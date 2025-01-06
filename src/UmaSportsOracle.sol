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
        uint256 timestamp = block.timestamp;

        // Send out OO data request
        _requestData(msg.sender, timestamp, data, token, reward, bond, liveness);

        // Store game
        _saveGame(gameId, msg.sender, timestamp, data, ordering, reward, bond, liveness);

        return gameId;
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
            if (IERC20(token).allowance(address(this), address(optimisticOracle)) < reward) {
                IERC20(token).approve(address(optimisticOracle), type(uint256).max);
            }
        }

        // Send a request to the Optimistic oracle
        optimisticOracle.requestPrice(ORACLE_IDENTIFIER, timestamp, data, IERC20(token), reward);

        // Ensure that request is event based
        optimisticOracle.setEventBased(ORACLE_IDENTIFIER, timestamp, data);

        // Update the bond on the OO
        if (bond > 0) optimisticOracle.setBond(ORACLE_IDENTIFIER, timestamp, data, bond);
        if (liveness > 0) {
            optimisticOracle.setCustomLiveness(ORACLE_IDENTIFIER, timestamp, data, liveness);
        }
    }
}
