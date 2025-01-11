// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {DeployLib} from "./DeployLib.sol";
import {TestHelper} from "./TestHelper.sol";

import {AncillaryDataLib} from "src/libraries/AncillaryDataLib.sol";
import {IUmaSportsOracleEE} from "src/interfaces/IUmaSportsOracle.sol";

import {IERC20} from "../interfaces/IERC20.sol";

import {USDC} from "../mocks/USDC.sol";
import {Finder} from "../mocks/Finder.sol";
import {AddressWhitelist} from "../mocks/AddressWhitelist.sol";
import {OptimisticOracleV2} from "../mocks/OptimisticOracleV2.sol";

import {UmaSportsOracle} from "src/UmaSportsOracle.sol";

abstract contract OracleSetup is IUmaSportsOracleEE, TestHelper {
    address public admin = alice;
    UmaSportsOracle public oracle;
    address public usdc;
    address public ctf;
    address public finder;
    address public whitelist;
    address public optimisticOracle;

    bytes public constant ancillaryData =
        hex"7b277469746c65273a202757696c6c206974207261696e20696e204e5943206f6e204672696461793f272c202764657363273a202757696c6c206974207261696e20696e204e5943206f6e204672696461793f277d";

    bytes public appendedAncillaryData = AncillaryDataLib.appendAncillaryData(admin, ancillaryData);
    bytes32 public gameId = keccak256(appendedAncillaryData);

    function setUp() public {
        ctf = DeployLib.deployConditionalTokens();
        usdc = address(new USDC());

        whitelist = address(new AddressWhitelist());
        optimisticOracle = address(new OptimisticOracleV2());
        finder = address(new Finder(optimisticOracle, whitelist));

        vm.startPrank(admin);
        oracle = new UmaSportsOracle(ctf, finder);
        IERC20(usdc).approve(address(oracle), type(uint256).max);
        vm.stopPrank();
    }
}
