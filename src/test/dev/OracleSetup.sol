// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {DeployLib} from "./DeployLib.sol";
import {TestHelper} from "./TestHelper.sol";

import {IERC20} from "src/interfaces/IERC20.sol";
import {IUmaSportsOracleEE} from "src/interfaces/IUmaSportsOracle.sol";

import {USDC} from "../mocks/USDC.sol";
import {Finder} from "../mocks/Finder.sol";
import {OptimisticOracleV2} from "../mocks/OptimisticOracleV2.sol";
import {CollateralWhitelist} from "../mocks/CollateralWhitelist.sol";

import {UmaSportsOracle} from "src/UmaSportsOracle.sol";

abstract contract OracleSetup is IUmaSportsOracleEE, TestHelper {
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

        vm.startPrank(admin);
        oracle = new UmaSportsOracle(ctf, finder);
        IERC20(usdc).approve(address(oracle), type(uint256).max);
        vm.stopPrank();
    }
}
