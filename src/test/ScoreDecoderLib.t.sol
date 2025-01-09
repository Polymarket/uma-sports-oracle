// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {TestHelper} from "./dev/TestHelper.sol";
import {Ordering} from "src/libraries/Structs.sol";
import {ScoreDecoderLib} from "src/libraries/ScoreDecoderLib.sol";

contract ScoreDecoderLibTest is TestHelper {
    function test_decodeScores(uint32 home, uint32 away, uint8 _ordering) public pure {
        _ordering = uint8(bound(_ordering, 0, 1));
        Ordering ordering = Ordering(_ordering);

        int256 encoded = encodeScores(home, away, ordering);

        (uint32 homeDecoded, uint32 awayDecoded) = ScoreDecoderLib.decodeScores(ordering, encoded);
        assertEq(home, homeDecoded);
        assertEq(away, awayDecoded);
    }
}
