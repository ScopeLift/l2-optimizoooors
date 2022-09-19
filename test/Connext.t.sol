// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/Connext.sol";

// =========================
// ======== Factory ========
// =========================

contract ConnextFactoryBaseTest is Test {
  ConnextRouterFactory factory;
  address connext = makeAddr("connext");
  address weth = makeAddr("weth");

  function setUp() public {
    factory = new ConnextRouterFactory(IConnext(connext), weth);
  }

  function mockTokenResponses(address asset) internal {
    bytes memory selector = abi.encodeWithSelector(IERC20.approve.selector);
    vm.mockCall(asset, selector, abi.encode(true));
  }
}

contract ConnextFactoryConstructor is ConnextFactoryBaseTest {
  function test_Constructor() public {
    assertEq(address(factory.CONNEXT()), connext, "connext");
  }
}

contract ConnextFactoryDeploy is ConnextFactoryBaseTest {
  function test_DeployRouter(address asset) public {
    vm.assume(asset != weth && asset != address(vm));
    mockTokenResponses(asset);

    address router1 = factory.computeAddress(asset);
    address router2 = factory.deploy(asset);

    assertEq(router1, router2, "address mismatch");
    assertTrue(router1.code.length > 0, "no code");
  }

  function test_RevertsIfAssetAlreadyDeployed(address asset) public {
    vm.assume(asset != address(vm));
    mockTokenResponses(asset);

    factory.deploy(asset);
    vm.expectRevert(stdError.lowLevelError);
    factory.deploy(asset);
  }
}

contract ConnextFactoryGetRouter is ConnextFactoryBaseTest {
  function test_GetRouter(address asset) public {
    mockTokenResponses(asset);

    address router = factory.getRouter(asset);
    assertEq(router, address(0), "router1");

    factory.deploy(asset);
    router = factory.getRouter(asset);
    assertTrue(router > address(0), "router2");
  }

  function test_IsDeployed(address asset) public {
    mockTokenResponses(asset);

    assertFalse(factory.isDeployed(asset), "deployed1");
    factory.deploy(asset);
    assertTrue(factory.isDeployed(asset), "deployed2");
  }
}

contract ConnextFactoryComputeAddress is ConnextFactoryBaseTest {
  function test_ComputeAddressEth() public {
    address router = factory.computeAddress(weth);
    assertEq(router, factory.ETH_ROUTER(), "router");
  }

  function test_ComputeAddressToken(address asset) public {
    vm.assume(asset != weth && asset != address(vm));
    mockTokenResponses(asset);

    address router1 = factory.computeAddress(asset);
    address router2 = factory.deploy(asset);
    assertEq(router1, router2, "router");
  }

  function test_ComputeAddressWeth() public {
    address router = factory.computeAddress(weth);
    assertEq(router, factory.ETH_ROUTER(), "router");
  }
}

// =========================
// ======== Routers ========
// =========================

contract RouterForkTestBase is Test {
  // Optimism Goerli data, from https://docs.connext.network/resources/testnet.
  IConnext connext = IConnext(0xA04f29c24CCf3AF30D4164F608A56Dc495B2c976);
  address weth = 0x4E283927E35b7118eA546Ef58Ea60bfF59E857DB;
  address tkn = 0x68Db1c8d85C09d546097C65ec7DCBFF4D6497CbF;

  ConnextRouterFactory factory;
  uint optimismForkId;

  function setUp() public {
    optimismForkId =
      vm.createSelectFork(vm.rpcUrl("optimism_goerli"), 1_244_053);

    factory = new ConnextRouterFactory(connext, weth);
    factory.deploy(tkn);
    deal(address(this), 10 ether);
    deal(tkn, address(this), 10e6);
  }
}

// NOTE: These are commented out because Connext is still in the process of
// getting WETH liquidity / configuring WETH support, so it currently fails.
contract BridgeEthFork is RouterForkTestBase {
  function test_BridgeEthPartial() public {
    // address router = factory.ETH_ROUTER();

    // (bool ok,) = payable(router).call{value: 1 ether}("");
    // assertTrue(ok, "bridge failed");
    // assertEq(address(this).balance, 9 ether, "balance");
  }

  function test_BridgeEthFull() public {
    // address router = factory.ETH_ROUTER();

    // (bool ok,) = payable(router).call{value: 10 ether}("");
    // assertTrue(ok, "bridge failed");
    // assertEq(address(this).balance, 0 ether, "balance");
  }
}

contract BridgeTokenFork is RouterForkTestBase {
  function test_BridgeTokenPartial() public {
    address router = factory.computeAddress(tkn);
    IERC20(tkn).approve(router, type(uint).max);

    // We want to supply 25% of our balance, which is close to 64/255, and 64
    // is 0x40 in hex.
    (bool ok,) = router.call(hex"40");
    assertTrue(ok, "supply failed");

    uint depositAmt = 10e6 * 64 / uint(255);
    uint expectedBal = 10e6 - depositAmt;
    assertEq(IERC20(tkn).balanceOf(address(this)), expectedBal, "balance");
  }

  function test_BridgeTokenFull() public {
    address router = factory.computeAddress(tkn);
    IERC20(tkn).approve(router, type(uint).max);

    (bool ok,) = router.call("");
    assertTrue(ok, "supply failed");

    assertEq(IERC20(tkn).balanceOf(address(this)), 0, "balance");
  }
}
