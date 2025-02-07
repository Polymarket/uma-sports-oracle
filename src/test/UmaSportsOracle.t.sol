// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "./interfaces/IERC20.sol";
import {IAddressWhitelistMock} from "./interfaces/IAddressWhitelistMock.sol";

import {OracleSetup} from "./dev/OracleSetup.sol";

import {IConditionalTokens} from "src/interfaces/IConditionalTokens.sol";

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

        vm.expectEmit();
        emit GameCreated(gameId, uint8(ordering), appendedAncillaryData, block.timestamp);

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
        vm.assume(_liveness < 5200 weeks);
        vm.assume(_bond < 100_000_000_000);

        _ordering = uint8(bound(_ordering, 0, 1));
        Ordering ordering = Ordering(_ordering);

        bytes memory data = abi.encodePacked(bound(_data, 1, 1000));

        deal(usdc, admin, _reward);

        bytes memory expectedAncillaryData = AncillaryDataLib.appendAncillaryData(admin, data);
        bytes32 expectedGameId = keccak256(expectedAncillaryData);

        vm.expectEmit();
        emit GameCreated(expectedGameId, uint8(ordering), expectedAncillaryData, block.timestamp);

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

    function test_createGame_revert_GameAlreadyCreated() public {
        test_createGame();

        vm.expectRevert(GameAlreadyCreated.selector);
        vm.prank(admin);
        oracle.createGame(ancillaryData, Ordering.HomeVsAway, usdc, 1_000_000, 100_000_000, 0);
    }

    function test_createGame_revert_UnsupportedToken() public {
        IAddressWhitelistMock(whitelist).setIsOnWhitelist(false);

        vm.expectRevert(UnsupportedToken.selector);
        oracle.createGame(ancillaryData, Ordering.HomeVsAway, usdc, 1_000_000, 100_000_000, 0);
    }

    function test_createGame_revert_InvalidAncillaryData() public {
        bytes memory data = hex"";

        vm.expectRevert(InvalidAncillaryData.selector);
        oracle.createGame(data, Ordering.HomeVsAway, usdc, 1_000_000, 100_000_000, 0);
    }

    function test_createMarket_Winner() public {
        test_createGame();
        MarketType marketType = MarketType.Winner;
        uint256 line = 0;

        bytes32 marketId = getMarketId(gameId, marketType, Underdog.Home, line, admin);
        bytes32 conditionId = getConditionId(address(oracle), marketId, uint256(2));

        vm.expectEmit();
        emit MarketCreated(marketId, gameId, conditionId, uint8(marketType), uint8(Underdog.Home), line);

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
        uint256 line = convertLine(_line);
        MarketType marketType = MarketType.Spreads;

        bytes32 marketId = getMarketId(gameId, marketType, Underdog.Home, line, admin);
        bytes32 conditionId = getConditionId(address(oracle), marketId, uint256(2));

        vm.expectEmit();
        emit MarketCreated(marketId, gameId, conditionId, uint8(marketType), uint8(Underdog.Home), line);

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
        vm.assume(line > 0 && line < 500);
        line = convertLine(line);

        test_createGame();
        MarketType marketType = MarketType.Totals;

        bytes32 marketId = getMarketId(gameId, marketType, Underdog.Home, line, admin);
        bytes32 conditionId = getConditionId(address(oracle), marketId, uint256(2));

        vm.expectEmit();
        emit MarketCreated(marketId, gameId, conditionId, uint8(marketType), uint8(Underdog.Home), line);

        vm.prank(admin);
        oracle.createTotalsMarket(gameId, line);

        MarketData memory marketData = oracle.getMarket(marketId);

        // Verify the Market's state post creation
        assertEq(gameId, marketData.gameId);
        assertEq(line, marketData.line);
        assertEq(uint8(MarketType.Totals), uint8(marketData.marketType));
        assertEq(uint8(MarketState.Created), uint8(marketData.state));
    }

    function test_createMarket_ConditionAlreadyPrepared() public {
        test_createGame();

        // "Frontrun" the createWinnerMarket call by preparing the expected marketId on the CTF
        bytes32 marketId = getMarketId(gameId, MarketType.Winner, Underdog.Home, 0, admin);
        IConditionalTokens(ctf).prepareCondition(address(oracle), marketId, 2);

        // The "frontrunning" should have no impact on creating the market
        bytes32 conditionId = getConditionId(address(oracle), marketId, uint256(2));

        vm.expectEmit();
        emit MarketCreated(marketId, gameId, conditionId, uint8(MarketType.Winner), uint8(Underdog.Home), 0);

        vm.prank(admin);
        oracle.createWinnerMarket(gameId);
    }

    function test_createMarket_fuzz(uint256 _line, uint8 _marketType) public {
        vm.assume(_line > 0 && _line < 100);

        test_createGame();

        _marketType = uint8(bound(_marketType, 0, 2));
        MarketType marketType = MarketType(_marketType);

        if (marketType == MarketType.Winner) {
            _line = 0;
        } else {
            _line = convertLine(_line);
        }

        uint256 outcomeCount = 2;

        bytes32 marketId = getMarketId(gameId, marketType, Underdog.Home, _line, admin);
        bytes32 conditionId = getConditionId(address(oracle), marketId, outcomeCount);

        vm.expectEmit();
        emit MarketCreated(marketId, gameId, conditionId, _marketType, uint8(Underdog.Home), _line);

        vm.prank(admin);
        if (marketType == MarketType.Winner) {
            oracle.createWinnerMarket(gameId);
        } else if (marketType == MarketType.Spreads) {
            oracle.createSpreadsMarket(gameId, Underdog.Home, _line);
        } else {
            oracle.createTotalsMarket(gameId, _line);
        }

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
        oracle.createSpreadsMarket(gameId, Underdog.Home, 0);

        vm.expectRevert(InvalidLine.selector);
        oracle.createSpreadsMarket(gameId, Underdog.Home, 2_000_000);

        vm.expectRevert(InvalidLine.selector);
        oracle.createTotalsMarket(gameId, 2);
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

        // Push price to the OO
        GameData memory gameData = oracle.getGame(gameId);
        int256 data = encodeScores(101, 133, Ordering.HomeVsAway);
        proposeAndSettle(data, gameData.timestamp, gameData.ancillaryData);

        assertTrue(oracle.ready(gameId));
    }

    function test_resolveMarket_Winner() public {
        test_createGame();

        uint32 home = 133;
        uint32 away = 101;
        int256 score = encodeScores(home, away, Ordering.HomeVsAway);

        // Create a Winner market on the Game
        bytes32 marketId = oracle.createWinnerMarket(gameId);

        // Push score data to the OO
        GameData memory gameData;
        gameData = oracle.getGame(gameId);
        proposeAndSettle(score, gameData.timestamp, gameData.ancillaryData);

        // Home win on a Home vs Away Game: [1,0]
        uint256[] memory expectedPayouts = new uint256[](2);
        expectedPayouts[0] = 1;
        expectedPayouts[1] = 0;

        vm.expectEmit();
        emit MarketResolved(marketId, expectedPayouts);

        oracle.resolveMarket(marketId);

        // Verify post resolution state
        gameData = oracle.getGame(gameId);
        assertEq(uint8(GameState.Settled), uint8(gameData.state));
        MarketData memory marketData = oracle.getMarket(marketId);
        assertEq(gameId, marketData.gameId);
        assertEq(0, marketData.line);
        assertEq(uint8(MarketType.Winner), uint8(marketData.marketType));
        assertEq(uint8(MarketState.Resolved), uint8(marketData.state));

        // Assert conditional token state post resolution
        bytes32 conditionId = getConditionId(address(oracle), marketId, uint256(2));
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
        GameData memory gameData;
        gameData = oracle.getGame(gameId);
        proposeAndSettle(score, gameData.timestamp, gameData.ancillaryData);

        // Underdog Home loss within spread, Underdog win: [0,1]
        uint256[] memory expectedPayouts = new uint256[](2);
        expectedPayouts[0] = 0;
        expectedPayouts[1] = 1;

        vm.expectEmit();
        emit MarketResolved(marketId, expectedPayouts);

        oracle.resolveMarket(marketId);

        // Verify post resolution state
        gameData = oracle.getGame(gameId);
        assertEq(uint8(GameState.Settled), uint8(gameData.state));

        MarketData memory marketData = oracle.getMarket(marketId);
        assertEq(gameId, marketData.gameId);
        assertEq(line, marketData.line);
        assertEq(uint8(MarketType.Spreads), uint8(marketData.marketType));
        assertEq(uint8(MarketState.Resolved), uint8(marketData.state));

        // Assert conditional token state post resolution
        bytes32 conditionId = getConditionId(address(oracle), marketId, uint256(2));
        // payout denominator is set when condition is resolved
        assertNotEq(0, IConditionalTokens(ctf).payoutDenominator(conditionId));
    }

    function test_resolveMarket_Totals() public {
        test_createGame();

        uint32 home = 133;
        uint32 away = 140;
        uint256 line = 300_500_000;

        // Create a Totals market on the Game
        bytes32 marketId = oracle.createTotalsMarket(gameId, line);

        int256 score = encodeScores(home, away, Ordering.HomeVsAway);

        // Push score data to the OO
        GameData memory gameData;
        gameData = oracle.getGame(gameId);
        proposeAndSettle(score, gameData.timestamp, gameData.ancillaryData);

        // total <= line, under wins: [0,1]
        uint256[] memory expectedPayouts = new uint256[](2);
        expectedPayouts[0] = 0;
        expectedPayouts[1] = 1;

        vm.expectEmit();
        emit MarketResolved(marketId, expectedPayouts);

        oracle.resolveMarket(marketId);

        // Verify post resolution state
        gameData = oracle.getGame(gameId);
        assertEq(uint8(GameState.Settled), uint8(gameData.state));

        MarketData memory marketData = oracle.getMarket(marketId);
        assertEq(gameId, marketData.gameId);
        assertEq(line, marketData.line);
        assertEq(uint8(MarketType.Totals), uint8(marketData.marketType));
        assertEq(uint8(MarketState.Resolved), uint8(marketData.state));

        // Assert conditional token state post resolution
        bytes32 conditionId = getConditionId(address(oracle), marketId, uint256(2));
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
        GameData memory gameData;
        gameData = oracle.getGame(gameId);
        proposeAndSettle(score, gameData.timestamp, gameData.ancillaryData);

        // Home win: [1,0,0]
        uint256[] memory expectedPayouts = new uint256[](2);
        expectedPayouts[0] = 1;
        expectedPayouts[1] = 1;

        vm.expectEmit();
        emit MarketResolved(marketId, expectedPayouts);

        oracle.resolveMarket(marketId);

        // Verify post resolution state
        gameData = oracle.getGame(gameId);
        assertEq(uint8(GameState.Settled), uint8(gameData.state));

        MarketData memory marketData = oracle.getMarket(marketId);
        assertEq(gameId, marketData.gameId);
        assertEq(0, marketData.line);
        assertEq(uint8(MarketType.Winner), uint8(marketData.marketType));
        assertEq(uint8(MarketState.Resolved), uint8(marketData.state));

        // Assert conditional token state post resolution
        bytes32 conditionId = getConditionId(address(oracle), marketId, uint256(2));
        // payout denominator is set when condition is resolved
        assertNotEq(0, IConditionalTokens(ctf).payoutDenominator(conditionId));
    }

    function test_resolveMarket_revert_MarketDoesNotExist() public {
        vm.expectRevert(MarketDoesNotExist.selector);
        oracle.resolveMarket(bytes32(0));
    }

    function test_resolveMarket_revert_GameNotResolvable() public {
        test_createGame();
        bytes32 marketId = oracle.createWinnerMarket(gameId);

        vm.expectRevert(GameNotResolvable.selector);
        oracle.resolveMarket(marketId);
    }

    function test_resolveMarket_revert_MarketCannotBeResolved() public {
        test_createGame();
        bytes32 marketId = oracle.createWinnerMarket(gameId);

        // Pause the market
        vm.prank(admin);
        oracle.pauseMarket(marketId);

        vm.expectRevert(MarketCannotBeResolved.selector);
        oracle.resolveMarket(marketId);
    }

    function test_resolveMarket_emergencySettleGame() public {
        test_createGame();

        bytes32 marketId = oracle.createWinnerMarket(gameId);

        uint32 home = 101;
        uint32 away = 133;
        vm.prank(admin);
        oracle.pauseGame(gameId);

        vm.prank(admin);
        oracle.emergencySettleGame(gameId, home, away);

        uint256[] memory payouts = new uint256[](2);
        payouts[0] = 0;
        payouts[1] = 1;

        vm.expectEmit();
        emit MarketResolved(marketId, payouts);

        oracle.resolveMarket(marketId);

        MarketData memory marketData = oracle.getMarket(marketId);
        assertEq(gameId, marketData.gameId);
        assertEq(0, marketData.line);
        assertEq(uint8(MarketType.Winner), uint8(marketData.marketType));
        assertEq(uint8(MarketState.Resolved), uint8(marketData.state));

        // Assert conditional token state post resolution
        bytes32 conditionId = getConditionId(address(oracle), marketId, uint256(2));
        // payout denominator is set when condition is resolved
        assertNotEq(0, IConditionalTokens(ctf).payoutDenominator(conditionId));
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
            line = convertLine(_line);
        }

        // Create a market on the Game
        bytes32 marketId;
        if (marketType == MarketType.Winner) {
            marketId = oracle.createWinnerMarket(gameId);
        } else if (marketType == MarketType.Spreads) {
            marketId = oracle.createSpreadsMarket(gameId, underdog, line);
        } else {
            marketId = oracle.createTotalsMarket(gameId, line);
        }

        int256 score = encodeScores(home, away, Ordering.HomeVsAway);

        // Push score data to the OO
        GameData memory gameData;
        gameData = oracle.getGame(gameId);
        proposeAndSettle(score, gameData.timestamp, gameData.ancillaryData);

        oracle.resolveMarket(marketId);

        // Verify post resolution state
        gameData = oracle.getGame(gameId);
        assertEq(uint8(GameState.Settled), uint8(gameData.state));

        MarketData memory marketData = oracle.getMarket(marketId);
        assertEq(gameId, marketData.gameId);
        assertEq(line, marketData.line);
        assertEq(uint8(marketType), uint8(marketData.marketType));
        assertEq(uint8(MarketState.Resolved), uint8(marketData.state));

        // Assert conditional token state post resolution
        uint256 outcomeSlotCount = 2;
        bytes32 conditionId = getConditionId(address(oracle), marketId, outcomeSlotCount);
        // payout denominator is set when condition is resolved
        assertNotEq(0, IConditionalTokens(ctf).payoutDenominator(conditionId));
    }

    function test_admin_pauseGame() public {
        test_createGame();

        vm.expectEmit();
        emit GamePaused(gameId);

        vm.prank(admin);
        oracle.pauseGame(gameId);

        GameData memory data = oracle.getGame(gameId);
        assertEq(uint8(GameState.Paused), uint8(data.state));
    }

    function test_admin_pauseGame_revert_NotAdmin() public {
        test_createGame();

        vm.expectRevert(NotAdmin.selector);
        vm.prank(brian);
        oracle.pauseGame(gameId);
    }

    function test_admin_pauseGame_revert_GameDoesNotExist() public {
        vm.expectRevert(GameDoesNotExist.selector);
        vm.prank(admin);
        oracle.pauseGame(gameId);
    }

    function test_admin_pauseGame_revert_GameCannotBePaused() public {
        test_createGame();
        GameData memory gameData = oracle.getGame(gameId);
        int256 data = encodeScores(101, 133, Ordering.HomeVsAway);
        proposeAndSettle(data, gameData.timestamp, gameData.ancillaryData);

        vm.expectRevert(GameCannotBePaused.selector);
        vm.prank(admin);
        oracle.pauseGame(gameId);
    }

    function test_admin_emergencySettleGame() public {
        test_admin_pauseGame();

        uint32 home = 101;
        uint32 away = 133;

        vm.expectEmit();
        emit GameEmergencySettled(gameId, home, away);

        vm.prank(admin);
        oracle.emergencySettleGame(gameId, home, away);

        GameData memory gameData = oracle.getGame(gameId);
        assertEq(uint8(GameState.EmergencySettled), uint8(gameData.state));
        assertEq(home, gameData.homeScore);
        assertEq(away, gameData.awayScore);
    }

    function test_admin_emergencySettleGame_revert_GameCannotBeEmergencySettled() public {
        test_createGame();

        vm.expectRevert(GameCannotBeEmergencySettled.selector);

        vm.prank(admin);
        oracle.emergencySettleGame(gameId, 101, 133);
    }

    function test_admin_emergencySettleGame_revert_GameDoesNotExist() public {
        vm.expectRevert(GameDoesNotExist.selector);

        vm.prank(admin);
        oracle.emergencySettleGame(gameId, 101, 133);
    }

    function test_admin_unpauseGame() public {
        test_admin_pauseGame();

        vm.expectEmit();
        emit GameUnpaused(gameId);

        vm.prank(admin);
        oracle.unpauseGame(gameId);

        GameData memory data = oracle.getGame(gameId);
        assertEq(uint8(GameState.Created), uint8(data.state));
    }

    function test_admin_unpauseGame_revert_GameDoesNotExist() public {
        vm.expectRevert(GameDoesNotExist.selector);
        vm.prank(admin);
        oracle.unpauseGame(gameId);
    }

    function test_admin_unpauseGame_revert_GameCannotBeUnpaused() public {
        test_createGame();
        GameData memory gameData = oracle.getGame(gameId);
        int256 data = encodeScores(101, 133, Ordering.HomeVsAway);
        proposeAndSettle(data, gameData.timestamp, gameData.ancillaryData);
        vm.expectRevert(GameCannotBeUnpaused.selector);

        vm.prank(admin);
        oracle.unpauseGame(gameId);
    }

    function test_admin_pauseMarket() public {
        test_createGame();
        vm.prank(admin);
        bytes32 marketId = oracle.createWinnerMarket(gameId);

        vm.prank(admin);
        oracle.pauseMarket(marketId);

        MarketData memory marketData = oracle.getMarket(marketId);
        assertEq(uint8(MarketState.Paused), uint8(marketData.state));
    }

    function test_admin_pauseMarket_revert_MarketDoesNotExist() public {
        vm.expectRevert(MarketDoesNotExist.selector);
        vm.prank(admin);
        oracle.pauseMarket(bytes32(0));
    }

    function test_admin_pauseMarket_revert_MarketCannotBePaused() public {
        test_resolveMarket_Winner();
        bytes32 marketId = getMarketId(gameId, MarketType.Winner, Underdog.Home, 0, address(this));

        vm.expectRevert(MarketCannotBePaused.selector);
        vm.prank(admin);
        oracle.pauseMarket(marketId);
    }

    function test_admin_unpauseMarket() public {
        test_admin_pauseMarket();
        bytes32 marketId = getMarketId(gameId, MarketType.Winner, Underdog.Home, 0, admin);

        vm.expectEmit();
        emit MarketUnpaused(marketId);

        vm.prank(admin);
        oracle.unpauseMarket(marketId);

        MarketData memory marketData = oracle.getMarket(marketId);
        assertEq(uint8(MarketState.Created), uint8(marketData.state));
    }

    function test_admin_unpauseMarket_revert_MarketDoesNotExist() public {
        vm.expectRevert(MarketDoesNotExist.selector);
        vm.prank(admin);
        oracle.unpauseMarket(bytes32(0));
    }

    function test_admin_unpauseMarket_revert_MarketCannotBeUnpaused() public {
        test_resolveMarket_Winner();
        bytes32 marketId = getMarketId(gameId, MarketType.Winner, Underdog.Home, 0, address(this));

        vm.expectRevert(MarketCannotBeUnpaused.selector);
        vm.prank(admin);
        oracle.unpauseMarket(marketId);
    }

    function test_admin_emergencyResolveMarket() public {
        test_createGame();
        vm.prank(admin);
        bytes32 marketId = oracle.createWinnerMarket(gameId);

        vm.prank(admin);
        oracle.pauseMarket(marketId);

        uint256[] memory payouts = new uint256[](2);
        payouts[0] = 0;
        payouts[1] = 1;

        vm.expectEmit();
        emit MarketEmergencyResolved(marketId, payouts);

        vm.prank(admin);
        oracle.emergencyResolveMarket(marketId, payouts);

        MarketData memory marketData = oracle.getMarket(marketId);
        assertEq(uint8(MarketState.EmergencyResolved), uint8(marketData.state));
    }

    function test_admin_emergencyResolveMarket_revert_MarketDoesNotExist() public {
        uint256[] memory payouts = new uint256[](2);
        payouts[0] = 0;
        payouts[1] = 1;
        vm.expectRevert(MarketDoesNotExist.selector);

        vm.prank(admin);
        oracle.emergencyResolveMarket(bytes32(0), payouts);
    }

    function test_admin_emergencyResolveMarket_revert_MarketCannotBeEmergencyResolved() public {
        test_resolveMarket_Winner();

        bytes32 marketId = getMarketId(gameId, MarketType.Winner, Underdog.Home, 0, address(this));

        uint256[] memory payouts = new uint256[](2);
        payouts[0] = 0;
        payouts[1] = 1;
        vm.expectRevert(MarketCannotBeEmergencyResolved.selector);

        vm.prank(admin);
        oracle.emergencyResolveMarket(marketId, payouts);
    }

    function test_admin_setBond(uint256 bond) public {
        vm.assume(bond > 0 && bond < 100_000_000_000);

        test_createGame();

        vm.expectEmit();
        emit BondUpdated(gameId, bond);

        vm.prank(admin);
        oracle.setBond(gameId, bond);

        GameData memory gameData = oracle.getGame(gameId);
        assertEq(bond, gameData.bond);
    }

    function test_admin_setLiveness(uint256 liveness) public {
        vm.assume(liveness > 0 && liveness < 5200 weeks);

        test_createGame();

        vm.expectEmit();
        emit LivenessUpdated(gameId, liveness);

        vm.prank(admin);
        oracle.setLiveness(gameId, liveness);

        GameData memory gameData = oracle.getGame(gameId);
        assertEq(liveness, gameData.liveness);
    }

    function test_admin_resetGame() public {
        test_createGame();

        fastForward(10);

        vm.expectEmit();
        emit GameReset(gameId);

        vm.prank(admin);
        oracle.resetGame(gameId);
    }

    function test_admin_resetGame_refundAvailable() public {
        test_createGame();

        fastForward(10);

        GameData memory gameData;
        gameData = oracle.getGame(gameId);

        // Propose and dispute the game 2x, refunding the reward to the Oracle
        int256 data = encodeScores(uint32(101), uint32(133), Ordering.HomeVsAway);
        proposeAndDispute(data, gameData.timestamp, gameData.ancillaryData);

        fastForward(10);

        gameData = oracle.getGame(gameId);
        proposeAndDispute(data, gameData.timestamp, gameData.ancillaryData);

        vm.expectEmit();
        emit Transfer(address(oracle), admin, gameData.reward);

        vm.prank(admin);
        oracle.resetGame(gameId);
    }

    function test_admin_resetGame_GameDoesNotExist() public {
        vm.expectRevert(GameDoesNotExist.selector);
        vm.prank(admin);
        oracle.resetGame(gameId);
    }

    function test_admin_resetGame_GameCannotBeReset() public {
        test_priceSettled(101, 133);
        vm.expectRevert(GameCannotBeReset.selector);

        vm.prank(admin);
        oracle.resetGame(gameId);
    }

    function test_priceSettled(uint32 home, uint32 away) public {
        test_createGame();

        // Propose a price and settle it on the OO
        GameData memory gameData;
        gameData = oracle.getGame(gameId);
        int256 data = encodeScores(home, away, Ordering.HomeVsAway);

        emit GameSettled(gameId, home, away);
        proposeAndSettle(data, gameData.timestamp, gameData.ancillaryData);

        // Verify state post settlement
        gameData = oracle.getGame(gameId);
        assertEq(uint8(GameState.Settled), uint8(gameData.state));
        assertEq(home, gameData.homeScore);
        assertEq(away, gameData.awayScore);
    }

    function test_priceSettled_alreadySettled(uint32 home, uint32 away) public {
        test_createGame();

        // Emergency settle the game
        vm.prank(admin);
        oracle.pauseGame(gameId);
        vm.prank(admin);
        oracle.emergencySettleGame(gameId, home, away);

        // Propose a price and settle it on the OO, but the Game is already settled. Should no-op
        GameData memory gameData;
        gameData = oracle.getGame(gameId);

        uint256 timestamp = gameData.timestamp;

        int256 data = encodeScores(home, away, Ordering.HomeVsAway);
        proposeAndSettle(data, gameData.timestamp, gameData.ancillaryData);

        gameData = oracle.getGame(gameId);
        // No change in timestamp
        assertEq(timestamp, gameData.timestamp);
    }

    function test_priceSettled_oldRequestSettle(uint32 home, uint32 away) public {
        test_createGame();

        GameData memory gameData;
        gameData = oracle.getGame(gameId);

        uint256 timestamp = gameData.timestamp;

        int256 data = encodeScores(home, away, Ordering.HomeVsAway);
        // Propose + dispute
        proposeAndDispute(data, timestamp, gameData.ancillaryData);
        gameData = oracle.getGame(gameId);
        // Propose + dispute again
        proposeAndDispute(data, gameData.timestamp, gameData.ancillaryData);

        // The first request was processed by the DVM first
        // Settle the first request, this should no-op since we ignore the older request
        voting.setPriceExists(true);
        voting.setPrice(data);
        settle(timestamp, gameData.ancillaryData);

        gameData = oracle.getGame(gameId);
        assertTrue(gameData.timestamp > timestamp);
    }

    function test_priceDisputed_singleDispute(uint32 home, uint32 away) public {
        test_createGame();
        GameData memory gameData;
        gameData = oracle.getGame(gameId);

        uint256 initialTimestamp = gameData.timestamp;
        bytes memory ancData = gameData.ancillaryData;
        int256 data = encodeScores(home, away, Ordering.HomeVsAway);

        // propose
        propose(data, initialTimestamp, ancData);

        // Dispute it
        dispute(initialTimestamp, ancData);

        // Verify state
        // We expect to have a new OO request with on the oracle
        gameData = oracle.getGame(gameId);
        assertTrue(gameData.timestamp > initialTimestamp);
        assertTrue(gameData.reset);
    }

    function test_priceDisputed_doubleDispute_validData(uint32 home, uint32 away) public {
        test_createGame();
        GameData memory gameData;
        gameData = oracle.getGame(gameId);

        uint256 initialTimestamp = gameData.timestamp;
        bytes memory ancData = gameData.ancillaryData;
        int256 data = encodeScores(home, away, Ordering.HomeVsAway);

        // propose and dispute it
        proposeAndDispute(data, initialTimestamp, ancData);

        // propose and dispute it again, pushing resolution to the DVM
        gameData = oracle.getGame(gameId);
        proposeAndDispute(data, gameData.timestamp, gameData.ancillaryData);
        gameData = oracle.getGame(gameId);

        // Validate that the oracle now holds the reward
        assertEq(gameData.reward, IERC20(usdc).balanceOf(address(oracle)));
        // Validate that the refund flag is set
        assertTrue(gameData.refund);

        // Push the score to the DVM
        voting.setPriceExists(true);
        voting.setPrice(data);

        // Settle the Game, updating the scores
        vm.expectEmit();

        // Validate the reward refund to the creator
        emit Transfer(address(oracle), gameData.creator, gameData.reward);

        emit GameSettled(gameId, home, away);

        settle(gameData.timestamp, gameData.ancillaryData);

        gameData = oracle.getGame(gameId);

        assertEq(uint8(GameState.Settled), uint8(gameData.state));
        assertEq(home, gameData.homeScore);
        assertEq(away, gameData.awayScore);
    }

    function test_priceDisputed_doubleDispute_ignore(uint32 home, uint32 away) public {
        test_createGame();
        GameData memory gameData;
        gameData = oracle.getGame(gameId);

        uint256 initialTimestamp = gameData.timestamp;
        bytes memory ancData = gameData.ancillaryData;
        int256 data = encodeScores(home, away, Ordering.HomeVsAway);

        // propose and dispute it
        propose(data, initialTimestamp, ancData);
        dispute(initialTimestamp, ancData);

        // propose and dispute it again, pushing resolution to the DVM
        gameData = oracle.getGame(gameId);
        propose(data, gameData.timestamp, gameData.ancillaryData);
        dispute(gameData.timestamp, gameData.ancillaryData);
        gameData = oracle.getGame(gameId);

        // Push the ignore data to the DVM
        voting.setPriceExists(true);
        voting.setPrice(type(int256).min);

        // Settle the Game, since the data is the ignore data, should reset the game
        vm.expectEmit();
        emit GameReset(gameId);

        settle(gameData.timestamp, gameData.ancillaryData);

        gameData = oracle.getGame(gameId);
        assertEq(uint8(GameState.Created), uint8(gameData.state));
    }

    function test_priceDisputed_doubleDispute_canceled(uint32 home, uint32 away) public {
        test_createGame();
        GameData memory gameData;
        gameData = oracle.getGame(gameId);

        uint256 initialTimestamp = gameData.timestamp;
        bytes memory ancData = gameData.ancillaryData;
        int256 data = encodeScores(home, away, Ordering.HomeVsAway);

        // propose and dispute it
        propose(data, initialTimestamp, ancData);
        dispute(initialTimestamp, ancData);

        // propose and dispute it again, pushing resolution to the DVM
        gameData = oracle.getGame(gameId);
        propose(data, gameData.timestamp, gameData.ancillaryData);
        dispute(gameData.timestamp, gameData.ancillaryData);
        gameData = oracle.getGame(gameId);

        // Push the canceled data to the DVM
        voting.setPriceExists(true);
        voting.setPrice(type(int256).max);

        // Settle the Game, since the data is the canceled data, should set the Game to canceled
        vm.expectEmit();
        emit GameCanceled(gameId);

        settle(gameData.timestamp, gameData.ancillaryData);

        gameData = oracle.getGame(gameId);
        assertEq(uint8(GameState.Canceled), uint8(gameData.state));
    }

    function test_priceDisputed_AlreadySettled(uint32 home, uint32 away) public {
        test_createGame();
        GameData memory gameData;
        gameData = oracle.getGame(gameId);

        uint256 initialTimestamp = gameData.timestamp;
        bytes memory ancData = gameData.ancillaryData;
        int256 data = encodeScores(home, away, Ordering.HomeVsAway);

        // Emergency settle the game
        vm.prank(admin);
        oracle.pauseGame(gameId);
        vm.prank(admin);
        oracle.emergencySettleGame(gameId, home, away);

        // propose and dispute it
        // Since the Game is already settled, the callback will refund the creator
        propose(data, initialTimestamp, ancData);
        vm.expectEmit();
        emit Transfer(address(oracle), admin, gameData.reward);

        dispute(initialTimestamp, ancData);

        gameData = oracle.getGame(gameId);
        assertEq(initialTimestamp, gameData.timestamp);
    }

    function test_priceDisputed_oldRequestDisputes(uint32 home, uint32 away) public {
        // creates and sends out OO req1
        test_createGame();
        fastForward(1);

        GameData memory gameData;
        gameData = oracle.getGame(gameId);

        uint256 timestamp = gameData.timestamp;
        int256 data = encodeScores(home, away, Ordering.HomeVsAway);

        // Admin resets game, creating OO req2
        vm.prank(admin);
        oracle.resetGame(gameId);
        gameData = oracle.getGame(gameId);

        // Settle req2, settling the Game via the callback
        proposeAndSettle(data, gameData.timestamp, gameData.ancillaryData);

        // Dispute req1, will no-op, because there is a more recent request
        propose(data, timestamp, gameData.ancillaryData);
        dispute(timestamp, gameData.ancillaryData);

        gameData = oracle.getGame(gameId);

        // Game remains the same
        gameData = oracle.getGame(gameId);
        assertEq(uint8(GameState.Settled), uint8(gameData.state));
        assertTrue(gameData.timestamp > timestamp);
    }
}
