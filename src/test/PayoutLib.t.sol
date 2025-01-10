// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {console2 as console} from "lib/forge-std/src/Test.sol";

import {TestHelper} from "./dev/TestHelper.sol";
import {Ordering, Underdog, MarketType} from "src/libraries/Structs.sol";
import {PayoutLib} from "src/libraries/PayoutLib.sol";

contract PayoutLibTest is TestHelper {
    function test_constructCanceledPayouts() public pure {
        uint256[] memory payouts = PayoutLib._constructCanceledPayouts();
        // [1,1]
        assertEq(uint256(1), payouts[0]);
        assertEq(uint256(1), payouts[1]);
    }

    function test_constructWinnerPayouts() public pure {
        uint256[] memory payouts;
        // Home ordering, Home win [1,0]
        payouts = PayoutLib._constructWinnerPayouts(Ordering.HomeVsAway, uint32(133), uint32(101));
        assertEq(uint256(1), payouts[0]);
        assertEq(uint256(0), payouts[1]);

        // Home ordering, Away win [0,1]
        payouts = PayoutLib._constructWinnerPayouts(Ordering.HomeVsAway, uint32(101), uint32(133));
        assertEq(uint256(0), payouts[0]);
        assertEq(uint256(1), payouts[1]);

        // Away ordering, Home win [0,1]
        payouts = PayoutLib._constructWinnerPayouts(Ordering.AwayVsHome, uint32(133), uint32(101));
        assertEq(uint256(0), payouts[0]);
        assertEq(uint256(1), payouts[1]);

        // Away ordering, Away win [1,0]
        payouts = PayoutLib._constructWinnerPayouts(Ordering.AwayVsHome, uint32(101), uint32(133));
        assertEq(uint256(1), payouts[0]);
        assertEq(uint256(0), payouts[1]);
    }

    function test_constructWinnerPayouts_fuzz(uint32 home, uint32 away) public pure {
        uint256[] memory payouts;

        // HomeVsAway
        Ordering homeVAway = Ordering.HomeVsAway;
        payouts = PayoutLib._constructWinnerPayouts(homeVAway, home, away);
        if (home == away) {
            // [1,1]
            assertEq(uint256(1), payouts[0]);
            assertEq(uint256(1), payouts[1]);
        }

        if (home > away) {
            // [1,0]
            assertEq(uint256(1), payouts[0]);
            assertEq(uint256(0), payouts[1]);
        }
        if (away > home) {
            // [0,1]
            assertEq(uint256(0), payouts[0]);
            assertEq(uint256(1), payouts[1]);
        }

        // AwayVsHome
        Ordering awayVsHome = Ordering.AwayVsHome;
        payouts = PayoutLib._constructWinnerPayouts(awayVsHome, home, away);

        if (home == away) {
            // [1,1]
            assertEq(uint256(1), payouts[0]);
            assertEq(uint256(1), payouts[1]);
        }

        if (home > away) {
            // [0,1]
            assertEq(uint256(0), payouts[0]);
            assertEq(uint256(1), payouts[1]);
        }
        if (away > home) {
            // [1,0]
            assertEq(uint256(1), payouts[0]);
            assertEq(uint256(0), payouts[1]);
        }
    }

    function test_constructSpreadsPayouts() public pure {
        uint256[] memory payouts;
        uint256 line = 15_500_000; // line of 15.5

        // Home underdog, Home win, Underdog win: [0,1]
        payouts = PayoutLib._constructSpreadsPayouts(uint32(133), uint32(101), line, Underdog.Home);
        assertEq(uint256(0), payouts[0]);
        assertEq(uint256(1), payouts[1]);

        // Home underdog, Home loses, spread <= line, Underdog win: [0,1]
        payouts = PayoutLib._constructSpreadsPayouts(uint32(90), uint32(101), line, Underdog.Home);
        assertEq(uint256(0), payouts[0]);
        assertEq(uint256(1), payouts[1]);

        // Home underdog, Home loses, spread > line, Favorite win: [1,0]
        payouts = PayoutLib._constructSpreadsPayouts(uint32(70), uint32(101), line, Underdog.Home);
        assertEq(uint256(1), payouts[0]);
        assertEq(uint256(0), payouts[1]);

        // Away underdog, Away win, Underdog win: [0,1]
        payouts = PayoutLib._constructSpreadsPayouts(uint32(101), uint32(133), line, Underdog.Away);
        assertEq(uint256(0), payouts[0]);
        assertEq(uint256(1), payouts[1]);

        // Away underdog, Away loses, spread <= line, Underdog win: [0,1]
        payouts = PayoutLib._constructSpreadsPayouts(uint32(101), uint32(90), line, Underdog.Away);
        assertEq(uint256(0), payouts[0]);
        assertEq(uint256(1), payouts[1]);

        // Away underdog, Away loses, spread > line, Favorite win: [1,0]
        payouts = PayoutLib._constructSpreadsPayouts(uint32(101), uint32(85), line, Underdog.Away);
        assertEq(uint256(1), payouts[0]);
        assertEq(uint256(0), payouts[1]);
    }

    function test_constructSpreadsPayouts_fuzz(uint32 home, uint32 away, uint8 _underdog, uint32 _line) public pure {
        _underdog = uint8(bound(_underdog, 0, 1));
        Underdog underdog = Underdog(_underdog);

        vm.assume(_line > 0 && _line < 100);

        // Scale the line and add 0.5, 4 -> 4_500_000;
        uint256 line = _line * (10 ** 6) + (5 * (10 ** 5));

        uint256[] memory payouts = PayoutLib._constructSpreadsPayouts(home, away, line, underdog);

        // Home underdog, Home win, Underdog win: [0,1]
        if (underdog == Underdog.Home && home > away) {
            assertEq(uint256(0), payouts[0]);
            assertEq(uint256(1), payouts[1]);
        }

        // Home underdog, Home loses, spread <= line, Underdog win: [0,1]
        if (underdog == Underdog.Home && away > home && away - home <= _line) {
            assertEq(uint256(0), payouts[0]);
            assertEq(uint256(1), payouts[1]);
            assertFalse(false);
        }

        // Home underdog, Home loses, spread > line, Favorite win: [1,0]
        if (underdog == Underdog.Home && away > home && away - home > _line) {
            assertEq(uint256(1), payouts[0]);
            assertEq(uint256(0), payouts[1]);
        }

        // Away underdog, Away win, Underdog win: [0,1]
        if (underdog == Underdog.Away && away > home) {
            assertEq(uint256(0), payouts[0]);
            assertEq(uint256(1), payouts[1]);
        }

        // Away underdog, Away loses, spread <= line, Underdog win: [0,1]
        if (underdog == Underdog.Away && home > away && home - away <= _line) {
            assertEq(uint256(0), payouts[0]);
            assertEq(uint256(1), payouts[1]);
        }

        // Away underdog, Away loses, spread > line, Favorite win: [1,0]
        if (underdog == Underdog.Away && home > away && home - away > _line) {
            assertEq(uint256(1), payouts[0]);
            assertEq(uint256(0), payouts[1]);
        }
    }

    function test_constructTotalsPayouts(uint32 home, uint32 away, uint32 _line) public pure {
        vm.assume(_line > 0 && _line < 500);

        // Scale the line and add 0.5, 4 -> 4_500_000;
        uint256 line = _line * (10 ** 6) + (5 * (10 ** 5));

        uint256 total = uint256(home) + uint256(away);
        uint256[] memory payouts = PayoutLib._constructTotalsPayouts(home, away, line);
        if (total <= _line) {
            // Under win, [0,1]
            assertEq(uint256(0), payouts[0]);
            assertEq(uint256(1), payouts[1]);
        } else {
            // Over win, [1,0]
            assertEq(uint256(1), payouts[0]);
            assertEq(uint256(0), payouts[1]);
        }
    }
}
