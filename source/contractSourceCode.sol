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
    event Log(string message);
    event LogUint(string message, uint256 value);
    mapping(uint256 => ProductTransaction) public transactionRecords;
    mapping(address => uint256[]) private userTransactions;
    mapping(address => mapping(uint256 => bool)) private userDateRecords;
    mapping(address => uint256[]) private userTanks;
    mapping(address => mapping(uint256 => uint256)) public userVolumeStockDate;
    mapping(address => mapping(uint256 => uint256)) public userVolumeStock;
    mapping(address => mapping(uint256 => uint256)) private userVolumeIn;
    mapping(address => mapping(uint256 => uint256)) private userVolumeOut;
    address[] private users;

    constructor() Ownable(msg.sender) {}

    // Function to add tankId to userTanks if it's not already there
    function addTankIdIfNotPresent(uint256 tankId) private {
        // Retrieve the user's tank array
        uint256[] memory tanks = userTanks[msg.sender];

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
        // Check - date valid?
        require(
            BokkyPooBahsDateTimeLibrary.isValidDate(
                referenceDate.year,
                referenceDate.month,
                referenceDate.day
            ),
            "Data invalida."
        );
        // Check - only one referenceDate per user can be stored on the blockchain
        require(
            !userDateRecords[msg.sender][
                BokkyPooBahsDateTimeLibrary.timestampFromDate(
                    referenceDate.year,
                    referenceDate.month,
                    referenceDate.day
                )
            ],
            "Data ja registrada."
        );
        // set refereceDateTimestamp
        uint256 referenceDateTimestamp = BokkyPooBahsDateTimeLibrary
            .timestampFromDate(
                referenceDate.year,
                referenceDate.month,
                referenceDate.day
            );
        // Se o array de transacoes do usuario esta vazio, adiciona um elemento usuario ao array de usuarios, contendo o endereco do usuario
        // essa verificacao eh mais simples do que correr o array de usuario e procurar o usuario nele
        if (userTransactions[msg.sender].length == 0) {
            users.push(msg.sender);
        }

        ProductTransaction storage newTransactionRecord = transactionRecords[
            nextTransactionId
        ];
        newTransactionRecord.userAddress = msg.sender;
        newTransactionRecord.referenceDate = referenceDate;
        // le o  array de entrada
        for (uint256 i = 0; i < transactionsData.length; i++) {
            uint256 tankId = transactionsData[i].tankId;
            uint256 volume = transactionsData[i].volume;
            uint256 tempDateTimestamp = 0;
            // salva o dado completo da transação na estrutura transactionsData
            newTransactionRecord.transactions.push(transactionsData[i]);
            // atualiza a lista de tanques do usuário
            addTankIdIfNotPresent(tankId);
            // atualiza o volumeIn total ou volumeOut total ou ultima posição de estoque (data e volume)
            if (transactionsData[i].transactionType == TransactionType.In) {
                // volumeIn total
                userVolumeIn[msg.sender][tankId] += volume;
            } else if (
                transactionsData[i].transactionType == TransactionType.Out
            ) {
                // volumeOut total
                userVolumeOut[msg.sender][tankId] += volume;
            } else if (
                transactionsData[i].transactionType == TransactionType.Stock
            ) {
                // volumeStock ultimo
                tempDateTimestamp = userVolumeStockDate[msg.sender][tankId];
                if (referenceDateTimestamp >= tempDateTimestamp) {
                    userVolumeStockDate[msg.sender][
                        tankId
                    ] = referenceDateTimestamp;
                    userVolumeStock[msg.sender][tankId] = volume;
                }
                emit LogUint("Volume", userVolumeStock[msg.sender][tankId]);
            }
        }
        // cria o próximo record no array userTransactions
        userTransactions[msg.sender].push(nextTransactionId);
        // atualiza a lista de datas (de referencia) do usuario
        userDateRecords[msg.sender][referenceDateTimestamp] = true;
        nextTransactionId++;
    }

    //
    // function readTransactions()
    //
    // le as transacoes gravadas
    //
    //      se usuario for owner - retorna todas as transacoes de todos os usuarios
    //      se usuario nao for owner - retorna todas as suas transacoes
    //
    // function readTransactions(address userAddress)
    //
    //      se usuario for owner - retorna todas as transacoes do usuaririo userAddress
    //      se usuario nao for owner - retorna todas as suas transacoes se userAddress igual ao usuario chamando a funcao,
    //                                 retorna erro caso contrario
    //
    // retorno: usuario, data de referencia e um array dos dados gravados
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
    // function checkRecordExists(referenceDate)
    //
    // pode ser usado pelo frontend para verificar antes de mandar gravar na blockchain
    // caso o frontend nao faca essa verificacao, a funcao "recordTransaction" tambem verifica
    //
    // retorno bool:
    // true - ja existe um record para o usuario que esta chamado a funcao na data referenceDate
    // false - caso contrario
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
    // function calculateDivergence(userAddress opcional)
    // 
    // calcula divergencia %, por tanque, entre estoque contabil (total de volumeIn - total de volumeOut) 
    // e fisico (volume de estoque informado na data de refencia mais recente para aquele tanque)
    //
    
    // sem parametro de entrada - retorna divergencia do proprio usuario
    function calculateDivergence()
        public
        view
        returns (TankVolumeCalculation[] memory)
    {
        return calculateUserDivergence(msg.sender);
    }

   // com parametro de entrada - retorna divergencia de qualquer usuario (se chamada pelo owner) ou somente do proprio usuario (se chamada por nao-owner)
    function calculateDivergence(address userAddress)
        public
        view
        returns (TankVolumeCalculation[] memory)
    {
        require(
            msg.sender == owner() || msg.sender == userAddress,
            "Sem acesso. Apenas o owner pode ver outros usuarios."
        );
        return calculateUserDivergence(userAddress);
    }

    function calculateUserDivergence(address userAddress)
        private
        view
        returns (TankVolumeCalculation[] memory)
    {
        // le array de tanques do usuario
        uint256[] memory tanks = userTanks[userAddress];
        // cria array de saida com o mesmo tamanho do array de tanques do usuairo
        TankVolumeCalculation[]
            memory tankCalculations = new TankVolumeCalculation[](tanks.length);
        // calcula divergencia para cada tanque do usuario
        for (uint256 i = 0; i < tanks.length; i++) {
            uint256 tankId = tanks[i];
            int256 volumeIn = int256(userVolumeIn[userAddress][tankId]); // converte para int para permitir que o calculo da divergencia possa ser negativo
            int256 volumeOut = int256(userVolumeOut[userAddress][tankId]); // converte para int para permitir que o calculo da divergencia possa ser negativo
            int256 lastStock = int256(userVolumeStock[userAddress][tankId]); // converte para int para permitir que o calculo da divergencia possa ser negativo
            int256 divergence = 0;
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