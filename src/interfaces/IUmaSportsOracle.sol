// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {MarketType, GameData, MarketData, Ordering, Underdog} from "../libraries/Structs.sol";

interface IUmaSportsOracleEE {
    error UnsupportedToken();
    error InvalidAncillaryData();
    error GameAlreadyCreated();
    error GameDoesNotExist();

    error MarketAlreadyCreated();
    error MarketDoesNotExist();
    error InvalidGame();
    error InvalidLine();

    error GameNotResolvable();

    error GameCannotBePaused();
    error GameCannotBeUnpaused();
    error GameCannotBeEmergencySettled();

    error MarketCannotBeResolved();
    error MarketCannotBePaused();
    error MarketCannotBeUnpaused();
    error MarketCannotBeEmergencyResolved();

    error InvalidRequestState();

    error NotOptimisticOracle();

    error GameCannotBeReset();

    error InvalidPayouts();

    /// @notice Emitted when a Game is created
    event GameCreated(bytes32 indexed gameId, uint8 ordering, bytes ancillaryData, uint256 timestamp);

    /// @notice Emitted when a Market is created
    event MarketCreated(
        bytes32 indexed marketId,
        bytes32 indexed gameId,
        bytes32 indexed conditionId,
        uint8 marketType,
        uint8 underdog,
        uint256 line
    );

    /// @notice Emitted when a Game is Canceled
    event GameCanceled(bytes32 indexed gameId);

    /// @notice Emitted when a Game is Reset
    event GameReset(bytes32 indexed gameId);

    /// @notice Emitted when a Game is settled
    event GameSettled(bytes32 indexed gameId, uint256 indexed home, uint256 indexed away);

    /// @notice Emitted when a Game is emergency settled
    event GameEmergencySettled(bytes32 indexed gameId, uint256 indexed home, uint256 indexed away);

    /// @notice Emitted when a Market is resolved
    event MarketResolved(bytes32 indexed marketId, uint256[] payouts);

    /// @notice Emitted when a Market is emergency resolved
    event MarketEmergencyResolved(bytes32 indexed marketId, uint256[] payouts);

    /// @notice Emitted when a Game is paused
    event GamePaused(bytes32 indexed gameId);

    /// @notice Emitted when a Game is unpaused
    event GameUnpaused(bytes32 indexed gameId);

    /// @notice Emitted when a Market is paused
    event MarketPaused(bytes32 indexed marketId);

    /// @notice Emitted when a Market is unpaused
    event MarketUnpaused(bytes32 indexed marketId);

    /// @notice Emitted when a Game's bond is updated
    event BondUpdated(bytes32 indexed gameId, uint256 indexed updatedBond);

    /// @notice Emitted when a Game's liveness is updated
    event LivenessUpdated(bytes32 indexed gameId, uint256 indexed updatedLiveness);
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

    function createWinnerMarket(bytes32 gameId) external returns (bytes32);

    function createSpreadsMarket(bytes32 gameId, Underdog underdog, uint256 line) external returns (bytes32);

    function createTotalsMarket(bytes32 gameId, uint256 line) external returns (bytes32);

    function resolveMarket(bytes32 marketId) external;

    function pauseGame(bytes32 gameId) external;

    function unpauseGame(bytes32 gameId) external;

    function resetGame(bytes32 gameId) external;

    function emergencySettleGame(bytes32 gameId, uint32 home, uint32 away) external;

    function pauseMarket(bytes32 marketId) external;

    function unpauseMarket(bytes32 marketId) external;

    function emergencyResolveMarket(bytes32 marketId, uint256[] memory payouts) external;

    function getGame(bytes32 gameId) external view returns (GameData memory);

    function getMarket(bytes32 marketId) external view returns (MarketData memory);
}
