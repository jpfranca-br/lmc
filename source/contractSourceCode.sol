// SPDX-License-Identifier: MIT
//
//
// LMC Smart Contract - V3.2
//
// Smart contract to digitally replicate the process of recording data in the Fuel Movement Logbook
// ("Livro de Movimentação de Combustíveis" - LMC), a daily requirement for Brazilian fuel stations,
// utilizing a blockchain framework.
//
// See more at
// https://github.com/jpfranca-br/lmc
//

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "https://github.com/bokkypoobah/BokkyPooBahsDateTimeLibrary/blob/master/contracts/BokkyPooBahsDateTimeLibrary.sol";

contract LMC is Ownable {

    // subestrutura transacao - data de referencia
    struct ReferenceDate {
        uint256 year;
        uint256 month;
        uint256 day;
    }

    // subsubestrutura transacao - tipos
    enum TransactionType {
        In, // entrada de notas fiscais
        Out, // saida de produtos = abastecimentos
        Stock // medida do estoque fisico
    }

    // subestrutura transacao - core
    struct TransactionData {
        TransactionType transactionType; // tipo definido acima
        uint256 tankId; // id do tanque
        uint256 nozzleId; // id do bico da bomba
        uint256 volume; // volume
        uint256 cash; // valor
        uint256 productCode; // codigo do produto
        uint256 invoiceXmlKey; // chave da nota fiscal (entrada)
    }

    // estrutura transacao
    struct ProductTransaction {
        address userAddress;             // endereco
        ReferenceDate referenceDate;     // data
        TransactionData[] transactions;  // tipo, tankId, nozzleId, volume, cash, productCode, invoiceXmlKey
    }

    // estrutura para calculo de divergencia contabil-fisica
    struct TankVolumeCalculation {
        uint256 tankId;
        int256 totalVolumeIn;
        int256 totalVolumeOut;
        int256 lastVolumeStock;
        int256 volumeDivergence;
    }

    uint256 private nextTransactionId = 1;
    // userTransactions[endereco_usuario] = [ids_transacoes]                              // array dos ids de transacao de cada usuario
    mapping(address => uint256[]) private userTransactions;
    // transactionRecords[id_transacao] = estrutura do tipo ProductTansaction             // detalhes da transacao (id_transacao) - estrutura principal de armazenamento.
    mapping(uint256 => ProductTransaction) private transactionRecords;
    // users[indice] = endereco_usuario                                                   // usuarios que gravaram na blockchain. Nao esta sendo usado, previsao para auditoria futura.
    address[] private users;
    // userDateRecords[endereco_usuario][timestamp_data_referencia] = bool                // datas de referencia que o usuario registrou, usado para verificar se o usuario já registrou algo na data
    mapping(address => mapping(uint256 => bool)) private userDateRecords;
    // userTanks[endereco_usuario] = [tanques que o usuario registrou]                    // para calcular divergencia mais facilmente, ja que os tanques nao sao necessariamente incrementais
    mapping(address => uint256[]) private userTanks;
    // userVolumeStockDate[endereco_usuario][tanque] = maior timestamp da data de estoque // para calcular divergencia mais facilmente
    mapping(address => mapping(uint256 => uint256)) private userVolumeStockDate;
    // userVolumeStock[endereco_usuario][tanque] = volume de estoque na data acima        // para calcular divergencia mais facilmente
    mapping(address => mapping(uint256 => uint256)) private userVolumeStock;
    // userVolumeIn[endereco_usuario][tanque] = soma dos volumes de entrada               // para calcular divergencia mais facilmente
    mapping(address => mapping(uint256 => uint256)) private userVolumeIn;
    // userVolumeIn[endereco_usuario][tanque] = soma dos volumes de saida                 // para calcular divergencia mais facilmente
    mapping(address => mapping(uint256 => uint256)) private userVolumeOut;

    constructor() Ownable(msg.sender) {}

    // Funcao para atualizar userTanks (se o tanque nao estiver presente)
    function addTankIdIfNotPresent(uint256 tankId) private {
        // Le o array de tanques do usuario
        uint256[] memory tanks = userTanks[msg.sender];
        // Verifica se o  tanque esta no array
        bool isPresent = false;
        for (uint256 i = 0; i < tanks.length; i++) {
            if (tanks[i] == tankId) {
                isPresent = true;
                break;
            }
        }
        // Se nao estiver, adiciona
        if (!isPresent) {
            userTanks[msg.sender].push(tankId);
        }
    }

    //
    // Funcao para gravar a estrutura de dados na blockchain
    // 
    // 
    // os dados de entrada são no formato
    // [yyyy,mm,dd],[[tipo = 0 para In 1 para Out 2 para Estoque,tanque,bico (somente Out),volume,valor (para In e Out),codigo produto (somente In),chave XML nota (somente In)],...]
    // exemplo
    // [2024,2,14],[[0,0,0,10,0,0,0],[1,0,0,2,0,0,0],[2,0,0,8,0,0,0]]
    // 

    function recordTransaction(
        ReferenceDate memory referenceDate,
        TransactionData[] memory transactionsData
    ) public {
        // Verifica se a data é válida
        require(
            BokkyPooBahsDateTimeLibrary.isValidDate(
                referenceDate.year,
                referenceDate.month,
                referenceDate.day
            ),
            "Data invalida."
        );
        // Verifica se a data já está registrada
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
        // Converte data de referencia em timestamp
        uint256 referenceDateTimestamp = BokkyPooBahsDateTimeLibrary
            .timestampFromDate(
                referenceDate.year,
                referenceDate.month,
                referenceDate.day
            );
        // Se o array de transacoes do usuario esta vazio, adiciona um elemento usuario ao array de usuarios, contendo o endereco do usuario
        // essa verificacao eh mais simples do que correr o array de usuario procurando por ele
        // para arrays dinamicos, preciso fazer "push"
        if (userTransactions[msg.sender].length == 0) {
            users.push(msg.sender);
        }
        // cria mais um registro de transacao
        // atencao a forma como o solidity lida com storage. aqui esta referenciando newTransactionRecord a estrutura  (nova ou existente)
        // transactionsRecords[nextTranscationId]. Toda alteracao em newTransactionRecord altera o que esta armazenado
        // comportamento bem diferente de como estamos acostumados a lidar com variaveis em memoria
        ProductTransaction storage newTransactionRecord = transactionRecords[nextTransactionId];
        // cada registro tem somente um usuario e uma data de referencia
        // e depois varias linhas com as entradas, saidas, estoques informados para aquela data
        // popula com endereco do usuario e data de referencia
        newTransactionRecord.userAddress = msg.sender;
        newTransactionRecord.referenceDate = referenceDate;
        // le o  array de entrada da funcao
        for (uint256 i = 0; i < transactionsData.length; i++) {
            // busca os dados de entrada e atualiza na newTransactionRecord
            newTransactionRecord.transactions.push(transactionsData[i]);
            // le variaveis de tankId e volume para atualizar os acumuladores de volumeIn, volumeOut, assim como ultima posicao de estoque
            uint256 tankId = transactionsData[i].tankId;
            uint256 volume = transactionsData[i].volume;
            uint256 tempDateTimestamp = 0;
            // atualiza a lista de tanques do usuário
            addTankIdIfNotPresent(tankId);
            // atualiza o volumeIn total ou volumeOut total ou ultima posição de estoque (data e volume)
            // dependendo do tipo de transacao
            // para transacao tipo In
            if (transactionsData[i].transactionType == TransactionType.In) {
                // atualiza o acumulador volumeIn
                userVolumeIn[msg.sender][tankId] += volume;
            } else if (
                // para transacao tipo Out
                transactionsData[i].transactionType == TransactionType.Out
            ) {
                // atualiza o acumulador volumeOut
                userVolumeOut[msg.sender][tankId] += volume;
            } else if (
                // para transacao tipo Stock
                transactionsData[i].transactionType == TransactionType.Stock
            ) {
                // verifica se o timestamp informado é maior que o armazenado
                tempDateTimestamp = userVolumeStockDate[msg.sender][tankId];
                if (referenceDateTimestamp >= tempDateTimestamp) {
                    // guarda novo timestamp
                    userVolumeStockDate[msg.sender][
                        tankId
                    ] = referenceDateTimestamp;
                    // guarda nova posicao de estoque
                    userVolumeStock[msg.sender][tankId] = volume;
                }
            }
        }
        // adiciona o id da transacao no array de transacoes do usuario 
        userTransactions[msg.sender].push(nextTransactionId);
        // adiciona a data de referencia no array de datas do usuario
        userDateRecords[msg.sender][referenceDateTimestamp] = true;
        nextTransactionId++;
    }

    //
    // function readTransactions(userAddress opcional)
    // retorna transacoes do usuario
    // retorno: usuario, data de referencia e um array dos dados gravados
    //

    // sem parametro de entrada - retorna a própria divergencia
    function readTransactions()
        public
        view
        returns (ProductTransaction[] memory)
    {
        return getUserTransactions(msg.sender);
    }

    // com parametro de entrada - retorna divergencia de qualquer usuario (se chamada pelo owner) ou somente do proprio usuario (se chamada por nao-owner)
    function readTransactions(address userAddress)
        public
        view
        returns (ProductTransaction[] memory)
    {
        require(
            msg.sender == owner() || msg.sender == userAddress,
            "Acesso nao autorizado. Somente a ANP pode ver dados de outros usuarios. Deixe o campo do endereco em branco ou coloque o seu proprio endereco."
        );
        return getUserTransactions(userAddress);
    }

    function getUserTransactions(address userAddress)
        private
        view
        returns (ProductTransaction[] memory)
    {
        // recupera array de transactionIds do usuario
        uint256[] memory transactionIds = userTransactions[userAddress];
        // cria um array de transacoes da altura do array acima
        ProductTransaction[]
            memory userTransactionData = new ProductTransaction[](
                transactionIds.length
            );
        // recupera transacoes do usuario e grava nesse array de transacoes
        for (uint256 i = 0; i < transactionIds.length; i++) {
            userTransactionData[i] = transactionRecords[transactionIds[i]];
        }
        // retorna array de transacoes
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

    // sem parametro de entrada - retorna a própria divergencia
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

    // funcao que realiza o calculo
    function calculateUserDivergence(address userAddress)
        private
        view
        returns (TankVolumeCalculation[] memory)
    {
        // le array de tanques do usuario
        uint256[] memory tanks = userTanks[userAddress];
        // cria array de saida com altura  array de tanques do usuairo
        TankVolumeCalculation[]
            memory tankCalculations = new TankVolumeCalculation[](tanks.length);
        // loop pro todos os tanques do usuario
        for (uint256 i = 0; i < tanks.length; i++) {
            uint256 tankId = tanks[i];
            int256 volumeIn = int256(userVolumeIn[userAddress][tankId]); // converte para int para permitir que o calculo da divergencia possa ser negativo
            int256 volumeOut = int256(userVolumeOut[userAddress][tankId]); // converte para int para permitir que o calculo da divergencia possa ser negativo
            int256 lastStock = int256(userVolumeStock[userAddress][tankId]); // converte para int para permitir que o calculo da divergencia possa ser negativo
            int256 divergence = 0;
            // so calcula se o denominador <> 0
            if (lastStock != 0) {
                divergence =
                    int256(1e4) -
                    int256(((volumeIn - volumeOut) * 1e4) / lastStock);
            }
            // Grava os valores calculados no array
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
