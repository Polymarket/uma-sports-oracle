// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {OracleSetup} from "./dev/OracleSetup.sol";

import {IConditionalTokens} from "src/interfaces/IConditionalTokens.sol";
import {IOptimisticOracleV2} from "src/interfaces/IOptimisticOracleV2.sol";

import {IAddressWhitelistMock} from "./interfaces/IAddressWhitelistMock.sol";
import {IOptimisticOracleV2Mock} from "./interfaces/IOptimisticOracleV2Mock.sol";

import {AncillaryDataLib} from "src/libraries/AncillaryDataLib.sol";
import {Ordering, GameData, GameState, MarketState, MarketType, MarketData} from "src/libraries/Structs.sol";

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

    function test_createMarket() public {
        test_createGame();
        MarketType marketType = MarketType.WinnerBinary;
        uint256 line = 0;

        bytes32 marketId = oracle.getMarketId(gameId, marketType, line, admin);
        bytes32 conditionId = keccak256(abi.encodePacked(address(oracle), marketId, uint256(2)));

        vm.expectEmit();
        emit MarketCreated(marketId, gameId, conditionId, uint8(marketType), line);

        vm.prank(admin);
        oracle.createMarket(gameId, marketType, line);

        MarketData memory marketData = oracle.getMarket(marketId);

        // Verify the Market's state post creation
        assertEq(gameId, marketData.gameId);
        assertEq(line, marketData.line);
        assertEq(uint8(MarketType.WinnerBinary), uint8(marketData.marketType));
        assertEq(uint8(MarketState.Created), uint8(marketData.state));
    }

    function test_createMarket_fuzz(uint256 _line, uint8 _marketType) public {
        test_createGame();

        _marketType = uint8(bound(_marketType, 0, 3));
        MarketType marketType = MarketType(_marketType);

        if (marketType == MarketType.WinnerBinary || marketType == MarketType.WinnerDraw) {
            _line = 0;
        }

        uint256 outcomeCount = 2;
        if (marketType == MarketType.WinnerDraw) {
            outcomeCount = 3;
        }

        bytes32 marketId = oracle.getMarketId(gameId, marketType, _line, admin);
        bytes32 conditionId = keccak256(abi.encodePacked(address(oracle), marketId, outcomeCount));

        vm.expectEmit();
        emit MarketCreated(marketId, gameId, conditionId, _marketType, _line);

        vm.prank(admin);
        oracle.createMarket(gameId, marketType, _line);

        MarketData memory marketData = oracle.getMarket(marketId);

        assertEq(gameId, marketData.gameId);
        assertEq(_line, marketData.line);
        assertEq(uint8(marketType), uint8(marketData.marketType));
        assertEq(uint8(MarketState.Created), uint8(marketData.state));
    }

    function test_createMarket_revert_GameDoesNotExist() public {
        vm.expectRevert(GameDoesNotExist.selector);
        vm.prank(admin);
        oracle.createMarket(gameId, MarketType.WinnerBinary, 0);
    }

    function test_createMarket_revert_InvalidLine() public {
        test_createGame();

        vm.expectRevert(InvalidLine.selector);
        vm.prank(admin);
        oracle.createMarket(gameId, MarketType.WinnerBinary, 100);
    }

    function test_createMarket_revert_MarketAlreadyCreated() public {
        test_createMarket();

        vm.expectRevert(MarketAlreadyCreated.selector);
        vm.prank(admin);
        oracle.createMarket(gameId, MarketType.WinnerBinary, 0);
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

        vm.prank(admin);
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

        vm.prank(admin);
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

        vm.prank(admin);
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
        vm.prank(admin);
        oracle.settleGame(gameId);
    }

    function test_settleGame_revert_GameCannotBeSettled() public {
        test_settleGame(132, 100);
        vm.expectRevert(GameCannotBeSettled.selector);
        vm.prank(admin);
        oracle.settleGame(gameId);
    }

    function test_settleGame_revert_DataDoesNotExist() public {
        test_createGame();
        vm.expectRevert(DataDoesNotExist.selector);

        vm.prank(admin);
        oracle.settleGame(gameId);
    }
}
