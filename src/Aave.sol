// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {IERC20} from "src/interfaces/IERC20.sol";
import {IWETH} from "src/interfaces/IWETH.sol";
import {Create2} from "src/lib/Create2.sol";
import {SafeTransferLib} from "src/lib/SafeTransferLib.sol";

// ============================
// ======== Interfaces ========
// ============================

interface IAavePool {
  struct ReserveConfigurationMap {
    uint data; // This is a packed word, but we don't need this data here.
  }

  struct ReserveData {
    ReserveConfigurationMap configuration; // stores the reserve configuration
    uint128 liquidityIndex; // the liquidity index. Expressed in ray
    uint128 currentLiquidityRate; // the current supply rate. Expressed in ray
    uint128 variableBorrowIndex; // variable borrow index. Expressed in ray
    uint128 currentVariableBorrowRate; // the current variable borrow rate. Expressed in ray
    uint128 currentStableBorrowRate; // the current stable borrow rate. Expressed in ray
    uint40 lastUpdateTimestamp; // timestamp of last update
    uint16 id; // the id of the reserve. Represents the position in the list of the active reserves
    address aTokenAddress; // aToken address
    address stableDebtTokenAddress; // stableDebtToken address
    address variableDebtTokenAddress; // variableDebtToken address
    address interestRateStrategyAddress; // address of the interest rate strategy
    uint128 accruedToTreasury; // the current treasury balance, scaled
    uint128 unbacked; // the outstanding unbacked aTokens minted through the bridging feature
    uint128 isolationModeTotalDebt; // the outstanding debt borrowed against this asset in isolation mode
  }

  function getReserveData(address asset)
    external
    view
    returns (ReserveData memory);

  function supply(
    address asset,
    uint amount,
    address onBehalfOf,
    uint16 referralCode
  ) external;
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
  uint bits = data.length * 8;
  uint fraction = uint(bytes32(data) >> (256 - bits));
  uint maxUintN = (1 << bits) - 1;
  return balance * fraction / maxUintN;
}

// =========================
// ======== Routers ========
// =========================

abstract contract AaveRouterBase {
  IAavePool public immutable AAVE;
  address public immutable ASSET;
  uint16 internal constant REFERRAL_CODE = 0;

  mapping(address => address) public supplyRouter; // asset => router
  mapping(address => address) public withdrawRouter; // asset => router

  constructor(IAavePool aave, address asset) {
    AAVE = aave;
    ASSET = asset;
  }
}

// -------- Supply ETH Router --------

contract AaveSupplyEth is AaveRouterBase {
  using SafeTransferLib for IERC20;

  constructor(IAavePool aave, address asset) AaveRouterBase(aave, asset) {
    IERC20(asset).safeApprove(address(aave), type(uint).max);
  }

  receive() external payable {
    IWETH(ASSET).deposit{value: msg.value}();
    AAVE.supply(address(ASSET), msg.value, msg.sender, REFERRAL_CODE);
  }
}

// -------- Withdraw ETH Router --------

contract AaveWithdrawEth is AaveRouterBase {
  constructor(IAavePool aave, address asset) AaveRouterBase(aave, asset) {}
}

// -------- Supply Token Router --------

contract AaveSupplyToken is AaveRouterBase {
  using SafeTransferLib for IERC20;

  constructor(IAavePool aave, address asset) AaveRouterBase(aave, asset) {
    IERC20(asset).safeApprove(address(aave), type(uint).max);
  }

  fallback() external {
    uint balance = IERC20(ASSET).balanceOf(msg.sender);
    uint amt = msg.data.length == 0 ? balance : parseAmount(balance, msg.data);
    IERC20(ASSET).safeTransferFrom(msg.sender, address(this), amt);
    AAVE.supply(ASSET, amt, msg.sender, 0);
  }
}

// -------- Withdraw Token Router --------

contract AaveWithdrawToken is AaveRouterBase {
  constructor(IAavePool aave, address asset) AaveRouterBase(aave, asset) {}
}

// =========================
// ======== Factory ========
// =========================

contract AaveRouterFactory {
  IAavePool public immutable AAVE;
  address public immutable WETH;
  address public immutable SUPPLY_ETH_ROUTER;
  address public immutable WITHDRAW_ETH_ROUTER;

  event RoutersDeployed(
    address supplyRouter, address withdrawRouter, address indexed asset
  );

  constructor(IAavePool aave, address weth) {
    AAVE = aave;
    WETH = weth;

    bytes32 salt = _salt(weth);
    SUPPLY_ETH_ROUTER = address(new AaveSupplyEth{salt: salt}(aave, weth));
    WITHDRAW_ETH_ROUTER = address(0);
    emit RoutersDeployed(SUPPLY_ETH_ROUTER, WITHDRAW_ETH_ROUTER, weth);
  }

  function deploy(address asset) external returns (address, address) {
    address supplyRouter =
      address(new AaveSupplyToken{salt: _salt(asset)}(AAVE, asset));
    address withdrawRouter =
      address(new AaveWithdrawToken{salt: _salt(asset)}(AAVE, asset));

    emit RoutersDeployed(supplyRouter, withdrawRouter, asset);
    return (supplyRouter, withdrawRouter);
  }

  function isDeployed(address asset) public view returns (address, address) {
    if (asset == WETH) {
      return (SUPPLY_ETH_ROUTER, WITHDRAW_ETH_ROUTER);
    }

    (address supplyRouter, address withdrawRouter) = computeAddresses(asset);
    if (supplyRouter.code.length == 0) {
      return (address(0), address(0));
    }
    return (supplyRouter, withdrawRouter);
  }

  function computeAddresses(address asset)
    public
    view
    returns (address, address)
  {
    if (asset == WETH) {
      return (SUPPLY_ETH_ROUTER, WITHDRAW_ETH_ROUTER);
    }
    address supplyRouter = _computeAddress(asset, true);
    address withdrawRouter = _computeAddress(asset, false);
    return (supplyRouter, withdrawRouter);
  }

  function _computeAddress(address asset, bool supply)
    internal
    view
    returns (address)
  {
    return Create2.computeCreate2Address(
      _salt(asset),
      address(this),
      supply
        ? type(AaveSupplyToken).creationCode
        : type(AaveWithdrawToken).creationCode,
      abi.encode(AAVE, asset)
    );
  }

  function _salt(address asset) internal pure returns (bytes32) {
    return bytes32(uint(uint160(asset)));
  }
}