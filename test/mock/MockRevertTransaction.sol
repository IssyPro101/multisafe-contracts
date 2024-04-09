// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

contract MockRevertTransaction {

    function revertTransaction() external pure {
        revert();
    }
}
