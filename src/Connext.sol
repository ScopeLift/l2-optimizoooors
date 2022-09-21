// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {IERC20} from "src/interfaces/IERC20.sol";
import {IWETH} from "src/interfaces/IWETH.sol";
import {Create2} from "src/lib/Create2.sol";
import {SafeTransferLib} from "src/lib/SafeTransferLib.sol";

// ============================
// ======== Interfaces ========
// ============================

// These are the call parameters that will remain constant between the two
// chains. They are supplied on `xcall` and should be asserted on `execute`.
struct CallParams {
  // The account that receives funds, in the event of a crosschain call,
  // will receive funds if the call fails.
  address to;
  // The data to execute on the receiving chain. If no crosschain call is needed, then leave empty.
  bytes callData;
  // The originating domain (i.e. where `xcall` is called). Must match nomad domain schema.
  uint32 originDomain;
  // The final domain (i.e. where `execute` / `reconcile` are called). Must match nomad domain schema.
  uint32 destinationDomain;
  // An address who can execute txs on behalf of `to`, in addition to allowing relayers.
  address agent;
  // The address to send funds to if your `Executor.execute call` fails.
  address recovery;
  // The address on the origin domain of the callback contract.
  bool forceSlow;
  // The relayer fee to execute the callback.
  bool receiveLocal;
  // If true, will take slow liquidity path even if it is not a permissioned call.
  address callback;
  // If true, will use the local nomad asset on the destination instead of adopted.
  uint callbackFee;
  // The amount of relayer fee the tx called xcall with.
  uint relayerFee;
  // Minimum amount received on swaps for local <> adopted on destination chain.
  uint destinationMinOut; // second AMM
}

struct XCallArgs {
  // The CallParams. These are consistent across sending and receiving chains.
  CallParams params;
  // The asset the caller sent with the transfer. Can be the adopted,
  // canonical, or the representational asset.
  address transactingAsset;
  // The amount of transferring asset supplied by the user in the `xcall`.
  uint transactingAmount;
  // Minimum amount received on swaps for adopted <> local on origin chain.
  uint originMinOut; // first AMM
}

interface IConnext {
  function xcall(XCallArgs calldata _args) external payable returns (bytes32);
}

// =========================
// ======== Helpers ========
// =========================

// Amounts supplied or withdrawn are specified as a fraction of the user's
// balance. You can pass up to 31 bytes of data to define this fraction. If zero
// bytes are provided, the max amount is used. If one byte is provided, that
// data is considered the numerator, and the denominator becomes 255, which is
// the max value of a single byte. If two bytes are provided, the data is still
// considered the numerator, but the denominator becomes 65_535, which is the
// max value of 2 bytes. This pattern continues through 31 bytes, and this
// method will revert if you try passing 32 bytes or more of calldata.
// Realistically you'll never need that much anyway.
function parseAmount(uint balance, bytes calldata data) pure returns (uint) {
  if (data.length == 0) return balance;

  uint bits = data.length * 8;
  uint fraction = uint(bytes32(data) >> (256 - bits));
  uint maxUintN = (1 << bits) - 1;
  return balance * fraction / maxUintN;
}

// =========================
// ======== Routers ========
// =========================

abstract contract ConnextBase {
  using SafeTransferLib for IERC20;

  IConnext public immutable CONNEXT;
  address public immutable ASSET;

  constructor(IConnext connext, address asset) {
    CONNEXT = connext;
    ASSET = asset;
    IERC20(asset).safeApprove(address(connext), type(uint).max);
  }

  function _xcallArgs(uint amt) internal view returns (XCallArgs memory) {
    CallParams memory callParams = CallParams({
      to: msg.sender,
      callData: "",
      originDomain: 1_735_356_532, // Hardcoded Optimism Goerli for now.
      destinationDomain: 1_735_353_714, // Hardcoded Goerli for now.
      agent: msg.sender,
      recovery: msg.sender,
      forceSlow: false,
      receiveLocal: false,
      callback: address(0),
      callbackFee: 0,
      relayerFee: 0,
      destinationMinOut: amt * 99 / 100 // Hardcoded 1% slippage for now.
    });

    return XCallArgs({
      params: callParams,
      transactingAsset: ASSET,
      transactingAmount: amt,
      originMinOut: amt * 99 / 100 // Hardcoded 1% slippage for now.
    });
  }
}

contract ConnextBridgeToken is ConnextBase {
  using SafeTransferLib for IERC20;

  constructor(IConnext connext, address asset) ConnextBase(connext, asset) {}

  fallback() external {
    uint balance = IERC20(ASSET).balanceOf(msg.sender);
    uint amt = parseAmount(balance, msg.data);
    IERC20(ASSET).safeTransferFrom(msg.sender, address(this), amt);
    CONNEXT.xcall(_xcallArgs(amt));
  }
}

contract ConnextBridgeEth is ConnextBase {
  using SafeTransferLib for IERC20;

  constructor(IConnext connext, address asset) ConnextBase(connext, asset) {}

  fallback() external payable {
    uint amt = msg.value > 0
      ? msg.value
      : parseAmount(IERC20(ASSET).balanceOf(msg.sender), msg.data);

    // Bridging ETH.
    if (msg.value > 0) IWETH(ASSET).deposit{value: msg.value}();
    // Bridging WETH.
    else IERC20(ASSET).safeTransferFrom(msg.sender, address(this), amt);

    CONNEXT.xcall(_xcallArgs(amt));
  }
}

// =========================
// ======== Factory ========
// =========================

contract ConnextRouterFactory {
  IConnext public immutable CONNEXT;
  address public immutable WETH;
  address public immutable ETH_ROUTER;

  event RouterDeployed(address router, address indexed asset);

  constructor(IConnext connext, address weth) {
    CONNEXT = connext;
    WETH = weth;

    bytes32 salt = _salt(weth);
    ETH_ROUTER = address(new ConnextBridgeEth{salt: salt}(connext, weth));
    emit RouterDeployed(ETH_ROUTER, weth);
  }

  function deploy(address asset) external returns (address router) {
    router = address(new ConnextBridgeToken{salt: _salt(asset)}(CONNEXT, asset));
    emit RouterDeployed(router, asset);
  }

  function getRouter(address asset) public view returns (address router) {
    if (asset == WETH) return ETH_ROUTER;
    router = computeAddress(asset);
    if (router.code.length == 0) return address(0);
  }

  function isDeployed(address asset) external view returns (bool) {
    return getRouter(asset) != address(0);
  }

  function computeAddress(address asset) public view returns (address) {
    if (asset == WETH) return ETH_ROUTER;
    return Create2.computeCreate2Address(
      _salt(asset),
      address(this),
      type(ConnextBridgeToken).creationCode,
      abi.encode(CONNEXT, asset)
    );
  }

  function _salt(address asset) internal pure returns (bytes32) {
    return bytes32(uint(uint160(asset)));
  }
}
