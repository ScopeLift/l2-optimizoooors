// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/AaveRouterEth.sol";

contract AaveRouterEthTest is Test {
  AaveRouterEth public router;

  function setUp() public {
    IAavePool aave = IAavePool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    IWETH9 weth = IWETH9(0x4200000000000000000000000000000000000006);

    router = new AaveRouterEth(aave, weth);
  }
}

contract SupplyEth is AaveRouterEthTest {
  function test_SupplyEth() public {
    vm.createSelectFork(vm.rpcUrl("optimism"), 22_566_008);
    (bool ok,) = address(router).call{value: 10 ether}("");
    assertTrue(ok, "supply failed");
  }
}
