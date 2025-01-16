// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.27;

struct Unsigned {
    uint256 rawValue;
}

contract Store {
    Unsigned internal fee = Unsigned({rawValue: uint256(1500000000)});

    function payOracleFeesErc20(address erc20Address, Unsigned calldata amount) external {}

    function computeFinalFee(address) external view returns (Unsigned memory) {
        return fee;
    }
}
