// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Ordering} from "./Structs.sol";

library ScoreDecoderLib {
    uint256 internal constant SCORE_A_IDX = 0;
    uint256 internal constant SCORE_B_IDX = 32;

    function decodeScores(Ordering ordering, int256 data) internal pure returns (uint32 home, uint32 away) {
        if (ordering == Ordering.HomeVsAway) {
            home = _getScore(data, SCORE_A_IDX);
            away = _getScore(data, SCORE_B_IDX);
        } else {
            away = _getScore(data, SCORE_A_IDX);
            home = _getScore(data, SCORE_B_IDX);
        }

        return (home, away);
    }

    function _getScore(int256 data, uint256 slot) internal pure returns (uint32) {
        return uint32(uint256(data >> slot));
    }
}
