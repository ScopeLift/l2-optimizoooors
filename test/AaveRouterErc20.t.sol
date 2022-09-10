// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/AaveRouterErc20.sol";

contract AaveRouterFactory is Test {
// TODO
}

contract AaveRouterErc20Test is Test {
  AaveRouterErc20Factory factory;
  AaveRouterErc20 router;
  address asset = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607; // USDC

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl("optimism"), 22_566_008);

    IAavePool aave = IAavePool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    factory = new AaveRouterErc20Factory(aave);
    router = factory.deployRouter(asset);
    deal(asset, address(this), 100 ether);
  }

  function test_X() public {
    (bool ok,) = address(router).call(hex"01");
    assertTrue(ok, "deposit failed");
  }
}
