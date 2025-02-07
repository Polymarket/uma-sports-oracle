// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Auth} from "./modules/Auth.sol";

import {LineLib} from "./libraries/LineLib.sol";
import {PayoutLib} from "./libraries/PayoutLib.sol";
import {ScoreDecoderLib} from "./libraries/ScoreDecoderLib.sol";
import {AncillaryDataLib} from "./libraries/AncillaryDataLib.sol";
import {Ordering, MarketType, MarketData, MarketState, GameState, GameData, Underdog} from "./libraries/Structs.sol";

import {IUmaSportsOracle} from "./interfaces/IUmaSportsOracle.sol";
import {IAddressWhitelist} from "./interfaces/IAddressWhitelist.sol";
import {IConditionalTokens} from "./interfaces/IConditionalTokens.sol";
import {IOptimisticOracleV2, IOptimisticRequester, State} from "./interfaces/IOptimisticOracleV2.sol";

import {ERC20, SafeTransferLib} from "lib/solmate/src/utils/SafeTransferLib.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/// @title UmaSportsOracle
/// @notice Oracle contract for Sports games
/// @author Jon Amenechi (jon@polymarket.com)
contract UmaSportsOracle is IUmaSportsOracle, IOptimisticRequester, Auth {
    /*///////////////////////////////////////////////////////////////////
                            IMMUTABLES 
    //////////////////////////////////////////////////////////////////*/

    /// @notice Conditional Tokens Framework
    IConditionalTokens public immutable ctf;

    /// @notice Optimistic Oracle
    IOptimisticOracleV2 public immutable optimisticOracle;

    /// @notice Collateral Whitelist
    IAddressWhitelist public immutable addressWhitelist;

    /*///////////////////////////////////////////////////////////////////
                            CONSTANTS 
    //////////////////////////////////////////////////////////////////*/

    /// @notice Query identifier used to request multiple values from the OO
    /// https://github.com/UMAprotocol/UMIPs/blob/master/UMIPs/umip-183.md
    bytes32 public constant IDENTIFIER = "MULTIPLE_VALUES";

    /*///////////////////////////////////////////////////////////////////
                                STATE 
    //////////////////////////////////////////////////////////////////*/

    /// @notice Mapping of gameId to Games
    mapping(bytes32 => GameData) internal games;

    /// @notice Mapping of marketId to Markets
    mapping(bytes32 => MarketData) internal markets;

    modifier onlyOptimisticOracle() {
        if (msg.sender != address(optimisticOracle)) revert NotOptimisticOracle();
        _;
    }

    constructor(address _ctf, address _optimisticOracle, address _addressWhitelist) {
        ctf = IConditionalTokens(_ctf);
        optimisticOracle = IOptimisticOracleV2(_optimisticOracle);
        addressWhitelist = IAddressWhitelist(_addressWhitelist);
    }

    /*///////////////////////////////////////////////////////////////////
                            PUBLIC 
    //////////////////////////////////////////////////////////////////*/

    /// @notice Creates a Game
    /// @param ancillaryData    - Data used to resolve a Game
    /// @param ordering         - The Ordering(home vs away or vice versa) of the Game
    /// @param token            - The token used for rewards and bonds
    /// @param reward           - The reward paid to successful proposers
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
        GameData storage gameData = games[gameId];
        if (_doesGameExist(gameData)) revert GameAlreadyCreated();

        uint256 timestamp = block.timestamp;

        // Store game
        _saveGame(gameId, msg.sender, timestamp, data, ordering, token, reward, bond, liveness);

        // Send out OO data request
        _requestData(msg.sender, timestamp, data, token, reward, bond, liveness);

        emit GameCreated(gameId, uint8(ordering), data, timestamp);
        return gameId;
    }

    /// @notice Creates a Winner(Team A vs Team B) Market based on an underlying Game
    /// @param gameId   - The unique Id of a Game to be linked to the Market
    function createWinnerMarket(bytes32 gameId) external returns (bytes32) {
        return _createMarket(gameId, MarketType.Winner, Underdog.Home, 0);
    }

    /// @notice Creates a Spreads Market based on an underlying Game
    /// @param gameId   - The unique Id of a Game to be linked to the Market
    /// @param underdog - The Underdog of the Market
    /// @param line     - The line of the Market.
    /// @dev Must be a half point scaled by 10 ^ 6, e.g 1.5, 2.5
    /// @dev For a Spread line of 2.5, line = 2_500_000
    function createSpreadsMarket(bytes32 gameId, Underdog underdog, uint256 line) external returns (bytes32) {
        // Validate that the spread line is a half point spread
        if (!LineLib._isValidLine(line)) revert InvalidLine();
        return _createMarket(gameId, MarketType.Spreads, underdog, line);
    }

    /// @notice Creates a Totals Market based on an underlying Game
    /// @param gameId   - The unique Id of a Game to be linked to the Market
    /// @param line     - The line of the Market
    /// @dev Must be a half point scaled by 10 ^ 6, e.g 200.5, 100.5
    /// @dev For a Totals line of 218.5, line = 218_500_000
    function createTotalsMarket(bytes32 gameId, uint256 line) external returns (bytes32) {
        if (!LineLib._isValidLine(line)) revert InvalidLine();
        return _createMarket(gameId, MarketType.Totals, Underdog.Home, line);
    }

    /// @notice Resolves a Market using the scores of a Settled Game
    /// @dev MarketState transition: Created -> Resolved
    /// @param marketId - The unique marketId
    function resolveMarket(bytes32 marketId) external {
        MarketData storage marketData = markets[marketId];
        // Ensure the Market exists
        if (!_doesMarketExist(marketData)) revert MarketDoesNotExist();

        // Validate that the Market can be resolved
        if (marketData.state != MarketState.Created) revert MarketCannotBeResolved();

        GameData storage gameData = games[marketData.gameId];
        GameState state = gameData.state;

        // Valid Game states for market resolution: Settled, Canceled or EmergencySettled
        if (!(state == GameState.Settled || state == GameState.Canceled || state == GameState.EmergencySettled)) {
            revert GameNotResolvable();
        }

        // Resolve the Market
        _resolve(marketId, gameData, marketData);
    }

    /*///////////////////////////////////////////////////////////////////
                            CALLBACKS 
    //////////////////////////////////////////////////////////////////*/

    /// @notice Callback to be executed on OO settlement
    /// If the OO request matches the Game and the Game is in a valid state,
    /// this function settles the Game by setting the home and away scores
    /// @param timestamp        - Timestamp of the Request
    /// @param ancillaryData    - Ancillary data of the Request
    /// @param price            - The price settled on the Request
    function priceSettled(bytes32, uint256 timestamp, bytes memory ancillaryData, int256 price)
        external
        onlyOptimisticOracle
    {
        bytes32 gameId = keccak256(ancillaryData);
        GameData storage gameData = games[gameId];

        // Ensure the request timestamp matches Game timestamp.
        // This ensures that only the Live OO request is relevant to the Oracle
        if (gameData.timestamp != timestamp) {
            return;
        }

        // No-op if the game is in any state other than Created, i.e EmergencySettled or Paused
        if (gameData.state != GameState.Created) {
            return;
        }

        // Settle the Game
        _settle(price, gameId, gameData);
    }

    /// @notice Callback to be executed by the OO dispute.
    /// On dispute, this function resets the Game by sending out a new price Request to the OO.
    /// No-op if the Game is disputed more than once, creating at most 2 price requests
    /// @param ancillaryData    - Ancillary data of the request
    function priceDisputed(bytes32, uint256 timestamp, bytes memory ancillaryData, uint256)
        external
        onlyOptimisticOracle
    {
        bytes32 gameId = keccak256(ancillaryData);
        GameData storage gameData = games[gameId];

        // Ensure the request timestamp matches Game timestamp.
        // This ensures that only the Live OO request is relevant to the Oracle
        if (gameData.timestamp != timestamp) {
            return;
        }

        GameState state = gameData.state;

        // If the Game is settled, refund the reward to the creator and no-op
        if (state == GameState.EmergencySettled) {
            _refund(gameData.token, gameData.creator, gameData.reward);
            return;
        }

        // If the Game has the reset flag set, this indicates that the OO Request was pushed to the DVM
        // Set the refund flag on the Game to refund the creator on resolution
        if (gameData.reset) {
            gameData.refund = true;
            return;
        }

        // Reset the game
        _resetGame(address(this), gameId, gameData);
    }

    /*///////////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS 
    //////////////////////////////////////////////////////////////////*/

    /// @notice Returns the GameData
    /// @param gameId   - The unique game Id
    function getGame(bytes32 gameId) external view returns (GameData memory) {
        return games[gameId];
    }

    /// @notice Returns the MarketData
    /// @param marketId - The unique market Id
    function getMarket(bytes32 marketId) external view returns (MarketData memory) {
        return markets[marketId];
    }

    /*///////////////////////////////////////////////////////////////////
                            ADMIN 
    //////////////////////////////////////////////////////////////////*/

    /// @notice Pauses a Game
    /// @dev Pausing a Game prevents it from settlement and allows it to be emergency settled
    /// @dev GameState transition: Created -> Paused
    /// @param gameId - The unique game Id
    function pauseGame(bytes32 gameId) external onlyAdmin {
        GameData storage gameData = games[gameId];

        if (!_doesGameExist(gameData)) revert GameDoesNotExist();
        if (gameData.state != GameState.Created) revert GameCannotBePaused();

        gameData.state = GameState.Paused;
        emit GamePaused(gameId);
    }

    /// @notice Unpauses a Game
    /// @dev GameState transition: Paused -> Created
    /// @param gameId - The unique game Id
    function unpauseGame(bytes32 gameId) external onlyAdmin {
        GameData storage gameData = games[gameId];

        if (!_doesGameExist(gameData)) revert GameDoesNotExist();
        if (gameData.state != GameState.Paused) revert GameCannotBeUnpaused();

        gameData.state = GameState.Created;
        emit GameUnpaused(gameId);
    }

    /// @notice Resets a Game, force sending a new request to the OO
    /// @param gameId - The unique game Id
    function resetGame(bytes32 gameId) external onlyAdmin {
        GameData storage gameData = games[gameId];

        if (!_doesGameExist(gameData)) revert GameDoesNotExist();
        if (gameData.state != GameState.Created) revert GameCannotBeReset();

        // Refund the reward to the Game's creator if necessary
        if (gameData.refund) _refund(gameData.token, gameData.creator, gameData.reward);

        _resetGameAndRefund(msg.sender, gameId, gameData);
    }

    /// @notice Emergency settles a Game
    /// @dev GameState transition: Paused -> EmergencySettled
    /// @param gameId   - The unique game Id
    function emergencySettleGame(bytes32 gameId, uint32 home, uint32 away) external onlyAdmin {
        GameData storage gameData = games[gameId];

        if (!_doesGameExist(gameData)) revert GameDoesNotExist();
        if (gameData.state != GameState.Paused) revert GameCannotBeEmergencySettled();

        gameData.state = GameState.EmergencySettled;
        gameData.homeScore = home;
        gameData.awayScore = away;

        emit GameEmergencySettled(gameId, home, away);
    }

    /// @notice Pauses a market which stops its resolution and allows it to be emergency resolved
    /// @dev MarketState transition: Created -> Paused
    /// @param marketId - The unique market id
    function pauseMarket(bytes32 marketId) external onlyAdmin {
        MarketData storage marketData = markets[marketId];

        if (!_doesMarketExist(marketData)) revert MarketDoesNotExist();
        if (marketData.state != MarketState.Created) revert MarketCannotBePaused();

        marketData.state = MarketState.Paused;
        emit MarketPaused(marketId);
    }

    /// @notice Unpauses a market
    /// @dev MarketState transition: Paused -> Created
    /// @param marketId - The unique market id
    function unpauseMarket(bytes32 marketId) external onlyAdmin {
        MarketData storage marketData = markets[marketId];

        if (!_doesMarketExist(marketData)) revert MarketDoesNotExist();
        if (marketData.state != MarketState.Paused) revert MarketCannotBeUnpaused();

        marketData.state = MarketState.Created;
        emit MarketUnpaused(marketId);
    }

    /// @notice Emergency resolves a market according to the payout array
    /// @dev MarketState transition: Paused -> EmergencyResolved
    /// @param marketId - The unique marketId
    /// @param payouts  - The payouts used to resolve the market
    function emergencyResolveMarket(bytes32 marketId, uint256[] memory payouts) external onlyAdmin {
        if (!PayoutLib.validatePayouts(payouts)) revert InvalidPayouts();

        MarketData storage marketData = markets[marketId];
        if (!_doesMarketExist(marketData)) revert MarketDoesNotExist();

        if (marketData.state != MarketState.Paused) revert MarketCannotBeEmergencyResolved();

        marketData.state = MarketState.EmergencyResolved;

        _reportPayouts(marketId, payouts);

        emit MarketEmergencyResolved(marketId, payouts);
    }

    /// @notice Updates the UMA bond for a Game
    /// @param gameId   - The unique game Id
    /// @param bond     - The updated bond
    function setBond(bytes32 gameId, uint256 bond) external onlyAdmin {
        GameData storage gameData = games[gameId];
        if (!_doesGameExist(gameData)) revert GameDoesNotExist();

        // no-op if the bond did not change
        if (bond == gameData.bond) return;

        uint256 timestamp = gameData.timestamp;
        bytes memory ancillaryData = gameData.ancillaryData;

        State state = _getOORequestState(timestamp, ancillaryData);
        if (state != State.Requested) revert InvalidRequestState();

        // Update the bond amount in storage
        gameData.bond = bond;

        // Update the bond in the OO
        optimisticOracle.setBond(IDENTIFIER, timestamp, ancillaryData, bond);
        emit BondUpdated(gameId, bond);
    }

    /// @notice Updates the liveness for a Game
    /// @param gameId   - The unique game Id
    /// @param liveness - The liveness value
    function setLiveness(bytes32 gameId, uint256 liveness) external onlyAdmin {
        GameData storage gameData = games[gameId];
        if (!_doesGameExist(gameData)) revert GameDoesNotExist();

        // no-op if the liveness did not change
        if (liveness == gameData.liveness) return;

        uint256 timestamp = gameData.timestamp;
        bytes memory ancillaryData = gameData.ancillaryData;

        State state = _getOORequestState(timestamp, ancillaryData);
        if (state != State.Requested) revert InvalidRequestState();

        // Update the liveness amount in storage
        gameData.liveness = liveness;

        // Update liveness in the OO
        optimisticOracle.setCustomLiveness(IDENTIFIER, timestamp, ancillaryData, liveness);

        emit LivenessUpdated(gameId, liveness);
    }

    /*///////////////////////////////////////////////////////////////////
                            INTERNAL 
    //////////////////////////////////////////////////////////////////*/

    /// @notice Saves Game Data
    /// @param creator      - Address of the creator
    /// @param timestamp    - Timestamp used in the OO request
    /// @param data         - Data used to resolve a Game
    /// @param token        - ERC20 token used to pay rewards and bonds
    /// @param reward       - Reward amount, denominated in token
    /// @param bond         - Bond amount used, denominated in token
    /// @param liveness     - UMA liveness period, will be the default liveness period if 0.
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
            awayScore: 0,
            reset: false,
            refund: false
        });
    }

    /// @notice Saves Market Data
    /// @param marketId     - The unique market Id
    /// @param gameId       - The unique game Id
    /// @param line         - The line for the Market
    /// @param underdog     - The underdog of the Market. Used for Spread markets
    /// @param marketType   - The market type
    function _saveMarket(bytes32 marketId, bytes32 gameId, uint256 line, Underdog underdog, MarketType marketType)
        internal
    {
        markets[marketId] = MarketData({
            gameId: gameId,
            line: line,
            underdog: underdog,
            marketType: marketType,
            state: MarketState.Created
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
        optimisticOracle.requestPrice(IDENTIFIER, timestamp, data, IERC20(token), reward);

        // Set callbacks
        optimisticOracle.setCallbacks(
            IDENTIFIER,
            timestamp,
            data,
            false, // DO NOT set callback on priceProposed
            true, // DO set callback on priceDisputed
            true // DO set callback on priceSettled
        );

        // Ensure that request is event based
        // Event based ensures that:
        // 1. The timestamp at which the request is evaluated is the time of the proposal
        // 2. The proposer cannot propose the ignorePrice value in the proposer/dispute flow
        // 3. RefundOnDispute is automatically set, meaning disputes trigger the reward to be refunded
        // Meaning, the only way to get the ignore price value is through the DVM i.e through a dispute
        optimisticOracle.setEventBased(IDENTIFIER, timestamp, data);

        // Update the bond and liveness on the OO if necessary
        if (bond > 0) optimisticOracle.setBond(IDENTIFIER, timestamp, data, bond);
        if (liveness > 0) optimisticOracle.setCustomLiveness(IDENTIFIER, timestamp, data, liveness);
    }

    /// @notice Settles a Game
    /// @dev If the scores are valid, GameState transition: Created -> Settled
    /// @param data         - The data provided by the OO
    /// @param gameId       - The unique gameId
    /// @param gameData     - The gameData in storage
    function _settle(int256 data, bytes32 gameId, GameData storage gameData) internal {
        // If canceled, cancel the game
        if (_isCanceled(data)) return _cancelGame(gameId, gameData);
        // If ignore, reset the game
        if (_isIgnore(data)) return _resetGameAndRefund(address(this), gameId, gameData);

        // Refund the reward to the Game's creator on resolution if necessary
        if (gameData.refund) _refund(gameData.token, gameData.creator, gameData.reward);

        // Decode the scores from the OO data
        (uint32 home, uint32 away) = ScoreDecoderLib.decodeScores(gameData.ordering, data);

        // Update the scores in storage and update the state
        gameData.homeScore = home;
        gameData.awayScore = away;
        gameData.state = GameState.Settled;

        emit GameSettled(gameId, home, away);
    }

    /// @notice Creates a Market based on an underlying Game
    /// @dev Creates the underlying CTF market based on the marketId
    /// @param gameId       - The unique Id of a Game to be linked to the Market
    /// @param marketType   - The marketType of the Market
    /// @param underdog     - The Underdog of the Market. Used for Spreads Markets
    /// @param line         - The line of the Market. Used for Spreads and Totals Markets
    function _createMarket(bytes32 gameId, MarketType marketType, Underdog underdog, uint256 line)
        internal
        returns (bytes32 marketId)
    {
        GameData storage gameData = games[gameId];

        // Validate that the Game exists
        if (!_doesGameExist(gameData)) revert GameDoesNotExist();

        // Validate that we can create a Market from the Game
        if (gameData.state != GameState.Created) revert InvalidGame();

        marketId = keccak256(abi.encode(gameId, marketType, uint8(underdog), line, msg.sender));

        // Validate that the market is unique
        MarketData storage marketData = markets[marketId];
        if (_doesMarketExist(marketData)) revert MarketAlreadyCreated();

        // Store the Market
        _saveMarket(marketId, gameId, line, underdog, marketType);

        // Create the underlying CTF market
        bytes32 conditionId = _prepareMarket(marketId);

        emit MarketCreated(marketId, gameId, conditionId, uint8(marketType), uint8(underdog), line);
        return marketId;
    }

    /// @notice Prepare a new Condition on the CTF
    /// @dev The marketId will be used as the questionID
    /// @param marketId - The unique MarketId
    function _prepareMarket(bytes32 marketId) internal returns (bytes32 conditionId) {
        conditionId = keccak256(abi.encodePacked(address(this), marketId, uint256(2)));
        if (ctf.getOutcomeSlotCount(conditionId) == 0) {
            ctf.prepareCondition(address(this), marketId, 2);
        }
        return conditionId;
    }

    /// @notice Report payouts on the CTF
    /// @param marketId - The unique MarketId
    /// @param payouts  - The payouts used to resolve the Condition
    function _reportPayouts(bytes32 marketId, uint256[] memory payouts) internal {
        ctf.reportPayouts(marketId, payouts);
    }

    /// @notice Cancels a game, setting the state to Canceled
    /// @dev GameState transition: Created -> Canceled
    function _cancelGame(bytes32 gameId, GameData storage gameData) internal {
        // Refund the reward to the Game's creator if necessary
        if (gameData.refund) _refund(gameData.token, gameData.creator, gameData.reward);

        gameData.state = GameState.Canceled;
        emit GameCanceled(gameId);
    }

    /// @notice Resets the game data refund flag and resets a Game
    /// To be used as part of settle and resetGame flows
    function _resetGameAndRefund(address requestor, bytes32 gameId, GameData storage gameData) internal {
        // Reset the refund flag
        gameData.refund = false;
        _resetGame(requestor, gameId, gameData);
    }

    /// @notice Resets a Game by sending a new request to the OO
    /// @dev The requestor pays for the price request
    /// @dev If the requestor is the Oracle, the price request is paid for by the refunded reward
    /// @dev If the requestor is an admin, the price request is paid for by the caller
    /// @param requestor    - The address requesting the reset
    /// @param gameId       - The unique gameId
    /// @param gameData     - The GameData in storage
    function _resetGame(address requestor, bytes32 gameId, GameData storage gameData) internal {
        uint256 timestamp = block.timestamp;

        // Update the request timestamp
        gameData.reset = true;
        gameData.timestamp = timestamp;

        // Send out a new data request
        _requestData(
            requestor,
            timestamp,
            gameData.ancillaryData,
            gameData.token,
            gameData.reward,
            gameData.bond,
            gameData.liveness
        );

        emit GameReset(gameId);
    }

    /// @notice Resolves a market
    /// @param marketId - The unique Market Id
    /// @param gameData - The game data
    /// @param marketData - The market data
    function _resolve(bytes32 marketId, GameData storage gameData, MarketData storage marketData) internal {
        uint256[] memory payouts = PayoutLib.constructPayouts(
            gameData.state,
            marketData.marketType,
            gameData.ordering,
            gameData.homeScore,
            gameData.awayScore,
            marketData.line,
            marketData.underdog
        );

        marketData.state = MarketState.Resolved;

        _reportPayouts(marketId, payouts);

        emit MarketResolved(marketId, payouts);
    }

    function _doesGameExist(GameData storage gameData) internal view returns (bool) {
        return gameData.ancillaryData.length > 0;
    }

    function _doesMarketExist(MarketData storage marketData) internal view returns (bool) {
        return marketData.gameId != bytes32(0);
    }

    function _refund(address token, address to, uint256 amount) internal {
        SafeTransferLib.safeTransfer(ERC20(token), to, amount);
    }

    function _getOORequestState(uint256 requestTimestamp, bytes memory ancillaryData) internal returns (State) {
        return optimisticOracle.getState(address(this), IDENTIFIER, requestTimestamp, ancillaryData);
    }

    function _isCanceled(int256 data) internal pure returns (bool) {
        return data == type(int256).max;
    }

    function _isIgnore(int256 data) internal pure returns (bool) {
        return data == type(int256).min;
    }
}
