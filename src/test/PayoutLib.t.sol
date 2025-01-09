// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {TestHelper} from "./dev/TestHelper.sol";
import {Ordering, Underdog, MarketType} from "src/libraries/Structs.sol";
import {PayoutLib} from "src/libraries/PayoutLib.sol";

contract PayoutLibTest is TestHelper {
    function test_constructCanceledPayouts() public {
        uint256[] memory payouts = PayoutLib._constructCanceledPayouts(MarketType.Spreads);
        // [1,1]
        assertEq(uint256(1), payouts[0]);
        assertEq(uint256(1), payouts[1]);

        payouts = PayoutLib._constructCanceledPayouts(MarketType.WinnerDraw);
        // [1,1,1]
        assertEq(uint256(1), payouts[0]);
        assertEq(uint256(1), payouts[1]);
        assertEq(uint256(1), payouts[2]);
    }

    function test_constructCanceledPayouts_fuzz(uint8 _marketType) public pure {
        _marketType = uint8(bound(_marketType, 0, 3));
        MarketType marketType = MarketType(_marketType);

        uint256[] memory payouts = PayoutLib._constructCanceledPayouts(marketType);

        if (marketType == MarketType.WinnerDraw) {
            // [1,1,1]
            assertEq(uint256(1), payouts[0]);
            assertEq(uint256(1), payouts[1]);
            assertEq(uint256(1), payouts[2]);
        } else {
            // [1,1]
            assertEq(uint256(1), payouts[0]);
            assertEq(uint256(1), payouts[1]);
        }
    }

    function test_constructWinnerBinaryPayouts() public {
        uint256[] memory payouts;
        // Home ordering, Home win [1,0]
        payouts = PayoutLib._constructWinnerBinaryPayouts(Ordering.HomeVsAway, uint32(133), uint32(101));
        assertEq(uint256(1), payouts[0]);
        assertEq(uint256(0), payouts[1]);

        // Home ordering, Away win [0,1]
        payouts = PayoutLib._constructWinnerBinaryPayouts(Ordering.HomeVsAway, uint32(101), uint32(133));
        assertEq(uint256(0), payouts[0]);
        assertEq(uint256(1), payouts[1]);

        // Away ordering, Home win [0,1]
        payouts = PayoutLib._constructWinnerBinaryPayouts(Ordering.AwayVsHome, uint32(133), uint32(101));
        assertEq(uint256(0), payouts[0]);
        assertEq(uint256(1), payouts[1]);

        // Away ordering, Away win [1,0]
        payouts = PayoutLib._constructWinnerBinaryPayouts(Ordering.AwayVsHome, uint32(101), uint32(133));
        assertEq(uint256(1), payouts[0]);
        assertEq(uint256(0), payouts[1]);
    }

    function test_constructWinnerBinaryPayouts_fuzz(uint32 home, uint32 away, uint8 _ordering) public {
        _ordering = uint8(bound(_ordering, 0, 1));
        Ordering ordering = Ordering(_ordering);

        uint256[] memory payouts = PayoutLib._constructWinnerBinaryPayouts(ordering, home, away);
    }

    function test_constructWinnerDrawPayouts_fuzz(uint32 home, uint32 away, uint8 _ordering) public {
        _ordering = uint8(bound(_ordering, 0, 1));
        Ordering ordering = Ordering(_ordering);

        // TODO
    }

    function test_constructSpreadsPayouts_fuzz(uint32 home, uint32 away, uint8 _ordering) public {
        _ordering = uint8(bound(_ordering, 0, 1));
        Ordering ordering = Ordering(_ordering);

        // TODO
    }

    function test_constructTotalsPayouts_fuzz(uint32 home, uint32 away, uint8 _ordering) public {
        _ordering = uint8(bound(_ordering, 0, 1));
        Ordering ordering = Ordering(_ordering);

        // TODO
    }

    function testConstructPayouts() public {}
}
