// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "src/Connext.sol";

contract DeployConnextRouters is Script {
  IConnext connext;
  address weth;
  address testTkn;

  function run() public {
    // NOTE: The hardcoded addresses are for Optimism Goerli.
    if (block.chainid == 420) {
      connext = IConnext(0xA04f29c24CCf3AF30D4164F608A56Dc495B2c976);
      weth = 0x4E283927E35b7118eA546Ef58Ea60bfF59E857DB;
      testTkn = 0x68Db1c8d85C09d546097C65ec7DCBFF4D6497CbF;
    } else {
      revert("Unsupported chain");
    }

    vm.broadcast();
    ConnextRouterFactory factory = new ConnextRouterFactory(connext, weth);

    vm.broadcast();
    factory.deploy(testTkn);
  }
}
