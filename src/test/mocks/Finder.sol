// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.27;

import {IFinder} from "../interfaces/IFinder.sol";

contract Finder is IFinder {
    address public optimisticOracleV2;
    address public collateralWhitelist;
    address public store;
    address public identifierWhitelist;
    address public oracle;

    function changeImplementationAddress(bytes32 interfaceName, address contractAddress) external {
        if (interfaceName == "OptimisticOracleV2") {
            optimisticOracleV2 = contractAddress;
        } else if (interfaceName == "CollateralWhitelist") {
            collateralWhitelist = contractAddress;
        } else if (interfaceName == "Store") {
            store = contractAddress;
        } else if (interfaceName == "IdentifierWhitelist") {
            identifierWhitelist = contractAddress;
        } else if (interfaceName == "Oracle") {
            oracle = contractAddress;
        } else {
            revert();
        }
    }

    function getImplementationAddress(bytes32 interfaceName) external view returns (address) {
        if (interfaceName == "OptimisticOracleV2") {
            return optimisticOracleV2;
        } else if (interfaceName == "CollateralWhitelist") {
            return collateralWhitelist;
        } else if (interfaceName == "Store") {
            return store;
        } else if (interfaceName == "IdentifierWhitelist") {
            return identifierWhitelist;
        } else if (interfaceName == "Oracle") {
            return oracle;
        } else {
            revert();
        }
    }
}
