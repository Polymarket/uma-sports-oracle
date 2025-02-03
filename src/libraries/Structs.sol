// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

enum Ordering {
    HomeVsAway,
    AwayVsHome
}

enum GameState {
    // Set when the Game is created
    Created,
    // Set when data is received from the OO and scores are updated
    Settled,
    // Set when the Game is canceled
    Canceled,
    // Set when the Game is paused
    Paused,
    // Set when the Game is emergency settled
    EmergencySettled
}

// The GameData struct represents a unique Sports Game
struct GameData {
    // The game creator
    address creator;
    // The State of the game
    GameState state;
    // The Ordering of the game
    Ordering ordering;
    // The score of the home team
    uint32 homeScore;
    // The score of the away team
    uint32 awayScore;
    // The ERC20 reward token
    address token;
    // The reward used to pay OO proposers
    uint256 reward;
    // The bond, in addition to the final fee, which OO proposers must put up
    uint256 bond;
    // The custom liveness for the Game, 0 for default
    uint256 liveness;
    // The OO request timestamp
    uint256 timestamp;
    // The ancillary data for the Game
    bytes ancillaryData;
    // Flag indicating that the Game has been reset
    bool reset;
    // Flag indicating that the Game should refund the creator
    bool refund;
}

enum MarketType {
    Winner,
    Spreads,
    Totals
}

enum Underdog {
    Home,
    Away
}

enum MarketState {
    Created,
    Resolved,
    Paused,
    EmergencyResolved
}

struct MarketData {
    bytes32 gameId; // The unique id of the game
    MarketState state; // The current State of the Market
    MarketType marketType; // The market type, used for determining resolution
    uint256 line; // The Line of the Market, used for spreads and totals, 0 for Winner markets
    Underdog underdog; // The Team expected to lose the Market, unused for Winner markets
}
