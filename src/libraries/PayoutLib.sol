// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {LineLib} from "./LineLib.sol";
import {Ordering, MarketData, MarketType, GameState, GameData, Underdog} from "./Structs.sol";

library PayoutLib {
    /// @notice Generate a payout array for the Market, given its state, market type, ordering and line
    /// @param state        - The state of the Game
    /// @param marketType   - The market type
    /// @param ordering     - The Game's ordering, HomeVsAway or AwayVsHome
    /// @param home         - The score of the Home team
    /// @param away         - The score of the Away team
    function constructPayouts(
        GameState state,
        MarketType marketType,
        Ordering ordering,
        uint32 home,
        uint32 away,
        uint256 line,
        Underdog underdog
    ) internal pure returns (uint256[] memory) {
        if (state == GameState.Canceled) {
            return _constructCanceledPayouts();
        }
        if (marketType == MarketType.Winner) {
            return _constructWinnerPayouts(ordering, home, away);
        }
        if (marketType == MarketType.Spreads) {
            return _constructSpreadsPayouts(home, away, line, underdog);
        }
        return _constructTotalsPayouts(home, away, line);
    }

    /// @notice Validates an externally provided payout array
    /// @param payouts - The payout arrays
    function validatePayouts(uint256[] memory payouts) internal pure returns (bool) {
        if (payouts.length != 2) return false;

        // Payout must be [0,1], [1,0] or [1,1]
        // if payout[0] is 1, payout[1] must be 0 or 1
        if ((payouts[0] == 1) && (payouts[1] == 0 || payouts[1] == 1)) {
            return true;
        }
        // If payout[0] is 0, payout[1] must be 1
        if ((payouts[0] == 0) && (payouts[1] == 1)) {
            return true;
        }
        return false;
    }

    /// @notice Construct canceled payouts
    /// Canceled games always resolve to 50/50
    function _constructCanceledPayouts() internal pure returns (uint256[] memory) {
        uint256[] memory payouts = new uint256[](2);
        payouts[0] = 1;
        payouts[1] = 1;
        return payouts;
    }

    /// @notice Construct winner payouts
    /// Based on the game ordering, construct payouts
    /// @param ordering - The ordering of the Game, Home vs Away or Away vs Home
    /// @param home     - The score of the home team
    /// @param away     - The score of the away team
    function _constructWinnerPayouts(Ordering ordering, uint32 home, uint32 away)
        internal
        pure
        returns (uint256[] memory)
    {
        uint256[] memory payouts = new uint256[](2);
        if (home == away) {
            // Draw, [1, 1], exceedingly rare for most sports but for completeness
            payouts[0] = 1;
            payouts[1] = 1;
            return payouts;
        }

        // For a Market with a Home vs Away ordering
        if (ordering == Ordering.HomeVsAway) {
            if (home > away) {
                // Home Win, [1, 0]
                payouts[0] = 1;
                payouts[1] = 0;
            } else {
                // Away Win, [0, 1]
                payouts[0] = 0;
                payouts[1] = 1;
            }
        } else {
            // Away Ordering
            if (home > away) {
                // Home Win, [0, 1]
                payouts[0] = 0;
                payouts[1] = 1;
            } else {
                // Away Win, [1, 0]
                payouts[0] = 1;
                payouts[1] = 0;
            }
        }
        return payouts;
    }

    /// @notice Construct a payout vector for Spread Markets
    /// @notice Spread markets are always ["Favorite", "Underdog"]
    /// @dev Spread invariant: Underdog must win the game OR lose by the line or less to win
    function _constructSpreadsPayouts(uint32 home, uint32 away, uint256 line, Underdog underdog)
        internal
        pure
        returns (uint256[] memory)
    {
        uint256[] memory payouts = new uint256[](2);
        uint256 _line = LineLib._getLineLowerBound(line);

        if (underdog == Underdog.Home) {
            // Underdog is Home
            if (home > away || (away - home <= _line)) {
                // Home won OR Home loss spread <= line, Spread Market Underdog win [0,1]
                payouts[0] = 0;
                payouts[1] = 1;
            } else {
                // Underdog loss spread > line, Spread Market Favorite win [1,0]
                payouts[0] = 1;
                payouts[1] = 0;
            }
        } else {
            // Underdog is Away
            if (away > home || (home - away <= _line)) {
                // Away won OR Away loss spread <= line, Spread Market Underdog win [0,1]
                payouts[0] = 0;
                payouts[1] = 1;
            } else {
                // Underdog loss spread > line, Spread Market Favorite win [1,0]
                payouts[0] = 1;
                payouts[1] = 0;
            }
        }

        return payouts;
    }

    /// @notice Construct a payout vector for Totals Markets
    /// @dev Totals markets are always ["Over", "Under"]
    /// @dev Totals invariant: Under wins if total score <= line
    /// @param home     - The score of the home team
    /// @param away     - The score of the away team
    /// @param line     - The line of the Totals market
    function _constructTotalsPayouts(uint32 home, uint32 away, uint256 line) internal pure returns (uint256[] memory) {
        uint256[] memory payouts = new uint256[](2);
        uint256 total = uint256(home) + uint256(away);
        uint256 _line = LineLib._getLineLowerBound(line);
        if (total <= _line) {
            // Under wins, [0,1]
            payouts[0] = 0;
            payouts[1] = 1;
        } else {
            // Over wins, [1,0]
            payouts[0] = 1;
            payouts[1] = 0;
        }
        return payouts;
    }
}
