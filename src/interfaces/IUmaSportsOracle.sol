// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {MarketType, GameData, MarketData, Ordering} from "../libraries/Structs.sol";

interface IUmaSportsOracleEE {
    error UnsupportedToken();
    error InvalidAncillaryData();

    error Paused();

    error MarketAlreadyCreated();
    error GameAlreadyCreated();
    error GameDoesNotExist();

    error CannotRequestGame();

    error InvalidLine();
    error InvalidBond();

    /// @notice Emitted when a Game is created
    event GameCreated(bytes32 indexed gameId, bytes ancillaryData, uint256 timestamp);

    /// @notice Emitted when a Market is created
    event MarketCreated(bytes32 indexed marketId, bytes32 indexed gameId, uint8 marketType, uint256 line);
}

interface IUmaSportsOracle is IUmaSportsOracleEE {
    function createGame(
        bytes memory ancillaryData,
        Ordering ordering,
        address token,
        uint256 reward,
        uint256 bond,
        uint256 liveness
    ) external returns (bytes32);

    function createMarket(bytes32 gameId, MarketType marketType, uint256 line) external returns (bytes32 marketId);

    function getGame(bytes32 gameId) external view returns (GameData memory);

    function getMarket(bytes32 marketId) external view returns (MarketData memory);

    function ready(bytes32 gameId) external view returns (bool);

    function isGameCreated(bytes32 gameId) external view returns (bool);
}
