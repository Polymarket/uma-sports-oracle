// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "lib/forge-std/src/Test.sol";

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
}
