// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {MarketType, GameData, MarketData, Ordering} from "../libraries/Structs.sol";

interface IUmaSportsOracleEE {
    error UnsupportedToken();
    error InvalidAncillaryData();

    error Paused();

    error MarketAlreadyCreated();
    error GameDoesNotExist();

    error CannotRequestGame();

    error InvalidLine();
    error InvalidBond();

    /// @notice Emitted when a Game is created
    event GameCreated(bytes32 indexed gameId, uint256 indexed reward, uint256 indexed bond);

    /// @notice Emitted when a Market is created
    event MarketCreated(bytes32 indexed marketId, bytes32 indexed gameId, uint8 marketType, uint256 line);
}

interface IUmaSportsOracle is IUmaSportsOracleEE {
    function createGame(
        bytes memory ancillaryData,
        Ordering order,
        address rewardToken,
        uint256 reward,
        uint256 bond,
        uint256 liveness
    ) external returns (bytes32);
}
