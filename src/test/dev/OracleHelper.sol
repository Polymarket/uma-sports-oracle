// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {DeployLib} from "./DeployLib.sol";
import {TestHelper} from "./TestHelper.sol";

import {IFinder} from "src/interfaces/IFinder.sol";
import {IUmaSportsOracleEE} from "src/interfaces/IUmaSportsOracle.sol";
import {IConditionalTokens} from "src/interfaces/IConditionalTokens.sol";
import {IAddressWhitelist} from "src/interfaces/IAddressWhitelist.sol";
import {IOptimisticOracleV2} from "src/interfaces/IOptimisticOracleV2.sol";

import {USDC} from "../mocks/USDC.sol";
import {Finder} from "../mocks/Finder.sol";
import {OptimisticOracleV2} from "../mocks/OptimisticOracleV2.sol";
import {CollateralWhitelist} from "../mocks/CollateralWhitelist.sol";

import {UmaSportsOracle} from "src/UmaSportsOracle.sol";

abstract contract OracleHelper is IUmaSportsOracleEE, TestHelper {
    address public admin = alice;
    UmaSportsOracle public oracle;
    address public usdc;
    address public ctf;
    address public finder;
    address public whitelist;
    address public optimisticOracle;

    function setUp() public {
        ctf = DeployLib.deployConditionalTokens();
        usdc = address(new USDC());

        whitelist = address(new CollateralWhitelist());
        optimisticOracle = address(new OptimisticOracleV2());
        finder = address(new Finder(optimisticOracle, whitelist));

        vm.prank(admin);
        oracle = new UmaSportsOracle(ctf, finder);
    }
}
