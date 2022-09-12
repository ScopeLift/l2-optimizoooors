// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "src/Aave.sol";

contract DeployAave is Script {
  IAavePool aave;
  address weth;
  address dai;
  address usdc;

  function run() public {
    if (block.chainid == 10) {
      aave = IAavePool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
      weth = 0x4200000000000000000000000000000000000006;
      dai = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
      usdc = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    } else if (block.chainid == 42_161) {
      aave = IAavePool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
      weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
      dai = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
      usdc = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
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
