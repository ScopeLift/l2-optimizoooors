// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

interface IWETH {
  function deposit() external payable;
  function withdraw(uint wad) external;
}
