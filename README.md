# Polymarket UMA Sports Oracle

## Overview

This repo contains contracts that use UMA's Optimistic Oracle(OO) to automatically resolve multiple Sports markets based on scores provided by the OO.

## Architecture
![Contract Architecture](./docs/arch.png)

The UmaSportsOracle contract will allow users to create _Games_ where every Game corresponds to a unique Sports event. This contract uses the Optimistic Oracle's MULTIPLE_VALUES price identifier to fetch the scores of the home and away teams.

Once created, _Markets_ can be created that will resolve based on the scores of the Game. 
There are 3 types of markets supported by the contract at this time:

* Winner    - A market on who the winner of a Game is i.e Team A vs Team B
* Spreads   - A market on the _spread_ between the team scores i.e Favorite vs Underdog
* Totals    - A market on the _total_ score i.e Over vs Under

In short:

* Anyone can call `createGame` on the Oracle, which will:
    - Send out a price request to the OO requesting the scores for the game
    - Create a Game if it doesn’t already exist
- After a Game is created, anyone can call `createMarket` which will:
    - Prepare a new ConditionalTokensFramework Condition
    - Creates a Market on the contract if it does not already exist
- Once score data is available, proposers will:
    - Fetch the scores for the home and away teams respectively
    - Encode the scores and other data(e.g if the game was canceled/delayed) according to UMIP 183
    - Propose this value on the OO
- OO disputers can challenge this value with a bond etc and escalate to the UMA DVM
- Once the value goes through the DVM, anyone can call `settleGame` for a Game which will:
    - Decode the scores retrieved from the OO
    - Store them onchain
- Once a Game is settled or canceled, anyone can call `resolveMarket` for any of the Markets linked to the Game which will resolve the Market(s) based on the scores of the Game

