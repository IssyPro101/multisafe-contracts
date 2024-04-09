// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import {Test, console} from "forge-std/Test.sol";

contract TransactionConfig is Test {

    struct TransactionDetails {
        address to;
        uint256 value;
        uint256 deadline;
        bytes data;
    }

    function getTransactionDetails(address _to, uint256 _value, uint256 _deadline, bytes memory _data) external pure returns (TransactionDetails memory) {
        return TransactionDetails({
            to: _to,
            value: _value,
            deadline: _deadline,
            data: _data
        });
    }

    function getMockTransactionDetails() external returns (TransactionDetails memory) {
        return TransactionDetails({
            to: makeAddr("transactionRecipient"),
            value: 0,
            deadline: block.timestamp + 100,
            data: "0x"
        });
    }
}
