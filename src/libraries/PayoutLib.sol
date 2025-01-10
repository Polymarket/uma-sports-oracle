// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Ordering, MarketData, MarketType, GameState, GameData, Underdog} from "./Structs.sol";

library PayoutLib {
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
        // Canceled games always get resolved to 50/50(or 33/33/33 in the case of WinnerDraw markets)
        if (state == GameState.Canceled) {
            return _constructCanceledPayouts(marketType);
        }

        if (marketType == MarketType.WinnerBinary) {
            return _constructWinnerBinaryPayouts(ordering, home, away);
        }
        if (marketType == MarketType.WinnerDraw) {
            return _constructWinnerDrawPayouts(ordering, home, away);
        }
        if (marketType == MarketType.Spreads) {
            return _constructSpreadsPayouts(ordering, home, away, line, underdog);
        }
        return _constructTotalsPayouts(ordering, home, away, line, underdog);
    }

    function _constructCanceledPayouts(MarketType marketType) internal pure returns (uint256[] memory) {
        uint256[] memory payouts;
        if (marketType == MarketType.WinnerDraw) {
            // Winner Draw markets have 3 outcomes. If canceled, resolve with [1,1,1]
            payouts = new uint256[](3);
            payouts[0] = 1;
            payouts[1] = 1;
            payouts[2] = 1;
        } else {
            // Resolve Winner Binary, Spreads and Totals Markets with [1,1]
            payouts = new uint256[](2);
            payouts[0] = 1;
            payouts[1] = 1;
        }
        return payouts;
    }

    function _constructWinnerBinaryPayouts(Ordering ordering, uint32 home, uint32 away)
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

    function _constructWinnerDrawPayouts(Ordering ordering, uint32 home, uint32 away)
        internal
        pure
        returns (uint256[] memory)
    {
        uint256[] memory payouts = new uint256[](3);

        if (home == away) {
            // Draw Win, [0, 1, 0]
            payouts[0] = 0;
            payouts[1] = 1;
            payouts[2] = 0;
            return payouts;
        }

        // For a Market with a Home vs Away ordering
        if (ordering == Ordering.HomeVsAway) {
            if (home > away) {
                // Home Win, [1, 0, 0]
                payouts[0] = 1;
                payouts[1] = 0;
                payouts[2] = 0;
            }
            if (away > home) {
                // Away Win, [0, 0, 1]
                payouts[0] = 0;
                payouts[1] = 0;
                payouts[2] = 1;
            }
        } else {
            // Away Ordering
            if (home > away) {
                // Home Win, [0, 0, 1]
                payouts[0] = 0;
                payouts[1] = 0;
                payouts[2] = 1;
            }
            if (away > home) {
                // Away Win, [1, 0, 0]
                payouts[0] = 1;
                payouts[1] = 0;
                payouts[2] = 0;
            }
        }
        return payouts;
    }

    /// @notice Construct a payout vector based for Spread Markets
    /// @dev Spread invariant: Underdog must win the game OR lose by the line or less to win
    function _constructSpreadsPayouts(Ordering ordering, uint32 home, uint32 away, uint256 line, Underdog underdog)
        internal
        pure
        returns (uint256[] memory)
    {
        uint256[] memory payouts = new uint256[](2);

        if (underdog == Underdog.Home) {
            // Underdog is Home
            if (home > away || (away - home <= line)) {
                // Home won OR Home loss spread <= line, Spread Market Home win
                if (ordering == Ordering.HomeVsAway) {
                    // Home Win [1,0]
                    payouts[0] = 1;
                    payouts[1] = 0;
                } else {
                    // Home Win [0,1]
                    payouts[0] = 0;
                    payouts[1] = 1;
                }
            } else {
                // Underdog loss spread > line, Spread Market Away win
                if (ordering == Ordering.HomeVsAway) {
                    // Away Win [0,1]
                    payouts[0] = 0;
                    payouts[1] = 1;
                } else {
                    // Away Win [1,0]
                    payouts[0] = 1;
                    payouts[1] = 0;
                }
            }
        } else {
            // Underdog is Away
            if (away > home || (home - away <= line)) {
                // Away won OR Away loss spread <= line, Spread Market Away win
                if (ordering == Ordering.HomeVsAway) {
                    // Away Win, Home vs Away [0,1]
                    payouts[0] = 0;
                    payouts[1] = 1;
                } else {
                    // Away Win, Away vs Home [1,0]
                    payouts[0] = 1;
                    payouts[1] = 0;
                }
            } else {
                // Underdog loss spread > line, Spread Market Home win
                if (ordering == Ordering.HomeVsAway) {
                    // Home Win, Home vs Away [1,0]
                    payouts[0] = 1;
                    payouts[1] = 0;
                } else {
                    // Home Win, Away vs Home [0,1]
                    payouts[0] = 0;
                    payouts[1] = 1;
                }
            }
        }

        return payouts;
    }

    function _constructTotalsPayouts(Ordering ordering, uint32 home, uint32 away, uint256 line, Underdog underdog)
        internal
        pure
        returns (uint256[] memory)
    {
        uint256[] memory payouts = new uint256[](2);

        // TODO
        return payouts;
    }
}
