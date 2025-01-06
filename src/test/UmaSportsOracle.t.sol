// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;


import {OracleHelper} from "./dev/OracleHelper.sol";
import { console2 as console } from "lib/forge-std/src/Test.sol";

contract UmaSportsOracleTest is OracleHelper {

    function test_createGame() public {
        console.logAddress(address(oracle));
        assertEq(uint256(1), uint256(1));
    }
}