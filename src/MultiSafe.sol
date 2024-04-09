// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title MultiSafe
 * @dev A multi-signature wallet contract that allows multiple owners to confirm and execute transactions.
 */
contract MultiSafe {
    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotOwner();
    error NonExistentTransaction();
    error TransactionAlreadyExecuted();
    error TransactionAlreadyConfirmed();
    error NonZeroOwnersRequired();
    error InvalidConfirmationNumber();
    error InvalidOwner();
    error NonUniqueOwner();
    error InsufficientConfirmations();
    error TransactionFailed();
    error TransactionNotConfirmed();
    error TransactionDeadlinePassed();

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(
        address indexed owner,
        uint256 indexed transactionIndex,
        address indexed to,
        uint256 value,
        uint256 deadline,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint256 indexed transactionIndex);
    event RevokeConfirmation(address indexed owner, uint256 indexed transactionIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed transactionIndex);

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Transaction {
        address to;
        uint256 value;
        uint256 deadline;
        bytes data;
        bool executed;
        uint256 numConfirmations;
    }

    /*//////////////////////////////////////////////////////////////
                             STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public numConfirmationsRequired;

    mapping(uint256 => mapping(address => bool)) public hasOwnerConfirmed;

    Transaction[] public transactions;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) {
            revert NotOwner();
        }
        _;
    }

    modifier transactionExists(uint256 _transactionIndex) {
        if (_transactionIndex >= transactions.length) {
            revert NonExistentTransaction();
        }
        _;
    }

    modifier transactionNotExecuted(uint256 _transactionIndex) {
        if (transactions[_transactionIndex].executed) {
            revert TransactionAlreadyExecuted();
        }
        _;
    }

    modifier transactionNotConfirmed(uint256 _transactionIndex) {
        if (hasOwnerConfirmed[_transactionIndex][msg.sender]) {
            revert TransactionAlreadyConfirmed();
        }
        _;
    }

    modifier isTransactionConfirmed(uint256 _transactionIndex) {
        if (!hasOwnerConfirmed[_transactionIndex][msg.sender]) {
            revert TransactionNotConfirmed();
        }
        _;
    }

    modifier enoughTransactionConfirmations(uint256 _transactionIndex) {
        if (transactions[_transactionIndex].numConfirmations < numConfirmationsRequired) {
            revert InsufficientConfirmations();
        }
        _;
    }

    modifier beforeTransactionDeadline(uint256 _transactionIndex) {
        if (block.timestamp > transactions[_transactionIndex].deadline) {
            revert TransactionDeadlinePassed();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @dev Constructor to initialise the MultiSafe contract.
     * @param _owners List of initial owners of the MultiSafe contract.
     * @param _numConfirmationsRequired Number of confirmations required for a transaction to be executed.
     */
    constructor(address[] memory _owners, uint256 _numConfirmationsRequired) {
        if (_owners.length == 0) {
            revert NonZeroOwnersRequired();
        }

        if (_numConfirmationsRequired == 0 || _numConfirmationsRequired > _owners.length) {
            revert InvalidConfirmationNumber();
        }

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            if (owner == address(0)) {
                revert InvalidOwner();
            }
            if (isOwner[owner]) {
                revert NonUniqueOwner();
            }

            isOwner[owner] = true;
            owners.push(owner);
        }

        numConfirmationsRequired = _numConfirmationsRequired;
    }

    /*//////////////////////////////////////////////////////////////
                            MULTISIG LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Submit a new transaction to be confirmed and executed.
     * @param _to Destination address of the transaction.
     * @param _value Ether value of the transaction.
     * @param _deadline Deadline for confirming the transaction.
     * @param _data Transaction data.
     */
    function submitTransaction(address _to, uint256 _value, uint256 _deadline, bytes memory _data)
        external
        onlyOwner
        returns (uint256)
    {
        uint256 transactionIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                deadline: _deadline,
                data: _data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitTransaction(msg.sender, transactionIndex, _to, _value, _deadline, _data);

        return transactionIndex;
    }

    /**
     * @dev Confirm a transaction.
     * @param _transactionIndex Index of the transaction to confirm.
     */
    function confirmTransaction(uint256 _transactionIndex)
        external
        onlyOwner
        transactionExists(_transactionIndex)
        transactionNotExecuted(_transactionIndex)
        transactionNotConfirmed(_transactionIndex)
    {
        Transaction storage transaction = transactions[_transactionIndex];
        transaction.numConfirmations += 1;
        hasOwnerConfirmed[_transactionIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _transactionIndex);
    }

    /**
     * @dev Revoke confirmation of a transaction.
     * @param _transactionIndex Index of the transaction to revoke confirmation.
     */
    function revokeConfirmation(uint256 _transactionIndex)
        external
        onlyOwner
        transactionExists(_transactionIndex)
        transactionNotExecuted(_transactionIndex)
        isTransactionConfirmed(_transactionIndex)
    {
        Transaction storage transaction = transactions[_transactionIndex];

        transaction.numConfirmations -= 1;
        hasOwnerConfirmed[_transactionIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _transactionIndex);
    }

    /**
     * @dev Execute a confirmed transaction.
     * @param _transactionIndex Index of the transaction to execute.
     */
    function executeTransaction(uint256 _transactionIndex)
        external
        onlyOwner
        transactionExists(_transactionIndex)
        transactionNotExecuted(_transactionIndex)
        enoughTransactionConfirmations(_transactionIndex)
        beforeTransactionDeadline(_transactionIndex)
        returns (bytes memory)
    {
        Transaction storage transaction = transactions[_transactionIndex];

        transaction.executed = true;

        (bool success, bytes memory data) = transaction.to.call{value: transaction.value}(transaction.data);

        if (!success) {
            revert TransactionFailed();
        }

        emit ExecuteTransaction(msg.sender, _transactionIndex);

        return data;
    }

    /**
     * @dev Fallback function to receive ether and emit a deposit event.
     */
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Get the list of owners.
     * @return owners List of owners.
     */
    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    /**
     * @dev Get a specific owner at a given index from owners.
     * @return owner Address of owner at given index.
     */
    function getOwnerAtIndex(uint256 _index) external view returns (address) {
        return owners[_index];
    }

    /**
     * @dev Get the count of transactions.
     * @return count Count of transactions.
     */
    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }

    /**
     * @dev Get details of a transaction.
     * @param _transactionIndex Index of the transaction.
     * @return to Destination address of the transaction.
     * @return value Ether value of the transaction.
     * @return deadline Expiry date of the transaction.
     * @return data Transaction data.
     * @return executed Whether the transaction has been executed.
     * @return numConfirmations Number of confirmations received for the transaction.
     */
    function getTransactionAtIndex(uint256 _transactionIndex)
        external
        view
        returns (
            address to,
            uint256 value,
            uint256 deadline,
            bytes memory data,
            bool executed,
            uint256 numConfirmations
        )
    {
        Transaction storage transaction = transactions[_transactionIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.deadline,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }
}
