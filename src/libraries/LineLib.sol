// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

library LineLib {
    uint256 internal constant ONE = 10 ** 6;
    uint256 internal constant HALF_POINT = 500_000;

    function _isValidLine(uint256 line) internal pure returns (bool) {
        return line % ONE == HALF_POINT;
    }

    /// @notice Gets the lower bound of a line
    function _getLineLowerBound(uint256 line) internal pure returns (uint256) {
        return line / ONE;
    }
}
