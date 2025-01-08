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
            return int256(uint256(0)) << 224 | int256(uint256(home)) << 192 | int256(uint256(away)) << 160;
        }
        return int256(uint256(0)) << 224 | int256(uint256(away)) << 192 | int256(uint256(home)) << 160;
    }
}
