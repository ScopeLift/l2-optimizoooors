// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

/**
 * NOTES
 *
 * =================
 * ETH Deposit
 * to: https://optimistic.etherscan.io/address/0x76D3030728e52DEB8848d5613aBaDE88441cbc59
 * method: DepositETH(address, address, uint16)
 * data:
 * 0x474cf53d
 * 000000000000000000000000794a61358d6845594f94dc1db02a252b5b4814ad
 * 00000000000000000000000060a5dcb2fc804874883b797f37cbf1b0582ac2dd
 * 0000000000000000000000000000000000000000000000000000000000000000
 *
 * ETH deposits for deposit the ETH to weth, then call
 * POOL.deposit(address(WETH), msg.value, onBehalfOf, referralCode);
 * where POOL is the same as the `to` address for the USDC deposit, 794a61358D6845594F94dc1DB02A252b5b4814aD
 *
 * Comments say deposit is deprecated, and the logic for this method is
 * identical to the logic for `supply` below, so we can just route all calls to supply
 *
 * =================
 * USDC Deposit
 * to: https://optimistic.etherscan.io/address/0x794a61358D6845594F94dc1DB02A252b5b4814aD
 * method: supply(bytes32)
 * data:
 * 0xf7a73840
 * 0000000000000000000000000000000000000000000000000000000f42400002
 *
 * The bytes32 is decoded and then it calls
 * function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode)
 */
interface IWETH9 {
  function withdraw(uint wad) external;

  function deposit() external payable;
}

contract AaveRouter {
  address public immutable aave;
  IWETH9 public immutable weth;

  constructor(address _aave, IWETH9 _weth) {
    aave = _aave;
    weth = _weth;
  }

  function supply(
    address asset,
    uint amount,
    address onBehalfOf,
    uint16 referralCode
  ) internal {
    aave.supply(asset, amount, onBehalfOf, referralCode);
  }

  fallback() external {
    // TODO decode msg.data however we choose to encode it
    supply(asset, amount, onBehalfOf, referralCode);
  }

  receive() external payable {
    weth.deposit{value: msg.value}();
    // TODO decode msg.data however we choose to encode it
    supply(asset, amount, onBehalfOf, referralCode);
  }
}
