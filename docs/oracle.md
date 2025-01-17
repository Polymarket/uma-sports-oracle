# UmaSportsOracle

The UmaSportsOracle allows users to create _Games_ where each Game is a unique sports event. 
OO proposers and disputers, will then fetch the scores of the Game offchain, encode them according the [MULTIPLE_VALUES](https://github.com/UMAprotocol/UMIPs/blob/master/UMIPs/umip-183.md) encoding schema and push those values to the UmaSportsOracle.

After Game creation, users can create different _Markets_ linked to the Game. Each Market is a unique [ConditionalTokenFramework](https://github.com/Polymarket/conditional-tokens-contracts) _condition_ and will be resolved based on the scores of the Game. This enables multiple markets to be resolved by a single OO request.

The Oracle also contains admin functionality to prevent games and markets from resolving normally and to emergency settle and emergency resolve games and markets respectively.

## Constuctor

Sets the ctf, optimistic oracle and address whitelist variables

### Parameters

```[solidity]
address _ctf, address _optimisticOracle, _addressWhitelist
```

## `createGame`

Creates a Game and sends out an OO price request for that Game

### Parameters

```[solidity]
bytes memory ancillaryData,
Ordering ordering,
address token,
uint256 reward,
uint256 bond,
uint256 liveness
```

## `createWinnerMarket`

Creates a Winner(Team A vs Team B) Market based on an underlying Game

### Parameters

```[solidity]
bytes32 gameId
```

## `createSpreadsMarket`

Creates a Spreads Market based on an underlying Game

### Parameters

```[solidity]
bytes32 gameId,
Underdog underdog,
uint256 line
```


## `createTotalsMarket`

Creates a Totals Market based on an underlying Game

### Parameters

```[solidity]
bytes32 gameId,
uint256 line
```

## `createMarket`

Creates a Market based on an underlying Game and creates the underlying CTF condition

### Parameters

```[solidity]
bytes32 gameId,
MarketType marketType,
Underdog underdog,
uint256 line
```

## `resolveMarket`

Resolves a Market using the scores of a Settled Game

### Parameters

```[solidity]
bytes32 marketId
```

## `priceSettled`

Callback to be executed on OO settlement. Settles the Game by setting the home and away scores.
Only executed by the OptimisticOracle.

### Parameters

```[solidity]
bytes32 identifier,
uint256 timestamp,
bytes memory ancillaryData,
int256 price
```

## `priceDisputed`

Callback to be executed by the OO dispute. Resets the Game by sending out a new price Request to the OO.
Only executed by the OptimisticOracle.

### Parameters

```[solidity]
bytes32 identifier,
uint256 timestamp,
bytes memory ancillaryData,
uint256 refund
```

## `ready`

Checks if a Game is ready to be settled

### Parameters

```[solidity]
bytes32 gameId
```

## `getGame`

Returns the GameData

### Parameters

```[solidity]
bytes32 gameId
```

## `getMarket`

Returns the MarketData

### Parameters

```[solidity]
bytes32 marketId
```

## `pauseGame`

Pauses a Game, preventing it from settlement and allows it to be emergency settled

### Parameters

```[solidity]
bytes32 gameId
```

## `unpauseGame`

Unpauses a Game

### Parameters

```[solidity]
bytes32 gameId
```


## `resetGame`

Resets a Game, force sending a new request to the OO

### Parameters

```[solidity]
bytes32 gameId
```

## `emergencySettleGame`

Emergency settles a Game

### Parameters

```[solidity]
bytes32 gameId
```


## `pauseMarket`

Pauses a market which stops its resolution and allows it to be emergency resolved

### Parameters

```[solidity]
bytes32 marketId
```

## `unpauseMarket`

Unpauses a market

### Parameters

```[solidity]
bytes32 marketId
```

## `emergencyResolveMarket`

Emergency resolves a market according to the payout array

### Parameters

```[solidity]
bytes32 marketId
```

## `setBond`

Updates the UMA bond for a Game

### Parameters

```[solidity]
bytes32 gameId,
uint256 bond
```

## `setLiveness`

Updates the liveness for a Game

### Parameters

```[solidity]
bytes32 gameId,
uint256 liveness
```

