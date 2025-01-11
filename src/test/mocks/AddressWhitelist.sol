// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.27;

import {IAddressWhitelist} from "src/interfaces/IAddressWhitelist.sol";

contract AddressWhitelist is IAddressWhitelist {
    bool public _isOnWhitelist = true;

    function addToWhitelist(address) external {}

    function removeFromWhitelist(address) external {}

    function isOnWhitelist(address) external view returns (bool) {
        return _isOnWhitelist;
    }

    function setIsOnWhitelist(bool b) external {
        _isOnWhitelist = b;
    }

    function getWhitelist() external pure returns (address[] memory) {
        return new address[](0);
    }
}
