// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {MarketType, GameData, MarketData, Ordering} from "../libraries/Structs.sol";

interface IUmaSportsOracleEE {
    error UnsupportedToken();
    error InvalidAncillaryData();
    error GameAlreadyCreated();
    error GameDoesNotExist();

    error MarketAlreadyCreated();
    error InvalidGame();
    error InvalidLine();
    error InvalidBond();

    error GameInInvalidSettleState();
    error DataDoesNotExist();

    error Paused();

    /// @notice Emitted when a Game is created
    event GameCreated(bytes32 indexed gameId, bytes ancillaryData, uint256 timestamp);

    /// @notice Emitted when a Market is created
    event MarketCreated(
        bytes32 indexed marketId, bytes32 indexed gameId, bytes32 indexed conditionId, uint8 marketType, uint256 line
    );

    event GameCanceled(bytes32 indexed gameId);

    event GameReset(bytes32 indexed gameId);

    /// @notice Emitted when a Game is settled
    event GameSettled(bytes32 indexed gameId, uint256 indexed home, uint256 indexed away);

    // TODO: fill in natspec
    event GameEmergencySettled(bytes32 indexed gameId, uint256 home, uint256 indexed away);

    event MarketResolved(bytes32 indexed marketId, uint256[] payouts);

    event MarketEmergencyResolved(bytes32 indexed marketId, uint256[] payouts);

    event GamePaused(bytes32 indexed gameId);

    event GameUnpaused(bytes32 indexed gameId);

    event MarketPaused(bytes32 indexed marketId);

    event MarketUnpaused(bytes32 indexed marketId);
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
