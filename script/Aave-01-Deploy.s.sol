// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "src/Aave.sol";

contract DeployAaveRouters is Script {
  IAavePool aave;
  address weth;
  address dai;
  address usdc;

  function run() public {
    // NOTE: The hardcoded addresses are for Optimism.
    if (block.chainid == 10) {
      aave = IAavePool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
      weth = 0x4200000000000000000000000000000000000006;
      dai = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
      usdc = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    } else {
      revert("Unsupported chain");
    }

    vm.broadcast();
    AaveRouterFactory factory = new AaveRouterFactory(aave, weth);

    vm.broadcast();
    factory.deploy(dai);

    vm.broadcast();
    factory.deploy(usdc);
  }
}
