// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";

/**
 * NOTES
 *
 * =================
 * ETH Deposit
 * to: https://optimistic.etherscan.io/address/0x76D3030728e52DEB8848d5613aBaDE88441cbc59
 * method: DepositETH(address, address, uint16)
 * data:
 * 0x474cf53d
 * 000000000000000000000000794a61358d6845594f94dc1db02a252b5b4814ad
 * 00000000000000000000000060a5dcb2fc804874883b797f37cbf1b0582ac2dd
 * 0000000000000000000000000000000000000000000000000000000000000000
 *
 * ETH deposits for deposit the ETH to weth, then call
 * POOL.deposit(address(WETH), msg.value, onBehalfOf, referralCode);
 * where POOL is the same as the `to` address for the USDC deposit, 794a61358D6845594F94dc1DB02A252b5b4814aD
 *
 * Comments say deposit is deprecated, and the logic for this method is
 * identical to the logic for `supply` below, so we can just route all calls to supply
 *
 * =================
 * USDC Deposit
 * to: https://optimistic.etherscan.io/address/0x794a61358D6845594F94dc1DB02A252b5b4814aD
 * method: supply(bytes32)
 * data:
 * 0xf7a73840
 * 0000000000000000000000000000000000000000000000000000000f42400002
 *
 * The bytes32 is decoded and then it calls
 * function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode)
 *
 * Forge fmt bulleted list test
 * - this was indented by 2 spaces before running forge fmt
 * - so was this
 */
interface IAavePool {
  function supply(
    address asset,
    uint amount,
    address onBehalfOf,
    uint16 referralCode
  ) external;
}

interface IERC20 {
  function balanceOf(address account) external view returns (uint);
}

contract AaveRouterErc20Factory {
  IAavePool public immutable aave;

  event RoutersDeployed(
    address supplyRouter, address withdrawRouter, address indexed asset
  );

  constructor(IAavePool _aave) {
    aave = _aave;
  }

  function deployRouters(address asset)
    external
    returns (
      AaveSupplyRouterErc20 supplyRouter,
      AaveWithdrawRouterErc20 withdrawRouter
    )
  {
    supplyRouter = new AaveSupplyRouterErc20{salt: salt(asset)}(aave, asset);
    withdrawRouter = new AaveWithdrawRouterErc20{salt: salt(asset)}(aave, asset);
    emit RoutersDeployed(address(supplyRouter), address(withdrawRouter), asset);
  }

  function isDeployed(address asset) public view returns (bool) {
    return computeSupplyRouterAddress(asset).code.length > 0;
  }

  function computeSupplyRouterAddress(address asset)
    public
    view
    returns (address)
  {
    // https://eips.ethereum.org/EIPS/eip-1014
    bytes32 data = keccak256(
      abi.encodePacked(
        bytes1(0xff),
        address(this),
        salt(asset),
        keccak256(
          abi.encodePacked(
            type(AaveSupplyRouterErc20).creationCode, abi.encode(aave, asset)
          )
        )
      )
    );
    return address(uint160(uint(data)));
  }

  function computeWithdrawRouterAddress(address asset)
    public
    view
    returns (address)
  {
    // https://eips.ethereum.org/EIPS/eip-1014
    bytes32 data = keccak256(
      abi.encodePacked(
        bytes1(0xff),
        address(this),
        salt(asset),
        keccak256(
          abi.encodePacked(
            type(AaveWithdrawRouterErc20).creationCode, abi.encode(aave, asset)
          )
        )
      )
    );
    return address(uint160(uint(data)));
  }

  function salt(address asset) internal pure returns (bytes32) {
    return bytes32(uint(uint160(asset)));
  }
}

abstract contract AaveRouterBase {
  IAavePool public immutable aave;
  address public immutable asset;

  constructor(IAavePool _aave, address _asset) {
    aave = _aave;
    asset = _asset;
  }

  // The amount supplied is a fraction of the user's balance. You can pass up
  // to 31 bytes of data to define this fraction. If 1 byte is provided, that
  // data is considered the numerator, and the denominator becomes 255, which
  // is the max value of a single byte. If 2 bytes are provided, the data is
  // still considered the numerator, but the denominator becomes 65_535, which
  // is the max value of 2 bytes. This will revert if you try passing 32 bytes
  // or more of calldata, but realistically you'll never need that much anyway.
  function parseAmount(uint balance, bytes calldata data)
    internal
    pure
    returns (uint)
  {
    uint bits = data.length * 8;
    uint fraction = uint(bytes32(data) >> (256 - bits));
    uint maxUintN = (1 << bits) - 1;
    return fraction * balance / maxUintN;
  }
}

contract AaveSupplyRouterErc20 is AaveRouterBase {
  constructor(IAavePool aave, address asset) AaveRouterBase(aave, asset) {}

  fallback() external {
    uint balance = IERC20(asset).balanceOf(msg.sender);
    uint amt = msg.data.length == 0 ? balance : parseAmount(balance, msg.data);
    // aave.supply(asset, amt, msg.sender, 0);
  }
}

contract AaveWithdrawRouterErc20 is AaveRouterBase {
  uint internal constant MAX_UINT = type(uint).max;

  constructor(IAavePool aave, address asset) AaveRouterBase(aave, asset) {}

  fallback() external {
    uint balance = IERC20(asset).balanceOf(msg.sender);
    uint amt = msg.data.length == 0 ? MAX_UINT : parseAmount(balance, msg.data);
    // aave.withdraw(asset, amount, msg.sender, 0);
  }
}
