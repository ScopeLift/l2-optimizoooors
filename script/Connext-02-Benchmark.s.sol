// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "src/Connext.sol";

contract BenchmarkConnext is Script {
  using stdJson for string;

  // NOTE: The hardcoded addresses are for Optimism Goerli.
  // Default Connext routers and tokens we'll use.
  address defaultConnextRouter = 0xA04f29c24CCf3AF30D4164F608A56Dc495B2c976;
  address testTkn = 0x68Db1c8d85C09d546097C65ec7DCBFF4D6497CbF;

  function run() public {
    // =======================
    // ======== Setup ========
    // =======================

    // Read in our routers.
    string memory file = "broadcast/Connext-01-Deploy.s.sol/420/run-latest.json";
    string memory json = vm.readFile(file);

    address testTknRouter =
      json.readAddress(".transactions[1].additionalContracts[0].address");

    // ===========================
    // ======== Execution ========
    // ===========================

    vm.startBroadcast();

    // Default bridge of 10 tokens.
    IERC20(testTkn).approve(defaultConnextRouter, type(uint).max);
    IConnext(defaultConnextRouter).xcall(_xcallArgs(10e18));

    // Optimized bridge of 10 tokens. Our deployer started with 100 tokens, sent
    // 10, and now has 90 left. To send 10 more, we send 1/9th of the balance
    // which is ~28/255, so we encode 28 as hex which is 0x1c.
    IERC20(testTkn).approve(testTknRouter, type(uint).max);
    (bool ok,) = testTknRouter.call(hex"1c");
    require(ok, "Optimized token bridge failed");

    vm.stopBroadcast();
  }

  // Copied from ConnextBase.
  function _xcallArgs(uint amt) internal view returns (XCallArgs memory) {
    CallParams memory callParams = CallParams({
      to: msg.sender,
      callData: "",
      originDomain: 1_735_356_532, // Hardcoded Optimism Goerli for now.
      destinationDomain: 1_735_353_714, // Hardcoded Goerli for now.
      agent: msg.sender,
      recovery: msg.sender,
      forceSlow: false,
      receiveLocal: false,
      callback: address(0),
      callbackFee: 0,
      relayerFee: 0,
      destinationMinOut: amt * 99 / 100 // Hardcoded 1% slippage for now.
    });

    return XCallArgs({
      params: callParams,
      transactingAsset: testTkn,
      transactingAmount: amt,
      originMinOut: amt * 99 / 100 // Hardcoded 1% slippage for now.
    });
  }
}
