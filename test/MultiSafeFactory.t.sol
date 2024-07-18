// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MultiSafeFactory} from "../src/MultiSafeFactory.sol";
import {MultiSafe} from "../src/MultiSafe.sol";

contract MultiSafeTest is Test {

    MultiSafeFactory multiSafeFactory;
    address owner1;
    address owner2;
    address owner3;

    function setUp() public {

        multiSafeFactory = new MultiSafeFactory();
     
    }

    function test_walletDataIsCorrect() external {

        owner1 = makeAddr("owner1");
        owner2 = makeAddr("owner2");
        owner3 = makeAddr("owner3");

        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        address multiSafeAddress = multiSafeFactory.deployMultiSafeWallet(owners, 3, "Test Wallet Name", "Test IPFS Link");

        MultiSafe multiSafe = MultiSafe(payable(multiSafeAddress));

        for (uint256 i = 0; i < owners.length; i++) {
            assertEq(multiSafe.owners(i), owners[i]);
        }

        assertEq(multiSafe.numConfirmationsRequired(), 3);

    }

}
