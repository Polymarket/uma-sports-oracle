// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Request} from "../mocks/OptimisticOracleV2.sol";

interface IOptimisticOracleV2Mock {
    function setPrice(int256 _price) external;

    function settleAndGetPrice(bytes32, uint256, bytes memory) external view returns (int256);

    function hasPrice(address, bytes32, uint256, bytes memory) external view returns (bool);

    function setHasPrice(bool b) external;

    function requestPrice(bytes32, uint256, bytes memory, address, uint256) external pure returns (uint256);

    function setBond(bytes32, uint256, bytes memory, uint256) external pure returns (uint256);

    function setEventBased(bytes32, uint256, bytes memory) external;

    function setCustomLiveness(bytes32, uint256, bytes memory, uint256) external;

    function getRequest(address, bytes32, uint256, bytes memory) external view returns (Request memory);

    function setRequest(Request memory _req) external;
}
