// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract LMC is Ownable {
    struct ProductIn {
        string referenceDate; // yyyy-mm-dd
        uint256 tankId;
        uint256 volumeDeciliters;
        uint256 cashCents;
        string productName;
        uint256 invoiceXmlKey;
    }

    struct ProductOut {
        string referenceDate; // yyyy-mm-dd
        uint256 tankId;
        uint256 nozzleId;
        uint256 volumeDeciliters;
        uint256 cashCents;
    }

    struct ProductStock {
        string referenceDate; // yyyy-mm-dd
        uint256 tankId;
        uint256 volumeDeciliters;
    }

    uint256 private nextTransactionId = 1;

    mapping(uint256 => ProductIn) public productIns;
    mapping(uint256 => ProductOut) public productOuts;
    mapping(uint256 => ProductStock) public productStocks;

    mapping(address => uint256[]) private userTransactions;

    constructor() Ownable(msg.sender) {
        // Constructor content (if any)
    }

function productIn(
    string memory referenceDate, 
    uint[] memory tankIds, 
    uint[] memory volumeDeciliters, 
    uint[] memory cashCents, 
    string[] memory productNames, 
    uint[] memory invoiceXmlKeys
) public {
    require(tankIds.length == volumeDeciliters.length && 
            tankIds.length == cashCents.length &&
            tankIds.length == productNames.length &&
            tankIds.length == invoiceXmlKeys.length, "Array lengths must match");

    for (uint i = 0; i < tankIds.length; i++) {
        productIns[nextTransactionId] = ProductIn(
            referenceDate, 
            tankIds[i], 
            volumeDeciliters[i], 
            cashCents[i], 
            productNames[i], 
            invoiceXmlKeys[i]
        );
        userTransactions[msg.sender].push(nextTransactionId);
        nextTransactionId++;
    }
}

function productOut(
    string memory referenceDate, 
    uint[] memory tankIds, 
    uint[] memory nozzleIds, 
    uint[] memory volumeDeciliters, 
    uint[] memory cashCents
) public {
    require(tankIds.length == nozzleIds.length && 
            tankIds.length == volumeDeciliters.length &&
            tankIds.length == cashCents.length, "Array lengths must match");

    for (uint i = 0; i < tankIds.length; i++) {
        productOuts[nextTransactionId] = ProductOut(
            referenceDate, 
            tankIds[i], 
            nozzleIds[i], 
            volumeDeciliters[i], 
            cashCents[i]
        );
        userTransactions[msg.sender].push(nextTransactionId);
        nextTransactionId++;
    }
}


function productStock(
    string memory referenceDate, 
    uint[] memory tankIds, 
    uint[] memory volumeDeciliters
) public {
    require(tankIds.length == volumeDeciliters.length, "Array lengths must match");

    for (uint i = 0; i < tankIds.length; i++) {
        productStocks[nextTransactionId] = ProductStock(
            referenceDate, 
            tankIds[i], 
            volumeDeciliters[i]
        );
        userTransactions[msg.sender].push(nextTransactionId);
        nextTransactionId++;
    }
}


    function audit(address user)
        public
        view
        returns (
            ProductIn[] memory,
            ProductOut[] memory,
            ProductStock[] memory
        )
    {
        uint256[] memory transactions = userTransactions[user];
        uint256 totalTransactions = transactions.length;

        uint256 productInCount;
        uint256 productOutCount;
        uint256 productStockCount;

        // Count non-zero entries
        for (uint256 i = 0; i < totalTransactions; i++) {
            if (productIns[transactions[i]].tankId != 0) productInCount++;
            if (productOuts[transactions[i]].tankId != 0) productOutCount++;
            if (productStocks[transactions[i]].tankId != 0) productStockCount++;
        }

        ProductIn[] memory filteredProductIns = new ProductIn[](productInCount);
        ProductOut[] memory filteredProductOuts = new ProductOut[](
            productOutCount
        );
        ProductStock[] memory filteredProductStocks = new ProductStock[](
            productStockCount
        );

        uint256 inCounter;
        uint256 outCounter;
        uint256 stockCounter;

        // Filter and assign non-zero entries
        for (uint256 i = 0; i < totalTransactions; i++) {
            uint256 transactionId = transactions[i];
            if (productIns[transactionId].tankId != 0) {
                filteredProductIns[inCounter] = productIns[transactionId];
                inCounter++;
            }
            if (productOuts[transactionId].tankId != 0) {
                filteredProductOuts[outCounter] = productOuts[transactionId];
                outCounter++;
            }
            if (productStocks[transactionId].tankId != 0) {
                filteredProductStocks[stockCounter] = productStocks[
                    transactionId
                ];
                stockCounter++;
            }
        }

        return (filteredProductIns, filteredProductOuts, filteredProductStocks);
    }
}
