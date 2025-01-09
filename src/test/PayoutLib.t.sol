// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {TestHelper} from "./dev/TestHelper.sol";
import {Ordering, Underdog, MarketType} from "src/libraries/Structs.sol";
import {PayoutLib} from "src/libraries/PayoutLib.sol";

contract PayoutLibTest is TestHelper {
    function testConstructCanceledPayouts(uint8 _ordering, uint8 _marketType) public {
        _ordering = uint8(bound(_ordering, 0, 1));
        Ordering ordering = Ordering(_ordering);

        _marketType = uint8(bound(_marketType, 0, 3));
        MarketType marketType = MarketType(_marketType);

        // TODO
    }

    function testConstructWinnerBinaryPayouts(uint32 home, uint32 away, uint8 _ordering) public {
        _ordering = uint8(bound(_ordering, 0, 1));
        Ordering ordering = Ordering(_ordering);

        // TODO
    }

    function testConstructWinnerDrawPayouts(uint32 home, uint32 away, uint8 _ordering) public {
        _ordering = uint8(bound(_ordering, 0, 1));
        Ordering ordering = Ordering(_ordering);

        // TODO
    }

    function testConstructSpreadsPayouts(uint32 home, uint32 away, uint8 _ordering) public {
        _ordering = uint8(bound(_ordering, 0, 1));
        Ordering ordering = Ordering(_ordering);

        // TODO
    }

    function testConstructTotalsPayouts(uint32 home, uint32 away, uint8 _ordering) public {
        _ordering = uint8(bound(_ordering, 0, 1));
        Ordering ordering = Ordering(_ordering);

        // TODO
    }

    function testConstructPayouts() public {}
}
