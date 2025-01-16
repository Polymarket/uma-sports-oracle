// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.27;

contract IdentifierWhitelist {
    bool internal b = true;

    function isIdentifierSupported(bytes32) external view returns (bool) {
        return b;
    }

    function setIdentifierSupported(bool _b) external {
        b = _b;
    }
}
