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
        uint256 line = 15; // line of 15.5

        // Home ordering, Home underdog, Home win, Spread Market Home win: [1,0]
        payouts = PayoutLib._constructSpreadsPayouts(uint32(133), uint32(101), line, Underdog.Home);
        assertEq(uint256(1), payouts[0]);
        assertEq(uint256(0), payouts[1]);

        // Home ordering, Home underdog, Home loses, spread <= line, Spread Market Home win: [1,0]
        payouts = PayoutLib._constructSpreadsPayouts(uint32(90), uint32(101), line, Underdog.Home);
        assertEq(uint256(1), payouts[0]);
        assertEq(uint256(0), payouts[1]);

        // Home ordering, Home underdog, Home loses, spread > line, Spread Market Away win: [0,1]
        payouts = PayoutLib._constructSpreadsPayouts(uint32(70), uint32(101), line, Underdog.Home);
        assertEq(uint256(0), payouts[0]);
        assertEq(uint256(1), payouts[1]);

        // Home ordering, Away underdog, Away win, Spread Market Away win: [0,1]
        payouts = PayoutLib._constructSpreadsPayouts(uint32(101), uint32(133), line, Underdog.Away);
        assertEq(uint256(0), payouts[0]);
        assertEq(uint256(1), payouts[1]);

        // Home ordering, Away underdog, Away loses, spread <= line, Spread Market Away win: [0,1]
        payouts = PayoutLib._constructSpreadsPayouts(uint32(101), uint32(90), line, Underdog.Away);
        assertEq(uint256(0), payouts[0]);
        assertEq(uint256(1), payouts[1]);

        // Home ordering, Away underdog, Away loses, spread > line, Spread Market Home win: [1,0]
        payouts = PayoutLib._constructSpreadsPayouts(uint32(101), uint32(85), line, Underdog.Home);
        assertEq(uint256(1), payouts[0]);
        assertEq(uint256(0), payouts[1]);

        // Away ordering, Home underdog, Home win, Spread Market Home win: [0,1]
        payouts = PayoutLib._constructSpreadsPayouts(uint32(133), uint32(101), line, Underdog.Home);
        assertEq(uint256(0), payouts[0]);
        assertEq(uint256(1), payouts[1]);

        // Away ordering, Home underdog, Home loses, spread <= line, Spread Market Home win: [0,1]
        payouts = PayoutLib._constructSpreadsPayouts(uint32(90), uint32(101), line, Underdog.Home);
        assertEq(uint256(0), payouts[0]);
        assertEq(uint256(1), payouts[1]);

        // Away ordering, Home underdog, Home loses, spread > line, Spread Market Away win: [1,0]
        payouts = PayoutLib._constructSpreadsPayouts(uint32(70), uint32(101), line, Underdog.Home);
        assertEq(uint256(1), payouts[0]);
        assertEq(uint256(0), payouts[1]);

        // Away ordering, Away underdog, Away win, Spread Market Away win: [1,0]
        payouts = PayoutLib._constructSpreadsPayouts(uint32(101), uint32(133), line, Underdog.Away);
        assertEq(uint256(1), payouts[0]);
        assertEq(uint256(0), payouts[1]);

        // Away ordering, Away underdog, Away loses, spread <= line, Spread Market Away win: [1,0]
        payouts = PayoutLib._constructSpreadsPayouts(uint32(101), uint32(90), line, Underdog.Away);
        assertEq(uint256(1), payouts[0]);
        assertEq(uint256(0), payouts[1]);

        // Away ordering, Away underdog, Away loses, spread > line, Spread Market Home win: [0,1]
        payouts = PayoutLib._constructSpreadsPayouts(uint32(101), uint32(85), line, Underdog.Home);
        assertEq(uint256(0), payouts[0]);
        assertEq(uint256(1), payouts[1]);
    }

    function test_constructSpreadsPayouts_fuzz(uint32 home, uint32 away, uint8 _ordering, uint8 _underdog, uint32 line)
        public
        pure
    {
        _ordering = uint8(bound(_ordering, 0, 1));
        Ordering ordering = Ordering(_ordering);

        _underdog = uint8(bound(_underdog, 0, 1));
        Underdog underdog = Underdog(_underdog);

        vm.assume(line > 0 && line < 100);

        uint256[] memory payouts = PayoutLib._constructSpreadsPayouts(home, away, line, underdog);

        // Home ordering, Home underdog, Home win, Spread Market Home win: [1,0]
        if (ordering == Ordering.HomeVsAway && underdog == Underdog.Home && home > away) {
            assertEq(uint256(1), payouts[0]);
            assertEq(uint256(0), payouts[1]);
        }

        // Home ordering, Home underdog, Home loses, spread <= line, Spread Market Home win: [1,0]
        if (ordering == Ordering.HomeVsAway && underdog == Underdog.Home && away > home && away - home <= line) {
            assertEq(uint256(1), payouts[0]);
            assertEq(uint256(0), payouts[1]);
        }

        // Home ordering, Home underdog, Home loses, spread > line, Spread Market Away win: [0,1]
        if (ordering == Ordering.HomeVsAway && underdog == Underdog.Home && away > home && away - home > line) {
            assertEq(uint256(0), payouts[0]);
            assertEq(uint256(1), payouts[1]);
        }

        // Home ordering, Away underdog, Away win, Spread Market Away win: [0,1]
        if (ordering == Ordering.HomeVsAway && underdog == Underdog.Away && away > home) {
            assertEq(uint256(0), payouts[0]);
            assertEq(uint256(1), payouts[1]);
        }

        // Home ordering, Away underdog, Away loses, spread <= line, Spread Market Away win: [0,1]
        if (ordering == Ordering.HomeVsAway && underdog == Underdog.Away && away < home && home - away <= line) {
            assertEq(uint256(0), payouts[0]);
            assertEq(uint256(1), payouts[1]);
        }

        // Home ordering, Away underdog, Away loses, spread > line, Spread Market Home win: [1,0]
        if (ordering == Ordering.HomeVsAway && underdog == Underdog.Away && away < home && home - away > line) {
            assertEq(uint256(1), payouts[0]);
            assertEq(uint256(0), payouts[1]);
        }

        // Away ordering, Home underdog, Home win, Spread Market Home win: [0,1]
        if (ordering == Ordering.AwayVsHome && underdog == Underdog.Home && home > away) {
            assertEq(uint256(0), payouts[0]);
            assertEq(uint256(1), payouts[1]);
        }

        // Away ordering, Home underdog, Home loses, spread <= line, Spread Market Home win: [0,1]
        if (ordering == Ordering.AwayVsHome && underdog == Underdog.Home && away > home && away - home <= line) {
            assertEq(uint256(0), payouts[0]);
            assertEq(uint256(1), payouts[1]);
        }

        // Away ordering, Home underdog, Home loses, spread > line, Spread Market Away win: [1,0]
        if (ordering == Ordering.AwayVsHome && underdog == Underdog.Home && away > home && away - home > line) {
            assertEq(uint256(1), payouts[0]);
            assertEq(uint256(0), payouts[1]);
        }

        // Away ordering, Away underdog, Away win, Spread Market Away win: [1,0]
        if (ordering == Ordering.AwayVsHome && underdog == Underdog.Away && away > home) {
            assertEq(uint256(1), payouts[0]);
            assertEq(uint256(0), payouts[1]);
        }

        // Home ordering, Away underdog, Away loses, spread <= line, Spread Market Away win: [1,0]
        if (ordering == Ordering.AwayVsHome && underdog == Underdog.Away && home > away && home - away <= line) {
            assertEq(uint256(1), payouts[0]);
            assertEq(uint256(0), payouts[1]);
        }

        // Away ordering, Away underdog, Away loses, spread > line, Spread Market Home win: [0,1]
        if (ordering == Ordering.AwayVsHome && underdog == Underdog.Away && home > away && home - away > line) {
            assertEq(uint256(0), payouts[0]);
            assertEq(uint256(1), payouts[1]);
        }
    }

    function test_constructTotalsPayouts(uint32 home, uint32 away, uint32 line) public pure {
        vm.assume(line > 0 && line < 500);

        uint256 total = uint256(home) + uint256(away);
        uint256[] memory payouts = PayoutLib._constructTotalsPayouts(home, away, line);
        if (total <= line) {
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
