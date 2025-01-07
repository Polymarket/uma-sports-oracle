// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {MarketType} from "../libraries/Structs.sol";
import {IConditionalTokens} from "../interfaces/IConditionalTokens.sol";

abstract contract ConditionalTokensModule {
    /// @notice Conditional Tokens Framework
    IConditionalTokens public immutable ctf;

    constructor(address _ctf) {
        ctf = IConditionalTokens(_ctf);
    }

    /// @notice Prepare a new Condition on the CTF
    /// @dev The marketId will be used as the questionID
    function _prepareMarket(bytes32 marketId, MarketType marketType) internal returns (bytes32) {
        if (marketType == MarketType.WinnerDraw) {
            return _prepareConditionByOutcome(marketId, 3);
        }
        return _prepareConditionByOutcome(marketId, 2);
    }

    function _prepareConditionByOutcome(bytes32 marketId, uint256 outcomeCount) internal returns (bytes32) {
        ctf.prepareCondition(address(this), marketId, outcomeCount);
        return keccak256(abi.encodePacked(address(this), marketId, outcomeCount));
    }
}
