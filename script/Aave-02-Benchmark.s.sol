// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "src/Aave.sol";

interface WrappedTokenGatewayV3 {
  function depositETH(address pool, address onBehalfOf, uint16 referralCode)
    external
    payable;

  function withdrawETH(address pool, uint amount, address onBehalfOf) external;
}

contract BenchmarkAave is Script {
  using stdJson for string;

  // NOTE: The hardcoded addresses are for Optimism.
  // Default Aave routers and tokens we'll use.
  address defaultEthRouter = 0x76D3030728e52DEB8848d5613aBaDE88441cbc59;
  address defaultTokenRouter = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
  address weth = 0x4200000000000000000000000000000000000006;
  address usdc = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;

  function run() public {
    // =======================
    // ======== Setup ========
    // =======================

    // Read in our routers.
    string memory file = "broadcast/Aave-01-Deploy.s.sol/10/run-latest.json";
    string memory json = vm.readFile(file);

    address supplyEthRtr =
      json.readAddress(".transactions[0].additionalContracts[0].address");
    address withdrawEthRtr =
      json.readAddress(".transactions[0].additionalContracts[1].address");
    address supplyUsdcRtr =
      json.readAddress(".transactions[2].additionalContracts[0].address");
    address withdrawUsdcRtr =
      json.readAddress(".transactions[2].additionalContracts[1].address");

    // ===========================
    // ======== Execution ========
    // ===========================

    vm.startBroadcast();

    // -------- ETH --------

    // Default 25% ETH supply.
    uint value = 0.0025 ether;
    WrappedTokenGatewayV3(defaultEthRouter).depositETH{value: value}(
      defaultTokenRouter, msg.sender, 0
    );

    // Default 25% ETH withdraw.
    atoken(weth).approve(defaultEthRouter, type(uint).max);
    WrappedTokenGatewayV3(defaultEthRouter).withdrawETH(
      defaultEthRouter, type(uint).max, msg.sender
    );

    // Optimized 25% ETH supply.
    (bool ok,) = payable(supplyEthRtr).call{value: value}("");
    require(ok, "Optimized ETH supply");

    // Optimized 25% ETH withdraw.
    atoken(weth).approve(withdrawEthRtr, type(uint).max);
    (ok,) = payable(withdrawEthRtr).call("");
    require(ok, "Optimized ETH withdraw");

    // -------- USDC --------

    // Default max USDC supply (balance of 2 USDC).
    bytes32 encoded =
      hex"0000000000000000000000000000000000000000000000000000001e84800002";
    IERC20(usdc).approve(defaultTokenRouter, type(uint).max);
    IAavePool(defaultTokenRouter).supply(encoded);

    // Default max USDC withdraw.
    encoded =
      hex"0000000000000000000000000000ffffffffffffffffffffffffffffffff0002";
    IAavePool(defaultTokenRouter).withdraw(encoded);

    // Optimized max USDC supply.
    IERC20(usdc).approve(supplyUsdcRtr, type(uint).max);
    (ok,) = supplyUsdcRtr.call("");
    require(ok, "Optimized USDC supply");

    // Optimized max USDC withdraw.
    atoken(usdc).approve(withdrawUsdcRtr, type(uint).max);
    (ok,) = withdrawUsdcRtr.call("");
    require(ok, "Optimized USDC withdraw");

    vm.stopBroadcast();
  }

  function atoken(address asset) internal view returns (IERC20) {
    return IERC20(
      IAavePool(defaultTokenRouter).getReserveData(asset).aTokenAddress
    );
  }
}
