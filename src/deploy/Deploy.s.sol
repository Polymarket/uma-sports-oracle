// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Script} from "lib/forge-std/src/Script.sol";
import {UmaSportsOracle} from "src/UmaSportsOracle.sol";

/// @title Deploy
/// @notice Script to deploy the UmaSportsOracle
/// @author Polymarket
contract Deploy is Script {
    /// @notice Deploys the Adapter
    /// @param ctf          - The ConditionalTokens Framework Address
    /// @param oo           - The OptimisticOracleV2 Address
    /// @param wl           - The AddressWhitelist Address
    function deploy(address ctf, address oo, address wl) public returns (address oracle) {
        vm.startBroadcast();
        oracle = address(new UmaSportsOracle(ctf, oo, wl));
        vm.stopBroadcast();
    }
}
