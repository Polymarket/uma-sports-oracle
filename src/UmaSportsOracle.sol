// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Auth} from "./modules/Auth.sol";
import {ConditionalTokensModule} from "./modules/ConditionalTokensModule.sol";

import {ScoreDecoderLib} from "./libraries/ScoreDecoderLib.sol";
import {AncillaryDataLib} from "./libraries/AncillaryDataLib.sol";
import {Ordering, MarketType, MarketData, MarketState, GameState, GameData} from "./libraries/Structs.sol";

import {IFinder} from "./interfaces/IFinder.sol";
import {IUmaSportsOracle} from "./interfaces/IUmaSportsOracle.sol";
import {IAddressWhitelist} from "./interfaces/IAddressWhitelist.sol";
import {IOptimisticOracleV2} from "./interfaces/IOptimisticOracleV2.sol";

import {ERC20, SafeTransferLib} from "lib/solmate/src/utils/SafeTransferLib.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/// @title UmaSportsOracle
/// @notice Oracle contract for Sports games
/// @author Jon Amenechi (jon@polymarket.com)
contract UmaSportsOracle is IUmaSportsOracle, Auth, ConditionalTokensModule {
    /*///////////////////////////////////////////////////////////////////
                            IMMUTABLES 
    //////////////////////////////////////////////////////////////////*/

    /// @notice Optimistic Oracle
    IOptimisticOracleV2 public immutable optimisticOracle;

    /// @notice Collateral Whitelist
    IAddressWhitelist public immutable addressWhitelist;

    /*///////////////////////////////////////////////////////////////////
                            CONSTANTS 
    //////////////////////////////////////////////////////////////////*/

    /// @notice Time period after which an admin can emergency resolve a Game or Market
    uint256 public constant EMERGENCY_SAFETY_PERIOD = 2 days;

    /// @notice Unique query identifier for the Optimistic Oracle
    bytes32 public constant OO_IDENTIFIER = "MOCK_SPORTS_IDENTIFIER";

    // TODO: replace CTF module with just functions on the oracle?

    /*///////////////////////////////////////////////////////////////////
                            STATE 
    //////////////////////////////////////////////////////////////////*/

    /// @notice Mapping of gameId to Games
    mapping(bytes32 => GameData) public games;

    /// @notice Mapping of marketId to Markets
    mapping(bytes32 => MarketData) public markets;

    // TODO: is the finder really necessary?
    constructor(address _ctf, address _finder) ConditionalTokensModule(_ctf) {
        IFinder finder = IFinder(_finder);
        optimisticOracle = IOptimisticOracleV2(finder.getImplementationAddress("OptimisticOracleV2"));
        addressWhitelist = IAddressWhitelist(finder.getImplementationAddress("CollateralWhitelist"));
    }

    /*///////////////////////////////////////////////////////////////////
                            PUBLIC 
    //////////////////////////////////////////////////////////////////*/

    /// @notice Creates a Game
    /// @param ancillaryData    - Data used to resolve a Game
    /// @param ordering         - The Ordering(home vs away or vice versa) of the Game
    /// @param token            - The token used for rewards and bonds
    /// @param reward           - The reward paid to successful proposers and disputers
    /// @param bond             - The bond put up by OO proposers and disputers
    /// @param liveness         - The liveness period, will be the default liveness period if 0.
    function createGame(
        bytes memory ancillaryData,
        Ordering ordering,
        address token,
        uint256 reward,
        uint256 bond,
        uint256 liveness
    ) external returns (bytes32 gameId) {
        // Verify the token used for OO rewards and bonds
        if (!addressWhitelist.isOnWhitelist(token)) revert UnsupportedToken();

        // Verify the ancillary data
        bytes memory data = AncillaryDataLib.appendAncillaryData(msg.sender, ancillaryData);
        if (ancillaryData.length == 0 || !AncillaryDataLib.isValidAncillaryData(data)) revert InvalidAncillaryData();

        gameId = keccak256(data);

        // Verify that the game is unique
        if (isGameCreated(gameId)) revert GameAlreadyCreated();

        uint256 timestamp = block.timestamp;

        // Store game
        _saveGame(gameId, msg.sender, timestamp, data, ordering, token, reward, bond, liveness);

        // Send out OO data request
        _requestData(msg.sender, timestamp, data, token, reward, bond, liveness);

        emit GameCreated(gameId, data, timestamp);
        return gameId;
    }

    /// @notice Creates a Market based on an underlying Game
    /// @dev Creates the underlying CTF market based on the marketId
    /// @param gameId       - The unique Id of a Game to be linked to the Market
    /// @param marketType   - The marketType of the Market
    /// @param line         - The line of the Market. 0 if the marketType is type Winner
    function createMarket(bytes32 gameId, MarketType marketType, uint256 line) external returns (bytes32 marketId) {
        GameData storage gameData = games[gameId];

        // Validate that the Game exists
        if (!_isGameCreated(gameData)) revert GameDoesNotExist();

        // Validate that we can create a Market from the Game
        if (gameData.state != GameState.Created) revert InvalidGame();

        // Validate the marketType and line
        if (line > 0 && (marketType == MarketType.WinnerBinary || marketType == MarketType.WinnerDraw)) {
            revert InvalidLine();
        }

        marketId = getMarketId(gameId, marketType, line, msg.sender);

        // Validate that the market is unique
        if (isMarketCreated(marketId)) revert MarketAlreadyCreated();

        // Store the Market
        _saveMarket(marketId, gameId, line, marketType);

        // Create the underlying CTF market
        bytes32 conditionId = _prepareMarket(marketId, marketType);

        emit MarketCreated(marketId, gameId, conditionId, uint8(marketType), line);
        return marketId;
    }

    /// @notice Settles a Game by fetching scores from the OO and setting them on the Oracle
    /// @param gameId   - The unique GameId
    function settleGame(bytes32 gameId) external {
        GameData storage gameData = games[gameId];

        // Ensure that the Game exists
        if (!_isGameCreated(gameData)) revert GameDoesNotExist();

        // Only a Game in state Created can be settled
        if (gameData.state != GameState.Created) revert GameCannotBeSettled();
        // Can only settle a game with valid OO data
        if (!_dataExists(gameData.timestamp, gameData.ancillaryData)) revert DataDoesNotExist();

        // Settle the game
        _settle(gameId, gameData);
    }

    /// @notice Resolves a Market using the scores of a Settled Game
    /// @param marketId -   The unique marketId
    function resolveMarket(bytes32 marketId) external {
        // TODO
    }

    /*///////////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS 
    //////////////////////////////////////////////////////////////////*/

    /// @notice Checks if a Game is ready to be settled
    /// @param gameId   - The unique GameId
    function ready(bytes32 gameId) public view returns (bool) {
        return _ready(games[gameId]);
    }

    function getMarketId(bytes32 gameId, MarketType marketType, uint256 line, address creator)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(gameId, marketType, line, creator));
    }

    function getGame(bytes32 gameId) external view returns (GameData memory) {
        return games[gameId];
    }

    function getMarket(bytes32 marketId) external view returns (MarketData memory) {
        return markets[marketId];
    }

    function isGameCreated(bytes32 gameId) public view returns (bool) {
        return _isGameCreated(games[gameId]);
    }

    function isMarketCreated(bytes32 marketId) public view returns (bool) {
        return _isMarketCreated(markets[marketId]);
    }

    /*///////////////////////////////////////////////////////////////////
                            ADMIN 
    //////////////////////////////////////////////////////////////////*/

    function pauseGame(bytes32) external onlyAdmin {
        // TODO
        // NOTE: Game can be in any state to be paused
    }

    function unpauseGame(bytes32) external onlyAdmin {
        // TODO
    }

    function emergencySettleGame(bytes32) external onlyAdmin {
        // TODO
        // NOTE: Game must be in state Paused to be EmergencySettled
        // correctly settled games can still be paused then emergency settled
    }

    function pauseMarket(bytes32) external onlyAdmin {
        // TODO
    }

    function unpauseMarket(bytes32) external onlyAdmin {
        // TODO
    }

    function emergencyResolveMarket(bytes32) external onlyAdmin {
        // TODO
    }

    /*///////////////////////////////////////////////////////////////////
                            INTERNAL 
    //////////////////////////////////////////////////////////////////*/

    /// @notice Saves Game Data
    /// @param creator          - Address of the creator
    /// @param timestamp        - Timestamp used in the OO request
    /// @param data             - Data used to resolve a Game
    /// @param token            - ERC20 token used to pay rewards and bonds
    /// @param reward           - Reward amount, denominated in token
    /// @param bond             - Bond amount used, denominated in token
    /// @param liveness         - UMA liveness period, will be the default liveness period if 0.
    function _saveGame(
        bytes32 gameId,
        address creator,
        uint256 timestamp,
        bytes memory data,
        Ordering ordering,
        address token,
        uint256 reward,
        uint256 bond,
        uint256 liveness
    ) internal {
        games[gameId] = GameData({
            state: GameState.Created,
            ordering: ordering,
            creator: creator,
            timestamp: timestamp,
            token: token,
            reward: reward,
            bond: bond,
            liveness: liveness,
            ancillaryData: data,
            homeScore: 0,
            awayScore: 0
        });
    }

    function _saveMarket(bytes32 marketId, bytes32 gameId, uint256 line, MarketType marketType) internal {
        markets[marketId] = MarketData({gameId: gameId, line: line, marketType: marketType, state: MarketState.Created});
    }

    /// @notice Request data from the OO
    /// @dev Transfers reward token from the requestor if non-zero reward is specified
    /// @param requestor        - Address of the requestor
    /// @param timestamp        - Timestamp used in the OO request
    /// @param data             - Data used to resolve a Game
    /// @param token            - Address of the reward token
    /// @param reward           - Reward amount, denominated in rewardToken
    /// @param bond             - Bond amount used, denominated in rewardToken
    /// @param liveness         - UMA liveness period, will be the default liveness period if 0.
    function _requestData(
        address requestor,
        uint256 timestamp,
        bytes memory data,
        address token,
        uint256 reward,
        uint256 bond,
        uint256 liveness
    ) internal {
        if (reward > 0) {
            // If the requestor is not the Oracle, the requestor pays for the price request
            // If not, the Oracle pays for the price request using the refunded reward
            if (requestor != address(this)) {
                // Transfer the reward from the requestor to the Oracle
                SafeTransferLib.safeTransferFrom(ERC20(token), requestor, address(this), reward);
            }

            // Approve the OO as spender on the reward token from the Adapter
            if (ERC20(token).allowance(address(this), address(optimisticOracle)) < reward) {
                SafeTransferLib.safeApprove(ERC20(token), address(optimisticOracle), type(uint256).max);
            }
        }

        // Send a request to the Optimistic oracle
        optimisticOracle.requestPrice(OO_IDENTIFIER, timestamp, data, IERC20(token), reward);

        // Ensure that request is event based
        // Event based ensures that:
        // 1. The timestamp at which the request is evaluated is the time of the proposal
        // 2. The proposer cannot propose the ignorePrice value in the proposer/dispute flow
        // 3. RefundOnDispute is automatically set, meaning disputes trigger the reward to be refunded
        // Meaning, the only way to get the ignore price value is through the DVM i.e through a dispute
        optimisticOracle.setEventBased(OO_IDENTIFIER, timestamp, data);

        // Update the bond on the OO
        if (bond > 0) optimisticOracle.setBond(OO_IDENTIFIER, timestamp, data, bond);
        if (liveness > 0) optimisticOracle.setCustomLiveness(OO_IDENTIFIER, timestamp, data, liveness);
    }

    // TODO: natspec
    function _settle(bytes32 gameId, GameData storage gameData) internal {
        // Get the data from the OO
        int256 data = optimisticOracle.settleAndGetPrice(OO_IDENTIFIER, gameData.timestamp, gameData.ancillaryData);

        // If cancelled, cancel the game
        if (_isCanceled(data)) return _cancelGame(gameId, gameData);
        // If ignore, reset the game
        if (_isIgnore(data)) return _resetGame(gameId, gameData);

        // Decode the scores from the OO data and set them in storage
        (uint32 home, uint32 away) = ScoreDecoderLib.decodeScores(gameData.ordering, data);

        gameData.homeScore = home;
        gameData.awayScore = away;
        gameData.state = GameState.Settled;

        emit GameSettled(gameId, home, away);
    }

    // TODO: natspec
    function _cancelGame(bytes32 gameId, GameData storage gameData) internal {
        gameData.state = GameState.Canceled;
        emit GameCanceled(gameId);
    }

    function _resetGame(bytes32 gameId, GameData storage gameData) internal {
        uint256 timestamp = block.timestamp;

        // Update the request timestamp
        gameData.timestamp = timestamp;

        // Send out a new data request
        _requestData(
            address(this),
            timestamp,
            gameData.ancillaryData,
            gameData.token,
            gameData.reward,
            gameData.bond,
            gameData.liveness
        );

        emit GameReset(gameId);
    }

    function _isGameCreated(GameData storage gameData) internal view returns (bool) {
        return gameData.ancillaryData.length > 0;
    }

    function _isMarketCreated(MarketData storage marketData) internal view returns (bool) {
        return marketData.gameId != bytes32(0);
    }

    function _ready(GameData storage gameData) internal view returns (bool) {
        if (gameData.state != GameState.Created) return false;
        return _dataExists(gameData.timestamp, gameData.ancillaryData);
    }

    function _dataExists(uint256 requestTimestamp, bytes memory ancillaryData) internal view returns (bool) {
        return optimisticOracle.hasPrice(address(this), OO_IDENTIFIER, requestTimestamp, ancillaryData);
    }

    // TODO: umip description
    function _isCanceled(int256 data) internal pure returns (bool) {
        return data == type(int256).max;
    }

    function _isIgnore(int256 data) internal pure returns (bool) {
        return data == type(int256).min;
    }
}
