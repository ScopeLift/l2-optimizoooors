// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

interface IERC20 {
  function approve(address spender, uint amount) external returns (bool);
  function balanceOf(address who) external view returns (uint);
}
