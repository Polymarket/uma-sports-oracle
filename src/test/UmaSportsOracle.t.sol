// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {console2 as console} from "lib/forge-std/src/Test.sol";

import {OracleSetup} from "./dev/OracleSetup.sol";

import {IConditionalTokens} from "src/interfaces/IConditionalTokens.sol";
import {IOptimisticOracleV2} from "src/interfaces/IOptimisticOracleV2.sol";

import {IAddressWhitelistMock} from "./interfaces/IAddressWhitelistMock.sol";
import {IOptimisticOracleV2Mock} from "./interfaces/IOptimisticOracleV2Mock.sol";

import {AncillaryDataLib} from "src/libraries/AncillaryDataLib.sol";
import {Ordering, GameData, GameState, MarketState, MarketType, MarketData, Underdog} from "src/libraries/Structs.sol";

contract UmaSportsOracleTest is OracleSetup {
    function testSetup() public view {
        assertEq(ctf, address(oracle.ctf()));
        assertEq(optimisticOracle, address(oracle.optimisticOracle()));
        assertEq(whitelist, address(oracle.addressWhitelist()));
        assertTrue(oracle.isAdmin(admin));
    }

    function test_createGame() public {
        uint256 reward = 1_000_000;
        uint256 bond = 100_000_000;
        uint256 liveness = 0;
        Ordering ordering = Ordering.HomeVsAway;

        deal(usdc, admin, reward);

        vm.expectEmit();
        emit GameCreated(gameId, appendedAncillaryData, block.timestamp);

        vm.prank(admin);
        oracle.createGame(ancillaryData, ordering, usdc, reward, bond, liveness);

        GameData memory gameData = oracle.getGame(gameId);
        assertEq(admin, gameData.creator);
        assertEq(reward, gameData.reward);
        assertEq(uint8(GameState.Created), uint8(gameData.state));
        assertEq(liveness, gameData.liveness);
    }

    function test_createGame_fuzz(uint256 _reward, uint256 _bond, uint256 _liveness, uint8 _ordering, uint256 _data)
        public
    {
        _ordering = uint8(bound(_ordering, 0, 1));
        Ordering ordering = Ordering(_ordering);

        bytes memory data = abi.encodePacked(bound(_data, 1, 1000));

        deal(usdc, admin, _reward);

        bytes memory expectedAncillaryData = AncillaryDataLib.appendAncillaryData(admin, data);
        bytes32 expectedGameId = keccak256(expectedAncillaryData);

        vm.expectEmit();
        emit GameCreated(expectedGameId, expectedAncillaryData, block.timestamp);

        vm.prank(admin);
        bytes32 gID = oracle.createGame(data, ordering, usdc, _reward, _bond, _liveness);

        // Verify state post game creation
        assertEq(expectedGameId, gID);
        GameData memory gameData = oracle.getGame(gID);
        assertEq(admin, gameData.creator);
        assertEq(_reward, gameData.reward);
        assertEq(uint8(GameState.Created), uint8(gameData.state));
        assertEq(_liveness, gameData.liveness);
        assertEq(expectedAncillaryData, gameData.ancillaryData);
    }

    function test_revert_createGameAlreadyCreated() public {
        test_createGame();

        vm.expectRevert(GameAlreadyCreated.selector);
        vm.prank(admin);
        oracle.createGame(ancillaryData, Ordering.HomeVsAway, usdc, 1_000_000, 100_000_000, 0);
    }

    function test_revert_createGameUnsupportedToken() public {
        IAddressWhitelistMock(whitelist).setIsOnWhitelist(false);

        vm.expectRevert(UnsupportedToken.selector);
        vm.prank(admin);
        oracle.createGame(ancillaryData, Ordering.HomeVsAway, usdc, 1_000_000, 100_000_000, 0);
    }

    function test_revert_createGameInvalidAncillaryData() public {
        bytes memory data = hex"";

        vm.expectRevert(InvalidAncillaryData.selector);
        vm.prank(admin);
        oracle.createGame(data, Ordering.HomeVsAway, usdc, 1_000_000, 100_000_000, 0);
    }

    function test_createMarket_Winner() public {
        test_createGame();
        MarketType marketType = MarketType.Winner;
        uint256 line = 0;

        bytes32 marketId = oracle.getMarketId(gameId, marketType, line, admin);
        bytes32 conditionId = keccak256(abi.encodePacked(address(oracle), marketId, uint256(2)));

        vm.expectEmit();
        emit MarketCreated(marketId, gameId, conditionId, uint8(marketType), line);

        vm.prank(admin);
        oracle.createWinnerMarket(gameId);

        MarketData memory marketData = oracle.getMarket(marketId);

        // Verify the Market's state post creation
        assertEq(gameId, marketData.gameId);
        assertEq(line, marketData.line);
        assertEq(uint8(MarketType.Winner), uint8(marketData.marketType));
        assertEq(uint8(MarketState.Created), uint8(marketData.state));
    }

    function test_createMarket_Spreads(uint256 _line) public {
        vm.assume(_line > 0 && _line < 100);

        test_createGame();
        uint256 line = _line * (10 ** 6) + (5 * (10 ** 5));
        MarketType marketType = MarketType.Spreads;

        bytes32 marketId = oracle.getMarketId(gameId, marketType, line, admin);
        bytes32 conditionId = keccak256(abi.encodePacked(address(oracle), marketId, uint256(2)));

        vm.expectEmit();
        emit MarketCreated(marketId, gameId, conditionId, uint8(marketType), line);

        vm.prank(admin);
        oracle.createSpreadsMarket(gameId, Underdog.Home, line);

        MarketData memory marketData = oracle.getMarket(marketId);

        // Verify the Market's state post creation
        assertEq(gameId, marketData.gameId);
        assertEq(line, marketData.line);
        assertEq(uint8(MarketType.Spreads), uint8(marketData.marketType));
        assertEq(uint8(MarketState.Created), uint8(marketData.state));
    }

    function test_createMarket_Totals(uint256 line) public {
        vm.assume(line > 0);
        test_createGame();
        MarketType marketType = MarketType.Totals;

        bytes32 marketId = oracle.getMarketId(gameId, marketType, line, admin);
        bytes32 conditionId = keccak256(abi.encodePacked(address(oracle), marketId, uint256(2)));

        vm.expectEmit();
        emit MarketCreated(marketId, gameId, conditionId, uint8(marketType), line);

        vm.prank(admin);
        oracle.createTotalsMarket(gameId, Underdog.Home, line);

        MarketData memory marketData = oracle.getMarket(marketId);

        // Verify the Market's state post creation
        assertEq(gameId, marketData.gameId);
        assertEq(line, marketData.line);
        assertEq(uint8(MarketType.Totals), uint8(marketData.marketType));
        assertEq(uint8(MarketState.Created), uint8(marketData.state));
    }

    function test_createMarket_fuzz(uint256 _line, uint8 _marketType) public {
        vm.assume(_line > 0 && _line < 100);

        test_createGame();

        _marketType = uint8(bound(_marketType, 0, 2));
        MarketType marketType = MarketType(_marketType);

        if (marketType == MarketType.Winner) {
            _line = 0;
        } else {
            _line = _line * (10 ** 6) + (5 * (10 ** 5));
        }

        uint256 outcomeCount = 2;

        bytes32 marketId = oracle.getMarketId(gameId, marketType, _line, admin);
        bytes32 conditionId = keccak256(abi.encodePacked(address(oracle), marketId, outcomeCount));

        vm.expectEmit();
        emit MarketCreated(marketId, gameId, conditionId, _marketType, _line);

        vm.prank(admin);
        oracle.createMarket(gameId, marketType, Underdog.Home, _line);

        MarketData memory marketData = oracle.getMarket(marketId);

        assertEq(gameId, marketData.gameId);
        assertEq(_line, marketData.line);
        assertEq(uint8(marketType), uint8(marketData.marketType));
        assertEq(uint8(MarketState.Created), uint8(marketData.state));
    }

    function test_createMarket_revert_GameDoesNotExist() public {
        vm.expectRevert(GameDoesNotExist.selector);
        vm.prank(admin);
        oracle.createWinnerMarket(gameId);
    }

    function test_createMarket_revert_InvalidLine() public {
        test_createGame();

        vm.expectRevert(InvalidLine.selector);
        vm.prank(admin);
        oracle.createMarket(gameId, MarketType.Winner, Underdog.Home, 100);
    }

    function test_createMarket_revert_MarketAlreadyCreated() public {
        test_createMarket_Winner();

        vm.expectRevert(MarketAlreadyCreated.selector);
        vm.prank(admin);
        oracle.createWinnerMarket(gameId);
    }

    function test_ready() public {
        test_createGame();

        assertFalse(oracle.ready(gameId));

        // Mock OO hasPrice
        IOptimisticOracleV2Mock(optimisticOracle).setHasPrice(true);
        assertTrue(oracle.ready(gameId));
    }

    function test_settleGame(uint32 home, uint32 away) public {
        test_createGame();

        int256 price = encodeScores(home, away, Ordering.HomeVsAway);
        // Mock OO hasPrice and set the price
        IOptimisticOracleV2Mock(optimisticOracle).setHasPrice(true);
        IOptimisticOracleV2Mock(optimisticOracle).setPrice(price);

        vm.expectEmit();
        emit GameSettled(gameId, home, away);

        oracle.settleGame(gameId);

        // Assert the state post settlement
        GameData memory gameData = oracle.getGame(gameId);
        assertEq(uint8(GameState.Settled), uint8(gameData.state));
        assertEq(home, gameData.homeScore);
        assertEq(away, gameData.awayScore);
    }

    function test_settleGameCanceled() public {
        test_createGame();

        // Set price to Cancel price accoring to the MULTIPLE_VALUES UMIP
        int256 price = type(int256).max;
        // Mock OO hasPrice and set the price
        IOptimisticOracleV2Mock(optimisticOracle).setHasPrice(true);
        IOptimisticOracleV2Mock(optimisticOracle).setPrice(price);

        vm.expectEmit();
        emit GameCanceled(gameId);

        oracle.settleGame(gameId);

        // Assert the state post settlement
        GameData memory gameData = oracle.getGame(gameId);
        assertEq(uint8(GameState.Canceled), uint8(gameData.state));
        assertEq(uint32(0), gameData.homeScore);
        assertEq(uint32(0), gameData.awayScore);
    }

    function test_settleGameIgnore() public {
        test_createGame();

        fastForward(2);

        // Set price to Ignore price accoring to the MULTIPLE_VALUES UMIP
        int256 price = type(int256).min;
        // Mock OO hasPrice and set the price
        IOptimisticOracleV2Mock(optimisticOracle).setHasPrice(true);
        IOptimisticOracleV2Mock(optimisticOracle).setPrice(price);

        // Deal the oracle some reward tokens to simulate the refund that occurs on dispute
        deal(usdc, address(oracle), uint256(1_000_000));

        vm.expectEmit();
        emit GameReset(gameId);

        oracle.settleGame(gameId);

        uint256 timestamp = block.timestamp;

        // Assert state post settlement
        GameData memory gameData = oracle.getGame(gameId);
        assertEq(uint8(GameState.Created), uint8(gameData.state));
        assertEq(timestamp, gameData.timestamp);
        assertEq(uint32(0), gameData.homeScore);
        assertEq(uint32(0), gameData.awayScore);
    }

    function test_settleGame_revert_GameDoesNotExist() public {
        vm.expectRevert(GameDoesNotExist.selector);
        oracle.settleGame(gameId);
    }

    function test_settleGame_revert_GameCannotBeSettled() public {
        test_settleGame(132, 100);
        vm.expectRevert(GameCannotBeSettled.selector);
        oracle.settleGame(gameId);
    }

    function test_settleGame_revert_DataDoesNotExist() public {
        test_createGame();
        vm.expectRevert(DataDoesNotExist.selector);

        oracle.settleGame(gameId);
    }

    function test_resolveMarket_Winner() public {
        test_createGame();

        uint32 home = 133;
        uint32 away = 101;
        int256 score = encodeScores(home, away, Ordering.HomeVsAway);

        // Create a Winner market on the Game
        bytes32 marketId = oracle.createWinnerMarket(gameId);

        // Push score data to the OO
        IOptimisticOracleV2Mock(optimisticOracle).setHasPrice(true);
        IOptimisticOracleV2Mock(optimisticOracle).setPrice(score);

        // settle the game
        oracle.settleGame(gameId);

        // Home win on a Home vs Away Game: [1,0]
        uint256[] memory expectedPayouts = new uint256[](2);
        expectedPayouts[0] = 1;
        expectedPayouts[1] = 0;

        vm.expectEmit();
        emit MarketResolved(marketId, expectedPayouts);

        oracle.resolveMarket(marketId);

        // Verify post resolution state
        MarketData memory marketData = oracle.getMarket(marketId);
        assertEq(gameId, marketData.gameId);
        assertEq(0, marketData.line);
        assertEq(uint8(MarketType.Winner), uint8(marketData.marketType));
        assertEq(uint8(MarketState.Resolved), uint8(marketData.state));

        // Assert conditional token state post resolution
        bytes32 conditionId = keccak256(abi.encodePacked(address(oracle), marketId, uint256(2)));
        // payout denominator is set when condition is resolved
        assertNotEq(0, IConditionalTokens(ctf).payoutDenominator(conditionId));
    }

    function test_resolveMarket_Spreads() public {
        test_createGame();

        uint32 home = 133;
        uint32 away = 140;
        uint256 line = 15_500_000;

        // Create a Spreads market on the Game
        bytes32 marketId = oracle.createSpreadsMarket(gameId, Underdog.Home, line);

        int256 score = encodeScores(home, away, Ordering.HomeVsAway);

        // Push score data to the OO
        IOptimisticOracleV2Mock(optimisticOracle).setHasPrice(true);
        IOptimisticOracleV2Mock(optimisticOracle).setPrice(score);

        // settle the game
        oracle.settleGame(gameId);

        // Underdog Home loss within spread, Underdog win: [0,1]
        uint256[] memory expectedPayouts = new uint256[](2);
        expectedPayouts[0] = 0;
        expectedPayouts[1] = 1;

        vm.expectEmit();
        emit MarketResolved(marketId, expectedPayouts);

        oracle.resolveMarket(marketId);

        // Verify post resolution state
        MarketData memory marketData = oracle.getMarket(marketId);
        assertEq(gameId, marketData.gameId);
        assertEq(line, marketData.line);
        assertEq(uint8(MarketType.Spreads), uint8(marketData.marketType));
        assertEq(uint8(MarketState.Resolved), uint8(marketData.state));

        // Assert conditional token state post resolution
        bytes32 conditionId = keccak256(abi.encodePacked(address(oracle), marketId, uint256(2)));
        // payout denominator is set when condition is resolved
        assertNotEq(0, IConditionalTokens(ctf).payoutDenominator(conditionId));
    }

    function test_resolveMarket_Totals() public {
        test_createGame();

        uint32 home = 133;
        uint32 away = 140;
        uint256 line = 300_500_000;

        // Create a Totals market on the Game
        bytes32 marketId = oracle.createTotalsMarket(gameId, Underdog.Home, line);

        int256 score = encodeScores(home, away, Ordering.HomeVsAway);

        // Push score data to the OO
        IOptimisticOracleV2Mock(optimisticOracle).setHasPrice(true);
        IOptimisticOracleV2Mock(optimisticOracle).setPrice(score);

        // settle the game
        oracle.settleGame(gameId);

        // total <= line, under wins: [0,1]
        uint256[] memory expectedPayouts = new uint256[](2);
        expectedPayouts[0] = 0;
        expectedPayouts[1] = 1;

        vm.expectEmit();
        emit MarketResolved(marketId, expectedPayouts);

        oracle.resolveMarket(marketId);

        // Verify post resolution state
        MarketData memory marketData = oracle.getMarket(marketId);
        assertEq(gameId, marketData.gameId);
        assertEq(line, marketData.line);
        assertEq(uint8(MarketType.Totals), uint8(marketData.marketType));
        assertEq(uint8(MarketState.Resolved), uint8(marketData.state));

        // Assert conditional token state post resolution
        bytes32 conditionId = keccak256(abi.encodePacked(address(oracle), marketId, uint256(2)));
        // payout denominator is set when condition is resolved
        assertNotEq(0, IConditionalTokens(ctf).payoutDenominator(conditionId));
    }

    function test_resolveMarket_Canceled() public {
        test_createGame();

        uint32 home = 101;
        uint32 away = 101;
        int256 score = encodeScores(home, away, Ordering.HomeVsAway);

        // Create a market on the Game
        bytes32 marketId = oracle.createWinnerMarket(gameId);

        // Push score data to the OO
        IOptimisticOracleV2Mock(optimisticOracle).setHasPrice(true);
        IOptimisticOracleV2Mock(optimisticOracle).setPrice(score);

        // settle the game
        oracle.settleGame(gameId);

        // Home win: [1,0,0]
        uint256[] memory expectedPayouts = new uint256[](2);
        expectedPayouts[0] = 1;
        expectedPayouts[1] = 1;

        vm.expectEmit();
        emit MarketResolved(marketId, expectedPayouts);

        oracle.resolveMarket(marketId);

        // Verify post resolution state
        MarketData memory marketData = oracle.getMarket(marketId);
        assertEq(gameId, marketData.gameId);
        assertEq(0, marketData.line);
        assertEq(uint8(MarketType.Winner), uint8(marketData.marketType));
        assertEq(uint8(MarketState.Resolved), uint8(marketData.state));

        // Assert conditional token state post resolution
        bytes32 conditionId = keccak256(abi.encodePacked(address(oracle), marketId, uint256(2)));
        // payout denominator is set when condition is resolved
        assertNotEq(0, IConditionalTokens(ctf).payoutDenominator(conditionId));
    }

    function test_resolveMarket_revert_MarketDoesNotExist() public {
        vm.expectRevert(MarketDoesNotExist.selector);
        oracle.resolveMarket(bytes32(0));
    }

    function test_resolveMarket_revert_GameNotSettledOrCanceled() public {
        test_createGame();
        bytes32 marketId = oracle.createWinnerMarket(gameId);

        vm.expectRevert(GameNotSettledOrCanceled.selector);
        oracle.resolveMarket(marketId);
    }

    function test_resolveMarket_fuzz(uint32 home, uint32 away, uint32 _line, uint8 _marketType, uint8 _underdog)
        public
    {
        vm.assume(_line > 0 && _line < 100);

        test_createGame();

        _marketType = uint8(bound(_marketType, 0, 2));
        MarketType marketType = MarketType(_marketType);

        _underdog = uint8(bound(_underdog, 0, 1));
        Underdog underdog = Underdog(_underdog);

        uint256 line;
        if (marketType == MarketType.Winner) {
            line = 0;
        } else {
            line = _line * (10 ** 6) + (5 * (10 ** 5));
        }

        // Create a market on the Game
        bytes32 marketId = oracle.createMarket(gameId, marketType, underdog, line);

        int256 score = encodeScores(home, away, Ordering.HomeVsAway);

        // Push score data to the OO
        IOptimisticOracleV2Mock(optimisticOracle).setHasPrice(true);
        IOptimisticOracleV2Mock(optimisticOracle).setPrice(score);

        // settle the game
        oracle.settleGame(gameId);

        oracle.resolveMarket(marketId);

        // Verify post resolution state
        MarketData memory marketData = oracle.getMarket(marketId);
        assertEq(gameId, marketData.gameId);
        assertEq(line, marketData.line);
        assertEq(uint8(marketType), uint8(marketData.marketType));
        assertEq(uint8(MarketState.Resolved), uint8(marketData.state));

        // Assert conditional token state post resolution
        uint256 outcomeSlotCount = 2;
        bytes32 conditionId = keccak256(abi.encodePacked(address(oracle), marketId, outcomeSlotCount));
        // payout denominator is set when condition is resolved
        assertNotEq(0, IConditionalTokens(ctf).payoutDenominator(conditionId));
    }
}
