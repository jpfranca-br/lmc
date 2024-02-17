// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
//import "BokkyPooBahsDateTimeLibrary.sol";
import "https://github.com/bokkypoobah/BokkyPooBahsDateTimeLibrary/blob/master/contracts/BokkyPooBahsDateTimeLibrary.sol"; // to check if a date is valid

contract LMC is Ownable {
    enum TransactionType {
        In,
        Out,
        Stock
    }

    struct TransactionData {
        TransactionType transactionType;
        uint256 tankId;
        uint256 volumeDeciliters;
        uint256 cashCents;
        string productName;
        uint256 invoiceXmlKey;
        uint256 nozzleId;
    }

    struct ProductTransaction {
        string referenceDate;
        TransactionData[] transactions;
    }

    struct AuditTransaction {
        address userAddress;
        ProductTransaction transaction;
    }

    uint256 private nextTransactionId = 1;
    mapping(uint256 => ProductTransaction) public transactionRecords;
    mapping(address => uint256[]) private userTransactions;
    mapping(address => mapping(string => bool)) private userDateRecords;
    address[] private users; // Array to keep track of all users

    constructor() Ownable(msg.sender) {}

    //
    // record transaction to the blockchain
    //

    function recordTransaction(
        string memory referenceDate,
        TransactionData[] memory transactionsData
    ) public {
        require(
            !userDateRecords[msg.sender][referenceDate],
            "Transaction for this date already exists."
        );
        (uint256 year, uint256 month, uint256 day) = parseDate(referenceDate);
        require(
            BokkyPooBahsDateTimeLibrary.isValidDate(year, month, day),
            "Invalid date."
        );
        // Add user to users array if not already included
        if (userTransactions[msg.sender].length == 0) {
            users.push(msg.sender);
        }

        ProductTransaction storage newTransactionRecord = transactionRecords[
            nextTransactionId
        ];
        newTransactionRecord.referenceDate = referenceDate;

        for (uint256 i = 0; i < transactionsData.length; i++) {
            newTransactionRecord.transactions.push(transactionsData[i]);
        }

        userTransactions[msg.sender].push(nextTransactionId);
        userDateRecords[msg.sender][referenceDate] = true;
        nextTransactionId++;
    }

    //
    // helper functions for parsing ISO date
    //

    function parseDate(string memory dateString)
        internal
        pure
        returns (
            uint256 year,
            uint256 month,
            uint256 day
        )
    {
        bytes memory dateStringBytes = bytes(dateString);

        require(
            dateStringBytes.length == 10,
            "Date must be in yyyy-mm-dd format"
        );
        require(
            dateStringBytes[4] == "-" && dateStringBytes[7] == "-",
            "Date must be in yyyy-mm-dd format"
        );

        // Extracting year
        year = toInt(substring(dateStringBytes, 0, 4));

        // Extracting month
        month = toInt(substring(dateStringBytes, 5, 7));

        // Extracting day
        day = toInt(substring(dateStringBytes, 8, 10));
    }

    function substring(
        bytes memory str,
        uint256 startIndex,
        uint256 endIndex
    ) internal pure returns (bytes memory) {
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = str[i];
        }
        return result;
    }

    function toInt(bytes memory str) internal pure returns (uint256) {
        uint256 result = 0;
        for (uint256 i = 0; i < str.length; i++) {
            // Convert each character to its integer representation
            result = result * 10 + (uint256(uint8(str[i])) - 48);
        }
        return result;
    }

    //
    // check if a record for specific date already exists - can be used by the front end to reject input without trying to write to the blockchain
    //

    function checkRecordExists(string memory referenceDate)
        public
        view
        returns (bool)
    {
        return userDateRecords[msg.sender][referenceDate];
    }

    // Function without userAddress parameter
    function auditTransactions()
        public
        view
        onlyOwner
        returns (AuditTransaction[] memory)
    {
        return auditTransactionsInternal(address(0));
    }

    //
    // read transactions from the blockchain
    //

    function readTransactions()
        public
        view
        returns (ProductTransaction[] memory)
    {
        uint256[] memory transactionIds = userTransactions[msg.sender];
        ProductTransaction[]
            memory userTransactionData = new ProductTransaction[](
                transactionIds.length
            );

        for (uint256 i = 0; i < transactionIds.length; i++) {
            uint256 transactionId = transactionIds[i];
            ProductTransaction storage transactionRecord = transactionRecords[
                transactionId
            ];
            userTransactionData[i] = transactionRecord;
        }

        return userTransactionData;
    }

    //
    // audit function - similar to the above, but can be called only contract owner and returns transactions for all users(eth addresses) or filtered by user
    //

    // Function with userAddress parameter
    function auditTransactions(address userAddress)
        public
        view
        onlyOwner
        returns (AuditTransaction[] memory)
    {
        return auditTransactionsInternal(userAddress);
    }

    // Internal function that performs the actual logic
    function auditTransactionsInternal(address userAddress)
        internal
        view
        returns (AuditTransaction[] memory)
    {
        uint256 totalTransactionsCount = 0;
        if (userAddress != address(0)) {
            totalTransactionsCount = userTransactions[userAddress].length;
        } else {
            for (uint256 i = 0; i < users.length; i++) {
                totalTransactionsCount += userTransactions[users[i]].length;
            }
        }

        AuditTransaction[] memory auditTransactionData = new AuditTransaction[](
            totalTransactionsCount
        );
        uint256 counter = 0;

        if (userAddress != address(0)) {
            for (uint256 i = 0; i < userTransactions[userAddress].length; i++) {
                uint256 transactionId = userTransactions[userAddress][i];
                auditTransactionData[counter] = AuditTransaction(
                    userAddress,
                    transactionRecords[transactionId]
                );
                counter++;
            }
        } else {
            for (uint256 i = 0; i < users.length; i++) {
                for (
                    uint256 j = 0;
                    j < userTransactions[users[i]].length;
                    j++
                ) {
                    uint256 transactionId = userTransactions[users[i]][j];
                    auditTransactionData[counter] = AuditTransaction(
                        users[i],
                        transactionRecords[transactionId]
                    );
                    counter++;
                }
            }
        }

        return auditTransactionData;
    }
}
