// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Script} from "lib/forge-std/src/Script.sol";
import {UmaSportsOracle} from "src/UmaSportsOracle.sol";

/// @title Deploy
/// @notice Script to deploy the UmaSportsOracle
/// @author Polymarket
contract Deploy is Script {
    /// @notice Deploys the Adapter
    /// @param admin        - The admin
    /// @param ctf          - The ConditionalTokens Framework Address
    /// @param oo           - The OptimisticOracleV2 Address
    /// @param wl           - The AddressWhitelist Address
    function deploy(address admin, address ctf, address oo, address wl) public returns (address oracle) {
        vm.startBroadcast();
        UmaSportsOracle orac = new UmaSportsOracle(ctf, oo, wl);

        orac.addAdmin(admin);

        orac.renounceAdmin();

        oracle = address(orac);

        vm.stopBroadcast();
    }
}
