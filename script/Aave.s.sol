// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "src/Aave.sol";

contract DeployAave is Script {
  IAavePool aave;
  address weth;

  function run() public {
    if (block.chainid == 10) {
      aave = IAavePool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
      weth = 0x4200000000000000000000000000000000000006;
    } else if (block.chainid == 42_161) {
      aave = IAavePool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
      weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    } else {
      revert("Unsupported chain");
    }

    vm.broadcast();
    new AaveRouterFactory(aave, weth);
  }
}
