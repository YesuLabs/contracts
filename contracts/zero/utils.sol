// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

library Utils {
    // Use this when we are certain that an overflow will not occur
    function Add(uint _a, uint _b) public pure returns (uint256) {
        assembly {
            mstore(0x0, add(_a, _b))
            return(0x0, 32)
        }
    }

    function CheckIsZeroAddress(address _address) public pure returns (bool) {
        assembly {
            if iszero(_address) {
                mstore(0x00, 0x20)
                mstore(0x20, 0x0c)
                mstore(0x40, 0x5a65726f20416464726573730000000000000000000000000000000000000000) // load hex of "Zero Address" to memory
                revert(0x00, 0x60)
            }
        }
        return true;
    }

    function MustGreaterThanZero(uint256 _value) internal pure returns (bool result) {
        assembly {
            // The 'iszero' opcode returns 1 if the input is zero, and 0 otherwise.
            // So, 'iszero(iszero(_value))' returns 1 if value > 0, and 0 if value == 0.
            result := iszero(iszero(_value))
        }
    }

}