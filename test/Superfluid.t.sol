// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/Superfluid.sol";

// =========================
// ==== Operator, etc ======
// =========================

contract SuperfluidForkTestBase is Test {
  // Optimism data.
  ISuperfluid host = ISuperfluid(0x567c4B141ED61923967cA25Ef4906C8781069a10);
  ISuperfluidCFA cfa =
    ISuperfluidCFA(0x204C6f131bb7F258b2Ea1593f5309911d8E458eD);
  ISuperfluidToken usdcx =
    ISuperfluidToken(0x8430F084B939208E2eDEd1584889C9A66B90562f);
  IERC20 usdc = IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);

  uint optimismForkId;

  function setUp() public {
    optimismForkId = vm.createSelectFork(vm.rpcUrl("optimism"));
  }

  // To receive ETH on withdrawals.
  receive() external payable {}
}

contract TokenWrapperFork is SuperfluidForkTestBase {
  function test_wrap() public {
    SuperTokenWrapper usdcxWrapper = new SuperTokenWrapper(address(usdcx));
    address user = makeAddr("tony");
    deal(address(usdc), user, 100_000e6);
    vm.startPrank(user);
    usdc.approve(address(usdcxWrapper), type(uint).max);
    (bool success, bytes memory data) = address(usdcxWrapper).call(
      hex""
    );
    vm.stopPrank();
    assertTrue(success);
    assertEq(usdcx.balanceOf(user), 100_000e18);
  }
}

contract OperatorFork is SuperfluidForkTestBase {
  function test_CreateFlow() public {
    SuperFlowOperator operator = new SuperFlowOperator(cfa, usdcx);
    SuperFlowCreate create = operator.CREATE();
    deal(address(usdcx), address(this), 100_000e6);
    host.callAgreement(
      address(cfa),
      abi.encodeCall(
        cfa.authorizeFlowOperatorWithFullControl,
        (usdcx, address(operator), new bytes(0))
      ),
      new bytes(0)
    );
    (bool success, bytes memory data) = address(create).call(
      bytes.concat(bytes20(makeAddr("receiver")), bytes1(0x80))
    );
    assertTrue(success);
  }
}
