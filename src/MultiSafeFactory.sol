// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {MultiSafe} from "./MultiSafe.sol";

/**
 * @title MultiSafeFactory
 * @dev A factory to deploy MultiSafe wallets
 */
contract MultiSafeFactory {

    /*//////////////////////////////////////////////////////////////
                             STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address[] public wallets;
    mapping(address => address[]) public userWallets;
    mapping(address => bool) public isWalletCreated;

    /*//////////////////////////////////////////////////////////////
                             FACTORY LOGIC
    //////////////////////////////////////////////////////////////*/
    function deployMultiSafeWallet(address[] memory _owners, uint256 _numConfirmationsRequired) external returns (address) {
        MultiSafe newWallet = new MultiSafe(_owners, _numConfirmationsRequired);
        wallets.push(address(newWallet));
        for (uint256 i = 0; i < _owners.length; i++) {
            userWallets[_owners[i]].push(address(newWallet));
        }
        isWalletCreated[address(newWallet)] = true;
        return address(newWallet);
    }

    function getNumAllWallets() external view returns (uint256) {
        return wallets.length;
    }

    function getNumUserWallets(address _user) external view returns (uint256) {
        return userWallets[_user].length;
    }
}
