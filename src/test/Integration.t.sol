// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {OracleSetup} from "./dev/OracleSetup.sol";
import {IOptimisticOracleV2Mock} from "./interfaces/IOptimisticOracleV2Mock.sol";

import {Ordering, Underdog} from "src/libraries/Structs.sol";

contract IntegrationTest is OracleSetup {
    function test_createGameAndResolveMarkets() public {
        // Happy path:
        // create game
        // create markets
        // resolve markets
        uint256 reward = 1_000_000;
        uint256 bond = 100_000_000;
        uint256 liveness = 0;
        Ordering ordering = Ordering.HomeVsAway;

        deal(usdc, admin, reward);

        // Create Game
        vm.prank(admin);
        oracle.createGame(ancillaryData, ordering, usdc, reward, bond, liveness);

        // Create a Winner market and multiple Spreads and Totals markets

        // create winner market
        vm.prank(admin);
        bytes32 winner = oracle.createWinnerMarket(gameId);

        // create spreads markets with line 10.5, 20.5 and 30.5
        bytes32 spreads_10 = oracle.createSpreadsMarket(gameId, Underdog.Home, convertLine(10));
        bytes32 spreads_20 = oracle.createSpreadsMarket(gameId, Underdog.Home, convertLine(20));
        bytes32 spreads_30 = oracle.createSpreadsMarket(gameId, Underdog.Home, convertLine(30));

        // create totals markets with line 150, 200 and 250
        bytes32 totals_150 = oracle.createTotalsMarket(gameId, Underdog.Home, convertLine(150));
        bytes32 totals_200 = oracle.createTotalsMarket(gameId, Underdog.Home, convertLine(200));
        bytes32 totals_250 = oracle.createTotalsMarket(gameId, Underdog.Home, convertLine(250));

        // Push prices to the OO and settle the Game
        int256 price = encodeScores(101, 130, Ordering.HomeVsAway);
        // Mock OO hasPrice and set the price
        IOptimisticOracleV2Mock(optimisticOracle).setHasPrice(true);
        IOptimisticOracleV2Mock(optimisticOracle).setPrice(price);
        
        // TODO
        // oracle.settleGame(gameId);

        // Resolve all the markets
        uint256[] memory payouts = new uint256[](2);

        // Winner market, Home vs away, home lost
        payouts[0] = 0;
        payouts[1] = 1;
        vm.expectEmit();
        emit MarketResolved(winner, payouts);
        oracle.resolveMarket(winner);

        // Spreads market, line 10.5, Favorite vs Underdog, Underdog lost
        payouts[0] = 1;
        payouts[1] = 0;
        vm.expectEmit();
        emit MarketResolved(spreads_10, payouts);
        oracle.resolveMarket(spreads_10);

        // Spreads market, line 20.5, Favorite vs Underdog, Underdog lost
        payouts[0] = 1;
        payouts[1] = 0;
        vm.expectEmit();
        emit MarketResolved(spreads_20, payouts);
        oracle.resolveMarket(spreads_20);

        // Spreads market, line 30.5, Favorite vs Underdog, Underdog won(spread <= line)
        payouts[0] = 0;
        payouts[1] = 1;
        vm.expectEmit();
        emit MarketResolved(spreads_30, payouts);
        oracle.resolveMarket(spreads_30);

        // Totals markets, line 150, Over vs Under, Over wins
        payouts[0] = 1;
        payouts[1] = 0;
        vm.expectEmit();
        emit MarketResolved(totals_150, payouts);
        oracle.resolveMarket(totals_150);

        // Totals markets, line 200, Over vs Under, Over wins
        payouts[0] = 1;
        payouts[1] = 0;
        vm.expectEmit();
        emit MarketResolved(totals_200, payouts);
        oracle.resolveMarket(totals_200);

        // Totals markets, line 250, Over vs Under, Under wins
        payouts[0] = 0;
        payouts[1] = 1;
        vm.expectEmit();
        emit MarketResolved(totals_250, payouts);
        oracle.resolveMarket(totals_250);
    }
}
