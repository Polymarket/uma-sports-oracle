// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

library ScoreDecoderLib {
    uint256 constant HOME_INDEX = 224;
    uint256 constant AWAY_INDEX = 192;

    function decodeScores(int256 data) internal pure returns (uint32 home, uint32 away) {
        home = uint32(uint256(data >> HOME_INDEX));
        away = uint32(uint256(data >> AWAY_INDEX));
        return (home, away);
    }
}
