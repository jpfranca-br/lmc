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
        uint256 nozzleId;
        uint256 volume;
        uint256 cash;
        uint256 productCode;
        uint256 invoiceXmlKey;
    }

    struct ReferenceDate {
        uint256 year;
        uint256 month;
        uint256 day;
    }

    struct ProductTransaction {
        address userAddress;
        ReferenceDate referenceDate;
        TransactionData[] transactions;
    }

    struct TankVolumeCalculation {
        uint256 tankId;
        int256 totalVolumeIn;
        int256 totalVolumeOut;
        int256 lastVolumeStock;
        int256 volumeDivergence;
    }

    uint256 private nextTransactionId = 1;
    mapping(uint256 => ProductTransaction) private transactionRecords;
    mapping(address => uint256[]) private userTransactions;
    mapping(address => mapping(uint256 => bool)) private userDateRecords;
    mapping(address => uint256[]) private userTanks;
    mapping(address => mapping(uint256 => uint256)) private userVolumeIn;
    mapping(address => mapping(uint256 => uint256)) private userVolumeOut;
    address[] private users; // Array to keep track of all users

    constructor() Ownable(msg.sender) {}

    // Function to add tankId to userTanks if it's not already there
    function addTankIdIfNotPresent(uint256 tankId) private {
        // Retrieve the user's tank array
        uint256[] memory tanks = userTanks[msg.sender];      ////////////////////////////////////

        // Check if tankId is already in the array
        bool isPresent = false;
        for (uint256 i = 0; i < tanks.length; i++) {
            if (tanks[i] == tankId) {
                isPresent = true;
                break;
            }
        }

        // If tankId is not present, add it to the array
        if (!isPresent) {
            userTanks[msg.sender].push(tankId);
        }
    }

    //
    // record transaction to the blockchain
    //

    function recordTransaction(
        ReferenceDate memory referenceDate,
        TransactionData[] memory transactionsData
    ) public {
        uint256 year = referenceDate.year;
        uint256 month = referenceDate.month;
        uint256 day = referenceDate.day;
        uint256 referenceDateTimestamp = BokkyPooBahsDateTimeLibrary
            .timestampFromDate(year, month, day);
        // Check - date valid?
        require(
            BokkyPooBahsDateTimeLibrary.isValidDate(year, month, day),
            "Data invalida."
        );
        // Check - only one referenceDate per user can be stored on the blockchain
        require(
            !userDateRecords[msg.sender][referenceDateTimestamp],
            "Data ja registrada."
        );
        // Add user to users array if not already included
        if (userTransactions[msg.sender].length == 0) {
            users.push(msg.sender);
        }

        ProductTransaction storage newTransactionRecord = transactionRecords[          ////////////////////////////
            nextTransactionId
        ];

        newTransactionRecord.userAddress = msg.sender;
        newTransactionRecord.referenceDate = referenceDate;
        for (uint256 i = 0; i < transactionsData.length; i++) {
            uint256 tankId = transactionsData[i].tankId;
            uint256 volume = transactionsData[i].volume;
            newTransactionRecord.transactions.push(transactionsData[i]);
            if (transactionsData[i].transactionType == TransactionType.In) {
                userVolumeIn[msg.sender][tankId] += volume;
            } else if (
                transactionsData[i].transactionType == TransactionType.Out
            ) {
                userVolumeOut[msg.sender][tankId] += volume;
            }
            addTankIdIfNotPresent(tankId);
        }
        userTransactions[msg.sender].push(nextTransactionId);
        userDateRecords[msg.sender][referenceDateTimestamp] = true;
        nextTransactionId++;
    }

    //
    // read transaction from the blockchain
    //

    function readTransactions()
        public
        view
        returns (ProductTransaction[] memory)
    {
        ProductTransaction[] memory transactions;

        if (msg.sender == owner()) {
            // Owner fetches transactions for all users
            transactions = getAllTransactions();
        } else {
            // Regular user fetches their own transactions
            transactions = getUserTransactions(msg.sender);
        }

        return transactions;
    }

    function readTransactions(address userAddress)
        public
        view
        returns (ProductTransaction[] memory)
    {
        require(
            msg.sender == owner() || msg.sender == userAddress,
            "Unauthorized access: Owner can access all user transactions. Regular user can only access own transactions. Same as calling without argument"
        );
        ProductTransaction[] memory transactions;
        if (address(this) == owner()) {
            // Owner fetches transactions for any user
            transactions = getUserTransactions(userAddress);
        } else {
            // Regular user fetches their own transactions
            transactions = getUserTransactions(msg.sender);
        }
        return transactions;
    }

    function getAllTransactions()
        private
        view
        returns (ProductTransaction[] memory)
    {
        ProductTransaction[] memory allTransactions;
        uint256 totalTransactionCount = 0;

        for (uint256 i = 0; i < users.length; i++) {
            totalTransactionCount += userTransactions[users[i]].length;
        }

        allTransactions = new ProductTransaction[](totalTransactionCount);
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < users.length; i++) {
            for (uint256 j = 0; j < userTransactions[users[i]].length; j++) {
                uint256 transactionId = userTransactions[users[i]][j];
                allTransactions[currentIndex] = transactionRecords[
                    transactionId
                ];
                allTransactions[currentIndex].userAddress = users[i];
                currentIndex++;
            }
        }

        return allTransactions;
    }

    function getUserTransactions(address userAddress)
        private
        view
        returns (ProductTransaction[] memory)
    {
        uint256[] memory transactionIds = userTransactions[userAddress];
        ProductTransaction[]
            memory userTransactionData = new ProductTransaction[](
                transactionIds.length
            );

        for (uint256 i = 0; i < transactionIds.length; i++) {
            userTransactionData[i] = transactionRecords[transactionIds[i]];
            userTransactionData[i].userAddress = userAddress;
        }

        return userTransactionData;
    }

    //
    // check if a record for date already exists - can be used by the front end to reject input without trying to write to the blockchain
    //

    function checkRecordExists(ReferenceDate memory referenceDate)
        public
        view
        returns (bool)
    {
        uint256 year = referenceDate.year;
        uint256 month = referenceDate.month;
        uint256 day = referenceDate.day;
        uint256 referenceDateTimestamp = BokkyPooBahsDateTimeLibrary
            .timestampFromDate(year, month, day);
        return userDateRecords[msg.sender][referenceDateTimestamp];
    }

    //
    // calculate volumes and last stock position for the user to check for consistency
    //

    function calculateVolumesGlobal()
        public
        view
        returns (
            int256 totalVolumeIn,
            int256 totalVolumeOut,
            int256 lastVolumeStock,
            int256 volumeDivergence
        )
    {
        uint256[] memory transactionIds = userTransactions[msg.sender];
        uint256 tempDateTimestamp = 0;
        uint256 latestDateTimestamp = 0;
        totalVolumeIn = 0;
        totalVolumeOut = 0;
        lastVolumeStock = 0;
        volumeDivergence = 0;

        for (uint256 i = 0; i < transactionIds.length; i++) {
            ProductTransaction memory transaction = transactionRecords[             ////////////////////////////////////////
                transactionIds[i]
            ];
            tempDateTimestamp = BokkyPooBahsDateTimeLibrary.timestampFromDate(
                transaction.referenceDate.year,
                transaction.referenceDate.month,
                transaction.referenceDate.day
            );
            for (uint256 j = 0; j < transaction.transactions.length; j++) {
                TransactionData memory data = transaction.transactions[j];          /////////////////////////

                if (data.transactionType == TransactionType.In) {
                    totalVolumeIn += int256(data.volume);
                } else if (data.transactionType == TransactionType.Out) {
                    totalVolumeOut += int256(data.volume);
                } else if (data.transactionType == TransactionType.Stock) {
                    // Compare dates
                    if (tempDateTimestamp > latestDateTimestamp) {
                        latestDateTimestamp = tempDateTimestamp;
                        lastVolumeStock = int256(data.volume);
                    }
                }
            }
        }

        if (lastVolumeStock != 0) {
            volumeDivergence =
                int256(1e4) -
                int256(
                    ((totalVolumeIn - totalVolumeOut) * 1e4) / lastVolumeStock
                );
        } else {
            volumeDivergence = 0;
        }

        return (
            totalVolumeIn,
            totalVolumeOut,
            lastVolumeStock,
            volumeDivergence
        );
    }

    function calculateVolumes()
        public
        view
        returns (TankVolumeCalculation[] memory)
    {
        uint256[] memory tanks = userTanks[msg.sender];                     /////////////////////////////////
        TankVolumeCalculation[]
            memory tankCalculations = new TankVolumeCalculation[](tanks.length);

        for (uint256 i = 0; i < tanks.length; i++) {
            uint256 tankId = tanks[i];
            uint256 latestDateTimestamp = 0;
            int256 volumeIn = int256(userVolumeIn[msg.sender][tankId]);
            int256 volumeOut = int256(userVolumeOut[msg.sender][tankId]);
            int256 lastStock = 0; // Initialize last stock volume
            int256 divergence = 0; // Initialize volume divergence

            uint256[] memory transactionIds = userTransactions[msg.sender];

            for (uint256 j = 0; j < transactionIds.length; j++) {
                ProductTransaction memory transaction = transactionRecords[             ////////////////////////////// storage
                    transactionIds[j]
                ];
                for (uint256 k = 0; k < transaction.transactions.length; k++) {
                    TransactionData memory data = transaction.transactions[k];           ////////////////////////////
                    if (data.tankId == tankId) {
                        if (data.transactionType == TransactionType.Stock) {
                            uint256 tempDateTimestamp = BokkyPooBahsDateTimeLibrary
                                    .timestampFromDate(
                                        transaction.referenceDate.year,
                                        transaction.referenceDate.month,
                                        transaction.referenceDate.day
                                    );
                            if (tempDateTimestamp > latestDateTimestamp) {
                                latestDateTimestamp = tempDateTimestamp;
                                lastStock = int256(data.volume);
                            }
                        }
                    }
                }
            }

            divergence = 0;
            if (lastStock != 0) {
                divergence =
                    int256(1e4) -
                    int256(((volumeIn - volumeOut) * 1e4) / lastStock);
            }

            // Assigning the calculated values to the tankCalculations array
            tankCalculations[i] = TankVolumeCalculation(
                tankId,
                volumeIn,
                volumeOut,
                lastStock,
                divergence
            );
        }
        return tankCalculations;
    }
}
