// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {OracleSetup} from "./dev/OracleSetup.sol";
import {console2 as console} from "lib/forge-std/src/Test.sol";

import {IConditionalTokens} from "src/interfaces/IConditionalTokens.sol";
import {IOptimisticOracleV2} from "src/interfaces/IOptimisticOracleV2.sol";

import { IAddressWhitelistMock } from "./interfaces/IAddressWhitelistMock.sol";

import {AncillaryDataLib} from "src/libraries/AncillaryDataLib.sol";
import {Ordering, GameData, GameState} from "src/libraries/Structs.sol";

contract UmaSportsOracleTest is OracleSetup {
    function test_initialState() public view {
        assertEq(ctf, address(oracle.ctf()));
        assertEq(optimisticOracle, address(oracle.optimisticOracle()));
        assertEq(whitelist, address(oracle.addressWhitelist()));
        assertTrue(oracle.isAdmin(admin));
    }

    function test_createGame(uint256 _reward, uint256 _bond, uint256 _liveness, uint8 _ordering, uint256 _data)
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
        bytes32 gameId = oracle.createGame(data, ordering, usdc, _reward, _bond, _liveness);

        // Verify state post game creation
        assertEq(expectedGameId, gameId);
        GameData memory gameData = oracle.getGame(gameId);
        assertEq(admin, gameData.creator);
        assertEq(_reward, gameData.reward);
        assertEq(uint8(GameState.Created), uint8(gameData.state));
        assertEq(_liveness, gameData.liveness);
        assertEq(expectedAncillaryData, gameData.ancillaryData);
    }

    function test_revert_createGameAlreadyCreated(
        uint256 _reward,
        uint256 _bond,
        uint256 _liveness,
        uint8 _ordering,
        uint256 _data
    ) public {
        _ordering = uint8(bound(_ordering, 0, 1));
        Ordering ordering = Ordering(_ordering);

        bytes memory data = abi.encodePacked(bound(_data, 1, 1000));

        deal(usdc, admin, _reward);

        vm.prank(admin);
        oracle.createGame(data, ordering, usdc, _reward, _bond, _liveness);

        vm.expectRevert(GameAlreadyCreated.selector);
        vm.prank(admin);
        oracle.createGame(data, ordering, usdc, _reward, _bond, _liveness);
    }

    function test_revert_createGameUnsupportedToken(
        uint256 _reward,
        uint256 _bond,
        uint256 _liveness,
        uint8 _ordering,
        uint256 _data
    ) public {
        _ordering = uint8(bound(_ordering, 0, 1));
        Ordering ordering = Ordering(_ordering);

        bytes memory data = abi.encodePacked(bound(_data, 1, 1000));

        IAddressWhitelistMock(whitelist).setIsOnWhitelist(false);

        vm.expectRevert(UnsupportedToken.selector);
        vm.prank(admin);
        oracle.createGame(data, ordering, usdc, _reward, _bond, _liveness);
    }

    function test_revert_createGameInvalidAncillaryData(
        uint256 _reward,
        uint256 _bond,
        uint256 _liveness,
        uint8 _ordering
    ) public {
        _ordering = uint8(bound(_ordering, 0, 1));
        Ordering ordering = Ordering(_ordering);

        bytes memory data = hex"";

        vm.expectRevert(InvalidAncillaryData.selector);
        vm.prank(admin);
        oracle.createGame(data, ordering, usdc, _reward, _bond, _liveness);
    }

    function test_createMarket() public {}
}
