// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "src/Superfluid.sol";

contract DeploySuperfluidFactory is Script {
  address cfa;
  address usdcx;

  function run() public {
    if (block.chainid == 10) {
      cfa = 0x204C6f131bb7F258b2Ea1593f5309911d8E458eD;
      usdcx = 0x8430F084B939208E2eDEd1584889C9A66B90562f;
    } else {
      revert("Unsupported chain");
    }

    vm.broadcast();
    SuperOperatorFactory factory = new SuperOperatorFactory(cfa);

    vm.broadcast();
    factory.deploy(usdcx);
  }
}
