// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IAddressWhitelistMock {
    function addToWhitelist(address) external;

    function removeFromWhitelist(address) external;

    function isOnWhitelist(address) external view returns (bool);

    function getWhitelist() external view returns (address[] memory);

    function setIsOnWhitelist(bool) external;
}
