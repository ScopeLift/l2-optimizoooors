// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "src/interfaces/IERC20.sol";

/// @notice Safe ETH and ERC20 transfer library that gracefully handles missing return values.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// @dev Caution! This library won't check that a token has code, responsibility is delegated to the caller.
/// @dev Identical to the solmate version, but using the IERC20 interface type.
/// Copied from: https://github.com/transmissions11/solmate/blob/4933263adeb62ee8878028e542453c4d1a071be9/src/utils/SafeTransferLib.sol
library SafeTransferLib {
  /*//////////////////////////////////////////////////////////////
                             ETH OPERATIONS
    //////////////////////////////////////////////////////////////*/

  function safeTransferETH(address to, uint amount) internal {
    bool success;

    assembly {
      // Transfer the ETH and store if it succeeded or not.
      success := call(gas(), to, amount, 0, 0, 0, 0)
    }

    require(success, "ETH_TRANSFER_FAILED");
  }

  /*//////////////////////////////////////////////////////////////
                            ERC20 OPERATIONS
    //////////////////////////////////////////////////////////////*/

  function safeTransferFrom(IERC20 token, address from, address to, uint amount)
    internal
  {
    bool success;

    assembly {
      // We'll write our calldata to this slot below, but restore it later.
      let memPointer := mload(0x40)

      // Write the abi-encoded calldata into memory, beginning with the function selector.
      mstore(
        0, 0x23b872dd00000000000000000000000000000000000000000000000000000000
      )
      mstore(4, from) // Append the "from" argument.
      mstore(36, to) // Append the "to" argument.
      mstore(68, amount) // Append the "amount" argument.

      success :=
        and(
          // Set success to whether the call reverted, if not we check it either
          // returned exactly 1 (can't just be non-zero data), or had no return data.
          or(
            and(eq(mload(0), 1), gt(returndatasize(), 31)),
            iszero(returndatasize())
          ),
          // We use 100 because that's the total length of our calldata (4 + 32 * 3)
          // Counterintuitively, this call() must be positioned after the or() in the
          // surrounding and() because and() evaluates its arguments from right to left.
          call(gas(), token, 0, 0, 100, 0, 32)
        )

      mstore(0x60, 0) // Restore the zero slot to zero.
      mstore(0x40, memPointer) // Restore the memPointer.
    }

    require(success, "TRANSFER_FROM_FAILED");
  }

  function safeTransfer(IERC20 token, address to, uint amount) internal {
    bool success;

    assembly {
      // We'll write our calldata to this slot below, but restore it later.
      let memPointer := mload(0x40)

      // Write the abi-encoded calldata into memory, beginning with the function selector.
      mstore(
        0, 0xa9059cbb00000000000000000000000000000000000000000000000000000000
      )
      mstore(4, to) // Append the "to" argument.
      mstore(36, amount) // Append the "amount" argument.

      success :=
        and(
          // Set success to whether the call reverted, if not we check it either
          // returned exactly 1 (can't just be non-zero data), or had no return data.
          or(
            and(eq(mload(0), 1), gt(returndatasize(), 31)),
            iszero(returndatasize())
          ),
          // We use 68 because that's the total length of our calldata (4 + 32 * 2)
          // Counterintuitively, this call() must be positioned after the or() in the
          // surrounding and() because and() evaluates its arguments from right to left.
          call(gas(), token, 0, 0, 68, 0, 32)
        )

      mstore(0x60, 0) // Restore the zero slot to zero.
      mstore(0x40, memPointer) // Restore the memPointer.
    }

    require(success, "TRANSFER_FAILED");
  }

  function safeApprove(IERC20 token, address to, uint amount) internal {
    bool success;

    assembly {
      // We'll write our calldata to this slot below, but restore it later.
      let memPointer := mload(0x40)

      // Write the abi-encoded calldata into memory, beginning with the function selector.
      mstore(
        0, 0x095ea7b300000000000000000000000000000000000000000000000000000000
      )
      mstore(4, to) // Append the "to" argument.
      mstore(36, amount) // Append the "amount" argument.

      success :=
        and(
          // Set success to whether the call reverted, if not we check it either
          // returned exactly 1 (can't just be non-zero data), or had no return data.
          or(
            and(eq(mload(0), 1), gt(returndatasize(), 31)),
            iszero(returndatasize())
          ),
          // We use 68 because that's the total length of our calldata (4 + 32 * 2)
          // Counterintuitively, this call() must be positioned after the or() in the
          // surrounding and() because and() evaluates its arguments from right to left.
          call(gas(), token, 0, 0, 68, 0, 32)
        )

      mstore(0x60, 0) // Restore the zero slot to zero.
      mstore(0x40, memPointer) // Restore the memPointer.
    }

    require(success, "APPROVE_FAILED");
  }
}
