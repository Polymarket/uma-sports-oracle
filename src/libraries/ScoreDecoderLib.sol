// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Ordering} from "./Structs.sol";

library ScoreDecoderLib {
    uint256 internal constant SCORE_A_SLOT = 192;
    uint256 internal constant SCORE_B_SLOT = 160;

    // TODO: umip 183 encoding is changing. Update when ready
    function decodeScores(Ordering ordering, int256 data) internal pure returns (uint32 home, uint32 away) {
        if (ordering == Ordering.HomeVsAway) {
            home = _getScore(data, SCORE_A_SLOT);
            away = _getScore(data, SCORE_B_SLOT);
        } else {
            away = _getScore(data, SCORE_A_SLOT);
            home = _getScore(data, SCORE_B_SLOT);
        }

        return (home, away);
    }

    function _getScore(int256 data, uint256 slot) internal pure returns (uint32) {
        return uint32(uint256(data >> slot));
    }
}
