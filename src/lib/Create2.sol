// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

library Create2 {
  function computeCreate2Address(
    bytes32 salt,
    address deployer,
    bytes memory initcode,
    bytes memory constructorArgs
  ) internal pure returns (address) {
    return address(
      uint160(
        uint(
          keccak256(
            abi.encodePacked(
              bytes1(0xff),
              deployer,
              salt,
              keccak256(abi.encodePacked(initcode, constructorArgs))
            )
          )
        )
      )
    );
  }
}
