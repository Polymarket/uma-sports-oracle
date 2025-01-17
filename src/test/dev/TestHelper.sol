// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "lib/forge-std/src/Test.sol";
import {Ordering} from "src/libraries/Structs.sol";

abstract contract TestHelper is Test {
    address public alice;
    address public brian;
    address public carla;
    address public devin;

    constructor() {
        alice = vm.createWallet("alice").addr;
        brian = vm.createWallet("brian").addr;
        carla = vm.createWallet("carla").addr;
        devin = vm.createWallet("devin").addr;
    }

    function advance(uint256 _delta) internal {
        vm.roll(block.number + _delta);
    }

    function fastForward(uint256 blockNumberDelta) internal {
        uint256 tsDelta = 12 * blockNumberDelta;
        vm.roll(block.number + blockNumberDelta);
        vm.warp(block.timestamp + tsDelta);
    }

    function encodeScores(uint32 home, uint32 away, Ordering ordering) internal pure returns (int256) {
        if (ordering == Ordering.HomeVsAway) {
            return int256(uint256(home)) << 0 | int256(uint256(away)) << 32;
        }
        return int256(uint256(away)) << 0 | int256(uint256(home)) << 32;
    }

    function convertLine(uint256 line) internal pure returns (uint256) {
        return (line * (10 ** 6)) + (5 * (10 ** 5));
    }
}
