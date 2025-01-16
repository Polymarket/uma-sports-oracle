// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {DeployLib} from "./DeployLib.sol";
import {TestHelper} from "./TestHelper.sol";

import {MarketType} from "src/libraries/Structs.sol";
import {AncillaryDataLib} from "src/libraries/AncillaryDataLib.sol";

import {IAuthEE} from "src/modules/interfaces/IAuth.sol";
import {IUmaSportsOracleEE} from "src/interfaces/IUmaSportsOracle.sol";
import {IOptimisticOracleV2} from "src/interfaces/IOptimisticOracleV2.sol";

import {IERC20} from "../interfaces/IERC20.sol";

import {USDC} from "../mocks/USDC.sol";
import {Store} from "../mocks/Store.sol";
import {Finder} from "../mocks/Finder.sol";
import {Voting} from "../mocks/Voting.sol";
import {AddressWhitelist} from "../mocks/AddressWhitelist.sol";
import {OptimisticOracleV2} from "../mocks/OptimisticOracleV2.sol";
import {IdentifierWhitelist} from "../mocks/IdentifierWhitelist.sol";

import {UmaSportsOracle} from "src/UmaSportsOracle.sol";

abstract contract OracleSetup is IUmaSportsOracleEE, IAuthEE, TestHelper {
    address public admin;
    address public proposer;
    address public disputer;

    address public usdc;
    address public ctf;
    address public whitelist;
    address public optimisticOracle;
    Voting public voting;

    UmaSportsOracle public oracle;

    bytes public constant ancillaryData =
        hex"7b277469746c65273a202757696c6c206974207261696e20696e204e5943206f6e204672696461793f272c202764657363273a202757696c6c206974207261696e20696e204e5943206f6e204672696461793f277d";

    bytes public appendedAncillaryData;
    bytes32 public gameId;

    bytes32 public identifier = "MULTIPLE_VALUES";

    function setUp() public {
        admin = alice;
        proposer = brian;
        disputer = carla;
        vm.label(admin, "Admin");
        vm.label(proposer, "Proposer");
        vm.label(disputer, "Disputer");

        appendedAncillaryData = AncillaryDataLib.appendAncillaryData(admin, ancillaryData);
        gameId = keccak256(appendedAncillaryData);
        ctf = DeployLib.deployConditionalTokens();
        usdc = address(new USDC());
        vm.label(usdc, "USDC");

        whitelist = address(new AddressWhitelist());
        // optimisticOracle = address(new OptimisticOracleV2());
        Finder finder = new Finder();
        optimisticOracle = DeployLib.OptimisticOracleV2(7200, address(finder));

        address store = address(new Store());
        address identifierWhitelist = address(new IdentifierWhitelist());
        voting = new Voting();

        finder.changeImplementationAddress("IdentifierWhitelist", identifierWhitelist);
        finder.changeImplementationAddress("Store", store);
        finder.changeImplementationAddress("OptimisticOracleV2", optimisticOracle);
        finder.changeImplementationAddress("CollateralWhitelist", whitelist);
        finder.changeImplementationAddress("Oracle", address(voting));

        // Deal the addresses USDC and approve the OO
        deal(usdc, proposer, 1_000_000_000_000);
        deal(usdc, disputer, 1_000_000_000_000);
        deal(usdc, admin, 1_000_000_000_000);
        vm.prank(proposer);
        IERC20(usdc).approve(optimisticOracle, type(uint256).max);
        vm.prank(disputer);
        IERC20(usdc).approve(optimisticOracle, type(uint256).max);
        vm.prank(admin);
        IERC20(usdc).approve(optimisticOracle, type(uint256).max);

        vm.startPrank(admin);
        oracle = new UmaSportsOracle(ctf, optimisticOracle, whitelist);
        IERC20(usdc).approve(address(oracle), type(uint256).max);
        vm.stopPrank();
    }

    function getMarketId(bytes32 _gameId, MarketType marketType, uint256 line, address creator)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_gameId, marketType, line, creator));
    }

    function convertLine(uint256 line) internal pure returns (uint256) {
        return (line * (10 ** 6)) + (5 * (10 ** 5));
    }

    function propose(int256 price, uint256 timestamp, bytes memory data) internal {
        fastForward(10);
        vm.prank(proposer);
        IOptimisticOracleV2(optimisticOracle).proposePrice(address(oracle), identifier, timestamp, data, price);
    }

    function dispute(uint256 timestamp, bytes memory data) internal {
        fastForward(10);
        vm.prank(disputer);
        IOptimisticOracleV2(optimisticOracle).disputePrice(address(oracle), identifier, timestamp, data);
    }

    function settle(uint256 timestamp, bytes memory data) internal {
        fastForward(10);
        vm.prank(proposer);
        IOptimisticOracleV2(optimisticOracle).settle(address(oracle), identifier, timestamp, data);
    }

    function proposeAndSettle(int256 price, uint256 timestamp, bytes memory data) internal {
        propose(price, timestamp, data);

        fastForward(1000);

        settle(timestamp, data);
    }
}
