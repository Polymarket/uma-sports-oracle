// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Auth} from "./modules/Auth.sol";
import {ConditionalTokensModule} from "./modules/ConditionalTokensModule.sol";

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
    bytes32 public constant ORACLE_IDENTIFIER = "MOCK_SPORTS_IDENTIFIER";

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
        _saveGame(gameId, msg.sender, timestamp, data, ordering, reward, bond, liveness);

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
        // Validate the Game
        if (!isGameCreated(gameId)) revert GameDoesNotExist();

        // Validate the marketType and line
        if (line > 0 && (marketType == MarketType.WinnerBinary || marketType == MarketType.WinnerDraw)) {
            revert InvalidLine();
        }

        marketId = getMarketId(gameId, marketType, line, msg.sender);

        // Validate that the market is unique
        if (isMarketCreated(marketId)) revert MarketAlreadyCreated();

        // Create the underlying CTF market
        bytes32 conditionId = _prepareMarket(marketId, marketType);

        // Store the Market
        _saveMarket(marketId, gameId, line, marketType);

        emit MarketCreated(marketId, gameId, conditionId, uint8(marketType), line);
        return marketId;
    }

    /*///////////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS 
    //////////////////////////////////////////////////////////////////*/

    function ready(bytes32 gameId) public view returns (bool) {
        // TODO
        return false;
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
        return games[gameId].ancillaryData.length > 0;
    }

    function isMarketCreated(bytes32 marketId) public view returns (bool) {
        return markets[marketId].gameId != bytes32(0);
    }

    /*///////////////////////////////////////////////////////////////////
                            INTERNAL 
    //////////////////////////////////////////////////////////////////*/

    /// @notice Saves Game Data
    /// @param creator          - Address of the creator
    /// @param timestamp        - Timestamp used in the OO request
    /// @param data             - Data used to resolve a Game
    /// @param reward           - Reward amount, denominated in rewardToken
    /// @param bond             - Bond amount used, denominated in rewardToken
    /// @param liveness         - UMA liveness period, will be the default liveness period if 0.
    function _saveGame(
        bytes32 gameId,
        address creator,
        uint256 timestamp,
        bytes memory data,
        Ordering ordering,
        uint256 reward,
        uint256 bond,
        uint256 liveness
    ) internal {
        games[gameId] = GameData({
            state: GameState.Created,
            ordering: ordering,
            creator: creator,
            timestamp: timestamp,
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
            // Transfer the reward from the requester to the Oracle
            SafeTransferLib.safeTransferFrom(ERC20(token), requestor, address(this), reward);

            // Approve the OO as spender on the reward token from the Adapter
            if (ERC20(token).allowance(address(this), address(optimisticOracle)) < reward) {
                SafeTransferLib.safeApprove(ERC20(token), address(optimisticOracle), type(uint256).max);
            }
        }

        // Send a request to the Optimistic oracle
        optimisticOracle.requestPrice(ORACLE_IDENTIFIER, timestamp, data, IERC20(token), reward);

        // Ensure that request is event based
        optimisticOracle.setEventBased(ORACLE_IDENTIFIER, timestamp, data);

        // Update the bond on the OO
        if (bond > 0) optimisticOracle.setBond(ORACLE_IDENTIFIER, timestamp, data, bond);
        if (liveness > 0) optimisticOracle.setCustomLiveness(ORACLE_IDENTIFIER, timestamp, data, liveness);
    }
}
