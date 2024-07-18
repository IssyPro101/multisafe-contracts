// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MultiSafe} from "../src/MultiSafe.sol";
import {MockRevertTransaction} from "./mock/MockRevertTransaction.sol";
import {TransactionConfig} from "./config/TransactionConfig.sol";

contract MultiSafeTest is Test {

    MultiSafe multiSafe;
    TransactionConfig transactionConfig;
    address owner1;
    address owner2;
    address owner3;

    function setUp() public {
        owner1 = makeAddr("owner1");
        owner2 = makeAddr("owner2");
        owner3 = makeAddr("owner3");

        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        multiSafe = new MultiSafe(owners, 3, "Test Wallet Name", "Test IPFS Link");

        for (uint256 i = 0; i < owners.length; i++) {
            assertEq(owners[i], multiSafe.owners(i));
            assertTrue(multiSafe.isOwner(owners[i]));
        }

        assertEq(multiSafe.numConfirmationsRequired(), 3);
        transactionConfig = new TransactionConfig();
    }

    function test_depositEth() external {
        vm.expectEmit();
        emit MultiSafe.Deposit(owner1, 1 ether, 1 ether);

        vm.deal(owner1, 1 ether);

        vm.startPrank(owner1);
        (bool success, ) = address(multiSafe).call{value: 1 ether}("");

        assertTrue(success);
    }

    function _getTransactionConfirmationsAtIndex(uint256 _transactionIndex) internal view returns (uint256) {
        (
            ,,,,,
            uint256 numConfirmations
        ) = multiSafe.getTransactionAtIndex(_transactionIndex);

        return numConfirmations;
    }

    function _getTransactionExecutionStatusAtIndex(uint256 _transactionIndex) internal view returns (bool) {
        (
            ,,,, 
            bool executed,
        ) = multiSafe.getTransactionAtIndex(_transactionIndex);

        return executed;
    }

    function test_submitTransaction() external {

        TransactionConfig.TransactionDetails memory transactionDetails = transactionConfig.getMockTransactionDetails();
        (
            address transactionRecipient,
            uint256 transactionValue,
            uint256 transactionDeadline,
            bytes memory transactionData
        ) = (transactionDetails.to, transactionDetails.value, transactionDetails.deadline, transactionDetails.data);

        vm.expectEmit();
        emit MultiSafe.SubmitTransaction(owner1, 0, transactionRecipient, transactionValue, transactionDeadline, transactionData);

        vm.prank(owner1);
        uint256 transactionIndex = multiSafe.submitTransaction(transactionRecipient, transactionValue, transactionDeadline, transactionData);

        (
            address to,
            uint256 value,
            uint256 deadline,
            bytes memory data,
            bool executed,
            uint256 numConfirmations
        ) = multiSafe.getTransactionAtIndex(transactionIndex);

        assertEq(to, transactionRecipient);
        assertEq(value, transactionValue);
        assertEq(deadline, transactionDeadline);
        assertEq(data.length, transactionData.length);
        assertEq(executed, false);
        assertEq(numConfirmations, 0);
    }

    function test_confirmTransaction() external {

        TransactionConfig.TransactionDetails memory transactionDetails = transactionConfig.getMockTransactionDetails();
        (
            address transactionRecipient,
            uint256 transactionValue,
            uint256 transactionDeadline,
            bytes memory transactionData
        ) = (transactionDetails.to, transactionDetails.value, transactionDetails.deadline, transactionDetails.data);

        vm.prank(owner1);
        uint256 transactionIndex = multiSafe.submitTransaction(transactionRecipient, transactionValue, transactionDeadline, transactionData);

        uint256 numConfirmationsBefore = _getTransactionConfirmationsAtIndex(transactionIndex);

        assertEq(numConfirmationsBefore, 0);

        vm.prank(owner1);
        multiSafe.confirmTransaction(transactionIndex);

        uint256 numConfirmationsAfter = _getTransactionConfirmationsAtIndex(transactionIndex);

        assertEq(numConfirmationsAfter, 1);
    }

    function test_cantConfirmTransactionAlreadyConfirmed() external {

        TransactionConfig.TransactionDetails memory transactionDetails = transactionConfig.getMockTransactionDetails();
        (
            address transactionRecipient,
            uint256 transactionValue,
            uint256 transactionDeadline,
            bytes memory transactionData
        ) = (transactionDetails.to, transactionDetails.value, transactionDetails.deadline, transactionDetails.data);

        vm.prank(owner1);
        uint256 transactionIndex = multiSafe.submitTransaction(transactionRecipient, transactionValue, transactionDeadline, transactionData);

        uint256 numConfirmationsBeforeInitial = _getTransactionConfirmationsAtIndex(transactionIndex);

        assertEq(numConfirmationsBeforeInitial, 0);

        vm.prank(owner1);
        multiSafe.confirmTransaction(transactionIndex);

        uint256 numConfirmationsAfterInitial = _getTransactionConfirmationsAtIndex(transactionIndex);

        assertEq(numConfirmationsAfterInitial, 1);

        vm.expectRevert();
        vm.prank(owner1);
        multiSafe.confirmTransaction(transactionIndex);

        uint256 numConfirmationsAfterFail = _getTransactionConfirmationsAtIndex(transactionIndex);

        assertEq(numConfirmationsAfterFail, 1);
    }

    function test_executeTransaction() external {

        TransactionConfig.TransactionDetails memory transactionDetails = transactionConfig.getMockTransactionDetails();
        (
            address transactionRecipient,
            uint256 transactionValue,
            uint256 transactionDeadline,
            bytes memory transactionData
        ) = (transactionDetails.to, transactionDetails.value, transactionDetails.deadline, transactionDetails.data);

        vm.prank(owner1);
        uint256 transactionIndex = multiSafe.submitTransaction(transactionRecipient, transactionValue, transactionDeadline, transactionData);

        vm.prank(owner1);
        multiSafe.confirmTransaction(transactionIndex);
        
        vm.prank(owner2);
        multiSafe.confirmTransaction(transactionIndex);
        
        vm.prank(owner3);
        multiSafe.confirmTransaction(transactionIndex);

        uint256 numConfirmationsAfter = _getTransactionConfirmationsAtIndex(transactionIndex);

        assertEq(numConfirmationsAfter, 3);

        vm.prank(owner1);
        multiSafe.executeTransaction(transactionIndex);

        bool transactionExecutionStatus = _getTransactionExecutionStatusAtIndex(transactionIndex);
        assertTrue(transactionExecutionStatus);
    }

    function test_cantExecuteTransactionAlreadyExecuted() external {

        TransactionConfig.TransactionDetails memory transactionDetails = transactionConfig.getMockTransactionDetails();
        (
            address transactionRecipient,
            uint256 transactionValue,
            uint256 transactionDeadline,
            bytes memory transactionData
        ) = (transactionDetails.to, transactionDetails.value, transactionDetails.deadline, transactionDetails.data);

        vm.prank(owner1);
        uint256 transactionIndex = multiSafe.submitTransaction(transactionRecipient, transactionValue, transactionDeadline, transactionData);

        vm.prank(owner1);
        multiSafe.confirmTransaction(transactionIndex);
        
        vm.prank(owner2);
        multiSafe.confirmTransaction(transactionIndex);
        
        vm.prank(owner3);
        multiSafe.confirmTransaction(transactionIndex);

        uint256 numConfirmations = _getTransactionConfirmationsAtIndex(transactionIndex);

        assertEq(numConfirmations, 3);

        vm.prank(owner1);
        multiSafe.executeTransaction(transactionIndex);

        vm.expectRevert();
        vm.prank(owner1);
        multiSafe.executeTransaction(transactionIndex);
    }

    function test_executeTransactionThatFails() external {

        MockRevertTransaction mockRevertTransaction = new MockRevertTransaction();

        address transactionRecipient = address(mockRevertTransaction);
        uint256 transactionValue = 0;
        uint256 transactionDeadline = block.timestamp + 100;
        bytes memory transactionData = abi.encodeCall(MockRevertTransaction.revertTransaction, ());

        vm.prank(owner1);
        uint256 transactionIndex = multiSafe.submitTransaction(transactionRecipient, transactionValue, transactionDeadline, transactionData);

        vm.prank(owner1);
        multiSafe.confirmTransaction(transactionIndex);
        
        vm.prank(owner2);
        multiSafe.confirmTransaction(transactionIndex);
        
        vm.prank(owner3);
        multiSafe.confirmTransaction(transactionIndex);

        uint256 numConfirmations = _getTransactionConfirmationsAtIndex(transactionIndex);

        assertEq(numConfirmations, 3);

        vm.prank(owner1);
        vm.expectRevert();
        multiSafe.executeTransaction(transactionIndex);

        bool transactionExecutionStatus = _getTransactionExecutionStatusAtIndex(transactionIndex);
        assertFalse(transactionExecutionStatus);
    }

    function test_revokeConfirmation() external {

        TransactionConfig.TransactionDetails memory transactionDetails = transactionConfig.getMockTransactionDetails();
        (
            address transactionRecipient,
            uint256 transactionValue,
            uint256 transactionDeadline,
            bytes memory transactionData
        ) = (transactionDetails.to, transactionDetails.value, transactionDetails.deadline, transactionDetails.data);

        vm.prank(owner1);
        uint256 transactionIndex = multiSafe.submitTransaction(transactionRecipient, transactionValue, transactionDeadline, transactionData);

        uint256 numConfirmationsBeforeConfirmation = _getTransactionConfirmationsAtIndex(transactionIndex);

        assertEq(numConfirmationsBeforeConfirmation, 0);

        vm.prank(owner1);
        multiSafe.confirmTransaction(transactionIndex);

        uint256 numConfirmationsAfterConfirmation = _getTransactionConfirmationsAtIndex(transactionIndex);

        assertEq(numConfirmationsAfterConfirmation, 1);

        vm.prank(owner1);
        multiSafe.revokeConfirmation(transactionIndex);

        uint256 numConfirmationAfterRevokal = _getTransactionConfirmationsAtIndex(transactionIndex);

        assertEq(numConfirmationAfterRevokal, 0);
    }

    function test_cantRevokeAlreadyRevoked() external {

        TransactionConfig.TransactionDetails memory transactionDetails = transactionConfig.getMockTransactionDetails();
        (
            address transactionRecipient,
            uint256 transactionValue,
            uint256 transactionDeadline,
            bytes memory transactionData
        ) = (transactionDetails.to, transactionDetails.value, transactionDetails.deadline, transactionDetails.data);

        vm.prank(owner1);
        uint256 transactionIndex = multiSafe.submitTransaction(transactionRecipient, transactionValue, transactionDeadline, transactionData);

        uint256 numConfirmationsBeforeConfirmation = _getTransactionConfirmationsAtIndex(transactionIndex);

        assertEq(numConfirmationsBeforeConfirmation, 0);

        vm.prank(owner1);
        multiSafe.confirmTransaction(transactionIndex);

        uint256 numConfirmationsAfterConfirmation = _getTransactionConfirmationsAtIndex(transactionIndex);

        assertEq(numConfirmationsAfterConfirmation, 1);

        vm.prank(owner1);
        multiSafe.revokeConfirmation(transactionIndex);

        uint256 numConfirmationAfterRevokal = _getTransactionConfirmationsAtIndex(transactionIndex);

        assertEq(numConfirmationAfterRevokal, 0);

        vm.expectRevert();
        vm.prank(owner1);
        multiSafe.revokeConfirmation(transactionIndex);
    }

}
