// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

struct RequestSettings {
    bool eventBased; // True if the request is set to be event-based.
    bool refundOnDispute; // True if the requester should be refunded their reward on dispute.
    bool callbackOnPriceProposed; // True if callbackOnPriceProposed callback is required.
    bool callbackOnPriceDisputed; // True if callbackOnPriceDisputed callback is required.
    bool callbackOnPriceSettled; // True if callbackOnPriceSettled callback is required.
    uint256 bond; // Bond that the proposer and disputer must pay on top of the final fee.
    uint256 customLiveness; // Custom liveness value set by the requester.
}

// Struct representing a price request.
struct Request {
    address proposer; // Address of the proposer.
    address disputer; // Address of the disputer.
    IERC20 currency; // ERC20 token used to pay rewards and fees.
    bool settled; // True if the request is settled.
    RequestSettings requestSettings; // Custom settings associated with a request.
    int256 proposedPrice; // Price that the proposer submitted.
    int256 resolvedPrice; // Price resolved once the request is settled.
    uint256 expirationTime; // Time at which the request auto-settles without a dispute.
    uint256 reward; // Amount of the currency to pay to the proposer on settlement.
    uint256 finalFee; // Final fee to pay to the Store upon request to the DVM.
}

contract OptimisticOracleV2 {
    int256 public price;
    bool public _hasPrice;
    Request public req;

    function setPrice(int256 _price) external {
        price = _price;
    }

    function settleAndGetPrice(bytes32, uint256, bytes memory) external view returns (int256) {
        return price;
    }

    function hasPrice(address, bytes32, uint256, bytes memory) external view returns (bool) {
        return _hasPrice;
    }

    function setHasPrice(bool b) external {
        _hasPrice = b;
    }

    function requestPrice(bytes32, uint256, bytes memory, address, uint256) external pure returns (uint256 totalBond) {
        return 0;
    }

    function setBond(bytes32, uint256, bytes memory, uint256) external pure returns (uint256 totalBond) {
        return 0;
    }

    function setEventBased(bytes32 identifier, uint256 timestamp, bytes memory ancillaryData) external {}

    function setCustomLiveness(
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData,
        uint256 customLiveness
    ) external {}

    function getRequest(address, bytes32, uint256, bytes memory) external view returns (Request memory) {
        return req;
    }

    function setRequest(Request memory _req) external {
        req = _req;
    }

    fallback() external {}
}
