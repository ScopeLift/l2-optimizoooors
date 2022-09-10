// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

interface IWETH9 {
  function withdraw(uint wad) external;

  function deposit() external payable;
}

interface IAavePool {
  function supply(
    address asset,
    uint amount,
    address onBehalfOf,
    uint16 referralCode
  ) external;
}

contract AaveRouterEth {
  IAavePool public immutable aave;
  IWETH9 public immutable weth;

  constructor(IAavePool _aave, IWETH9 _weth) {
    aave = _aave;
    weth = _weth;
  }

  receive() external payable {
    weth.deposit{value: msg.value}();
    aave.supply(address(weth), msg.value, msg.sender, 0);
  }
}
