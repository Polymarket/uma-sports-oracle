// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Ordering, MarketData, MarketType, GameState, GameData, Underdog} from "./Structs.sol";

library PayoutLib {
    uint256 internal constant ONE = 10 ** 6;

    /// @notice Generate a payout array for the Market, given its state, market type, ordering and line
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
        // Canceled games always get resolved to 50/50
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

    function _constructCanceledPayouts() internal pure returns (uint256[] memory) {
        uint256[] memory payouts = new uint256[](2);
        payouts[0] = 1;
        payouts[1] = 1;
        return payouts;
    }

    function _constructWinnerPayouts(Ordering ordering, uint32 home, uint32 away)
        internal
        pure
        returns (uint256[] memory)
    {
        uint256[] memory payouts = new uint256[](2);
        if (home == away) {
            // Draw, [1, 1]
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
            }
            if (away > home) {
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
            }
            if (away > home) {
                // Away Win, [1, 0]
                payouts[0] = 1;
                payouts[1] = 0;
            }
        }
        return payouts;
    }

    /// @notice Construct a payout vector for Spread Markets
    /// @dev Spread markets are always ["Favorite", "Underdog"]
    /// @dev Spread invariant: Underdog must win the game OR lose by the line or less to win
    function _constructSpreadsPayouts(uint32 home, uint32 away, uint256 line, Underdog underdog)
        internal
        pure
        returns (uint256[] memory)
    {
        uint256[] memory payouts = new uint256[](2);
        uint256 _line = _getLineLowerBound(line);

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
    function _constructTotalsPayouts(uint32 home, uint32 away, uint256 line) internal pure returns (uint256[] memory) {
        uint256[] memory payouts = new uint256[](2);
        uint256 total = uint256(home) + uint256(away);
        uint256 _line = _getLineLowerBound(line);
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

    /// @notice Gets the lower bound of a line
    function _getLineLowerBound(uint256 line) internal pure returns (uint256) {
        return line / ONE;
    }
}
