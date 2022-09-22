// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "src/Superfluid.sol";

contract BenchmarkSuperfluid is Script {
  using stdJson for string;

  // NOTE: The hardcoded addresses are for Optimism.
  // Default Superfluid host, token, and constant flow agreement we'll use.
  ISuperfluid host = ISuperfluid(0x567c4B141ED61923967cA25Ef4906C8781069a10);
  ISuperfluidCFA cfa =
    ISuperfluidCFA(0x204C6f131bb7F258b2Ea1593f5309911d8E458eD);
  ISuperfluidToken usdcx =
    ISuperfluidToken(0x8430F084B939208E2eDEd1584889C9A66B90562f);
  IERC20 usdc = IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);

  function run() public {
    // =======================
    // ======== Setup ========
    // =======================

    // Read in our operator.
    string memory file = "broadcast/Superfluid-01-Deploy.s.sol/10/run-latest.json";
    string memory json = vm.readFile(file);

    address usdcxWrapper =
      json.readAddress(".transactions[0].additionalContracts[0].address");

    address usdcxOperator = json.readAddress(".transactions[2].additionalContracts[0].address");

    // ===========================
    // ======== Execution ========
    // ===========================

    vm.startBroadcast();
    // Wrap USDC.
    usdc.approve(usdcxWrapper, type(uint).max);
    (bool ok,) = usdcxWrapper.call(hex"1c");
    require(ok, "Optimized token bridge failed");

    // Approve operator to control usdcx flows.
    host.callAgreement(
      address(cfa),
      abi.encodeCall(
        cfa.authorizeFlowOperatorWithFullControl,
        (usdcx, usdcxOperator, new bytes(0))
      ),
      new bytes(0)
    );

    // Create a flow to a known address.
    (bool success, bytes memory data) = address(SuperFlowOperator(usdcxOperator).CREATE()).call(
      bytes.concat(bytes20(0x69E271483C38ED4902a55C3Ea8AAb9e7cc8617E5), bytes1(0x80))
    );

    vm.stopBroadcast();
  }
}
