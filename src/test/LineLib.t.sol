// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {TestHelper} from "./dev/TestHelper.sol";

import {LineLib} from "src/libraries/LineLib.sol";

contract LineLibTest is TestHelper {
    function test_getLineLowerBound(uint256 line) public pure {
        vm.assume(line > 0 && line < 10000);
        line = convertLine(line);

        assertEq(line / (10 ** 6), LineLib._getLineLowerBound(line));
    }

    function test_isValidLine(uint256 line) public pure {
        vm.assume(line > 0 && line < 10000);
        line = convertLine(line);
        assertTrue(LineLib._isValidLine(line));
    }
}
