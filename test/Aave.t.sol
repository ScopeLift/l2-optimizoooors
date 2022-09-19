// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/Aave.sol";

// =============================
// ======== ParseAmount ========
// =============================

contract ParseAmount is Test {
  uint balance = 100 ether;

  // External so we can pass as calldata to `parseAmount`.
  function assertParseAmount(bytes calldata data, uint expected) external {
    uint amount = parseAmount(balance, data);
    assertEq(amount, expected, "parseAmount failed");
  }

  function test_ParseAmount() public {
    this.assertParseAmount(bytes.concat(""), balance);

    this.assertParseAmount(bytes.concat(hex"ff"), balance);
    this.assertParseAmount(bytes.concat(hex"ffff"), balance);
    this.assertParseAmount(bytes.concat(hex"ffffffff"), balance);
    this.assertParseAmount(bytes.concat(hex"ffffffffffffffff"), balance);

    this.assertParseAmount(bytes.concat(hex"01"), balance / 255);
    this.assertParseAmount(bytes.concat(hex"0001"), balance / 65_535);
    this.assertParseAmount(bytes.concat(hex"000001"), balance / 16_777_215);
    this.assertParseAmount(
      bytes.concat(hex"00000001"), balance / (4_294_967_295)
    );

    this.assertParseAmount(bytes.concat(hex"aa"), balance * 0xaa / 255);
    this.assertParseAmount(bytes.concat(hex"00aa"), balance * 0xaa / 65_535);
    this.assertParseAmount(
      bytes.concat(hex"0000aa"), balance * 0xaa / 16_777_215
    );
    this.assertParseAmount(
      bytes.concat(hex"000000aa"), balance * 0xaa / (4_294_967_295)
    );

    this.assertParseAmount(bytes.concat(hex"aaaa"), balance * 0xaaaa / 65_535);
    this.assertParseAmount(
      bytes.concat(hex"aaaaaa"), balance * 0xaaaaaa / 16_777_215
    );
    this.assertParseAmount(
      bytes.concat(hex"aaaaaaaa"), balance * 0xaaaaaaaa / (4_294_967_295)
    );
  }

  function testFuzz_ParseAmount(uint64 fraction) public {
    uint amount = balance * fraction / (type(uint64).max);
    this.assertParseAmount(bytes.concat(bytes8(fraction)), amount);
  }

  function testFuzz_ParseAmount(uint32 fraction) public {
    uint amount = balance * fraction / (type(uint32).max);
    this.assertParseAmount(bytes.concat(bytes4(fraction)), amount);
  }

  function testFuzz_ParseAmount(uint16 fraction) public {
    uint amount = balance * fraction / (type(uint16).max);
    this.assertParseAmount(bytes.concat(bytes2(fraction)), amount);
  }

  function testFuzz_ParseAmount(uint8 fraction) public {
    uint amount = balance * fraction / (type(uint8).max);
    this.assertParseAmount(bytes.concat(bytes1(fraction)), amount);
  }
}

// =========================
// ======== Factory ========
// =========================

contract AaveFactoryBaseTest is Test {
  AaveRouterFactory factory;
  address aave = makeAddr("aave");
  address weth = makeAddr("weth");

  function setUp() public {
    mockTokenResponses(weth);
    factory = new AaveRouterFactory(IAavePool(aave), weth);
  }

  function mockTokenResponses(address asset) internal {
    vm.mockCall(
      asset, abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true)
    );
    vm.mockCall(
      aave,
      abi.encodeCall(IAavePool.getReserveData, (asset)),
      abi.encode(
        IAavePool.ReserveData(
          IAavePool.ReserveConfigurationMap(0),
          uint128(0),
          uint128(0),
          uint128(0),
          uint128(0),
          uint128(0),
          uint40(0),
          uint16(0),
          address(uint160(bytes20(keccak256(abi.encodePacked(asset))))),
          address(0),
          address(0),
          address(0),
          uint128(0),
          uint128(0),
          uint128(0)
        )
      )
    );
  }
}

contract AaveFactoryConstructor is AaveFactoryBaseTest {
  event RoutersDeployed(
    address supplyRouter, address withdrawRouter, address indexed asset
  );

  function test_Constructor() public {
    vm.recordLogs();
    factory = new AaveRouterFactory(IAavePool(aave), weth);
    Vm.Log[] memory events = vm.getRecordedLogs();

    // Check immutables.
    assertEq(address(factory.AAVE()), aave, "aave");
    assertEq(address(factory.WETH()), weth, "weth");

    (address supplyEthRtr, address withdrawEthRtr) =
      factory.computeAddresses(weth);
    assertEq(supplyEthRtr, factory.SUPPLY_ETH_ROUTER(), "supply1");
    assertEq(withdrawEthRtr, factory.WITHDRAW_ETH_ROUTER(), "withdraw1");

    // Check logs.
    assertEq(events.length, 1, "events.length");
    assertEq(events[0].topics[1], bytes32(uint(uint160(weth))), "asset");

    (supplyEthRtr, withdrawEthRtr) =
      abi.decode(events[0].data, (address, address));
    assertEq(supplyEthRtr, factory.SUPPLY_ETH_ROUTER(), "supply2");
    assertEq(withdrawEthRtr, factory.WITHDRAW_ETH_ROUTER(), "withdraw2");
  }
}

contract AaveFactoryDeploy is AaveFactoryBaseTest {
  function test_DeployRouter(address asset) public {
    vm.assume(asset != address(vm));
    mockTokenResponses(asset);

    (address supplyRtr1, address withdrawRtr1) = factory.computeAddresses(asset);
    (address supplyRtr2, address withdrawRtr2) = factory.deploy(asset);

    assertEq(supplyRtr1, supplyRtr2, "supply");
    assertEq(withdrawRtr1, withdrawRtr2, "withdraw");
    assertTrue(supplyRtr1.code.length > 0, "supply code");
    assertTrue(withdrawRtr1.code.length > 0, "withdraw code");
  }

  function test_RevertsIfAssetAlreadyDeployed(address asset) public {
    vm.assume(asset != address(vm));
    mockTokenResponses(asset);

    factory.deploy(asset);
    vm.expectRevert(stdError.lowLevelError);
    factory.deploy(asset);
  }
}

contract AaveFactoryGetRouters is AaveFactoryBaseTest {
  function test_GetRouters(address asset) public {
    mockTokenResponses(asset);

    (address supplyRtr, address withdrawRtr) = factory.getRouters(asset);
    assertEq(supplyRtr, address(0), "supply1");
    assertEq(withdrawRtr, address(0), "withdraw1");

    factory.deploy(asset);
    (supplyRtr, withdrawRtr) = factory.getRouters(asset);
    assertTrue(supplyRtr > address(0), "supply2");
    assertTrue(withdrawRtr > address(0), "withdraw2");
  }

  function test_IsDeployed(address asset) public {
    mockTokenResponses(asset);

    assertFalse(factory.isDeployed(asset), "deployed1");
    factory.deploy(asset);
    assertTrue(factory.isDeployed(asset), "deployed2");
  }
}

contract AaveFactoryComputeAddress is AaveFactoryBaseTest {
  function test_ComputeAddressEth() public {
    (address supplyRtr, address withdrawRtr) = factory.computeAddresses(weth);
    assertEq(supplyRtr, factory.SUPPLY_ETH_ROUTER(), "supply");
    assertEq(withdrawRtr, factory.WITHDRAW_ETH_ROUTER(), "withdraw");
  }

  function test_ComputeAddressToken(address asset) public {
    vm.assume(asset != weth && asset != address(vm));
    mockTokenResponses(asset);

    (address supplyRtr1, address withdrawRtr1) = factory.computeAddresses(asset);
    (address supplyRtr2, address withdrawRtr2) = factory.deploy(asset);
    assertEq(supplyRtr1, supplyRtr2, "supply");
    assertEq(withdrawRtr1, withdrawRtr2, "withdraw");
  }

  function test_ComputeAddressWeth() public {
    (address supplyRtr, address withdrawRtr) = factory.computeAddresses(weth);
    assertEq(supplyRtr, factory.SUPPLY_ETH_ROUTER(), "supply");
    assertEq(withdrawRtr, factory.WITHDRAW_ETH_ROUTER(), "withdraw");
  }
}

// =========================
// ======== Routers ========
// =========================

contract RouterForkTestBase is Test {
  // Optimism data.
  IAavePool aave = IAavePool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
  address weth = 0x4200000000000000000000000000000000000006;
  address usdc = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;

  AaveRouterFactory factory;
  uint optimismForkId;

  function setUp() public {
    optimismForkId = vm.createSelectFork(vm.rpcUrl("optimism"), 22_750_341);
    factory = new AaveRouterFactory(aave, weth);
    factory.deploy(usdc);
    deal(address(this), 100 ether);
    deal(usdc, address(this), 100_000e6);
  }

  function atoken(address asset) internal view returns (IERC20) {
    return IERC20(aave.getReserveData(asset).aTokenAddress);
  }

  // To receive ETH on withdrawals.
  receive() external payable {}
}

contract SupplyEthFork is RouterForkTestBase {
  function test_SupplyEthPartial() public {
    address supplyEthRtr = factory.SUPPLY_ETH_ROUTER();

    (bool ok,) = payable(supplyEthRtr).call{value: 25 ether}("");
    assertTrue(ok, "supply failed");

    assertEq(address(this).balance, 75 ether, "balance");
    assertEq(atoken(weth).balanceOf(address(this)), 25 ether, "atoken");
  }

  function test_SupplyEthFull() public {
    address supplyEthRtr = factory.SUPPLY_ETH_ROUTER();

    (bool ok,) = payable(supplyEthRtr).call{value: 100 ether}("");
    assertTrue(ok, "supply failed");

    assertEq(address(this).balance, 0 ether, "balance");
    assertEq(atoken(weth).balanceOf(address(this)), 100 ether, "atoken");
  }
}

contract SupplyTokenFork is RouterForkTestBase {
  function test_SupplyTokenPartial() public {
    (address supplyTokenRtr,) = factory.computeAddresses(usdc);
    IERC20(usdc).approve(supplyTokenRtr, type(uint).max);

    // We want to supply 25% of our balance, which is close to 64/255, and 64
    // is 0x40 in hex.
    (bool ok,) = supplyTokenRtr.call(hex"40");
    assertTrue(ok, "supply failed");

    uint depositAmt = 100_000e6 * 64 / uint(255);
    uint expectedBal = 100_000e6 - depositAmt;
    assertEq(IERC20(usdc).balanceOf(address(this)), expectedBal, "balance");
    assertEq(atoken(usdc).balanceOf(address(this)), depositAmt, "atoken");
  }

  function test_SupplyTokenFull() public {
    (address supplyTokenRtr,) = factory.computeAddresses(usdc);
    IERC20(usdc).approve(supplyTokenRtr, type(uint).max);

    (bool ok,) = supplyTokenRtr.call("");
    assertTrue(ok, "supply failed");

    assertEq(IERC20(usdc).balanceOf(address(this)), 0, "balance");
    assertEq(atoken(usdc).balanceOf(address(this)), 100_000e6, "atoken");
  }
}

contract WithdrawEthFork is SupplyEthFork {
  function test_WithdrawEthFull() public {
    test_SupplyEthFull(); // Run this test to get us ATokens.
    address withdrawEthRtr = factory.WITHDRAW_ETH_ROUTER();
    atoken(weth).approve(withdrawEthRtr, type(uint).max);

    (bool ok,) = withdrawEthRtr.call("");
    assertTrue(ok, "withdraw failed");

    assertEq(address(this).balance, 100 ether, "balance");
    assertEq(atoken(weth).balanceOf(address(this)), 0, "atoken");
  }

  function test_WithdrawEthPartial() public {
    test_SupplyEthFull(); // Run this test to get us ATokens.
    address withdrawEthRtr = factory.WITHDRAW_ETH_ROUTER();
    atoken(weth).approve(withdrawEthRtr, type(uint).max);

    (bool ok,) = withdrawEthRtr.call(hex"40"); // About 25% of our balance.
    assertTrue(ok, "withdraw failed");

    uint withdrawAmt = 100 ether * 64 / uint(255);
    uint expectedBal = 100 ether - withdrawAmt;
    assertEq(address(this).balance, withdrawAmt, "balance");
    assertEq(atoken(weth).balanceOf(address(this)), expectedBal, "atoken");
  }
}

contract WithdrawTokenFork is SupplyTokenFork {
  function test_WithdrawTokenFull() public {
    test_SupplyTokenFull(); // Run this test to get us ATokens.
    (, address withdrawTokenRtr) = factory.computeAddresses(usdc);
    atoken(usdc).approve(withdrawTokenRtr, type(uint).max);

    (bool ok,) = withdrawTokenRtr.call("");
    assertTrue(ok, "withdraw failed");

    assertEq(address(this).balance, 100 ether, "balance");
    assertEq(atoken(weth).balanceOf(address(this)), 0, "atoken");
  }

  function test_WithdrawTokenPartial() public {
    test_SupplyTokenFull(); // Run this test to get us ATokens.
    (, address withdrawTokenRtr) = factory.computeAddresses(usdc);
    atoken(usdc).approve(withdrawTokenRtr, type(uint).max);

    (bool ok,) = withdrawTokenRtr.call(hex"40"); // About 25% of our balance.
    assertTrue(ok, "withdraw failed");

    uint withdrawAmt = 100_000e6 * 64 / uint(255);
    uint expectedBal = 100_000e6 - withdrawAmt;
    assertEq(IERC20(usdc).balanceOf(address(this)), withdrawAmt, "balance");
    assertEq(atoken(usdc).balanceOf(address(this)), expectedBal, "atoken");
  }
}
