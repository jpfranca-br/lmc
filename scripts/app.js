let web3;
let contract;

async function connectWallet() {
    if (typeof window.ethereum !== 'undefined') {
        try {
            const accounts = await ethereum.request({
                method: 'eth_requestAccounts'
            });
            if (accounts.length === 0) {
                console.log("No accounts connected");
                alert("Nenhuma conta conectada.");
            } else {
                console.log("Connected accounts:", accounts);
                document.getElementById("errorMessage").textContent = "Contas disponíveis: " + JSON.stringify(accounts);
                web3 = new Web3(window.ethereum);
                loadContract();
                console.log("Contract loaded");
            }
        } catch (error) {
            console.error("User denied account access");
            alert("Sistema sem acesso à sua conta. Verifique se Metamask está desbloqueado. Dê refresh na página.");
        }
    } else {
        console.error("MetaMask is not installed");
        alert("Baixe https://metamask.io e crie/importe uma conta na Testnet Sepolia. Depois disso, dê refresh na página.");
    }
}

const loadContract = async () => {
    try {
        // Fetch the ABI
        const abiResponse = await axios.get('../config/contractABI.json');
        const abi = abiResponse.data;
        if (!abi) {
            alert("Erro técnico. Contate o suporte.");
            throw new Error("Failed to load contract ABI");
        }
        // Fetch the contract address
        const addressResponse = await axios.get('../config/contractAddress.txt');
        const address = addressResponse.data.trim();
        if (!address) {
            alert("Erro tecnico. Contate o suporte.");
            throw new Error("Failed to load contract address");
        }
        // Create the contract instance
        contract = new web3.eth.Contract(abi, address);
        return contract; // Return the contract instance
    } catch (error) {
        alert("Erro tecnico. Contate o suporte.");
        console.error("Error in loadContract:", error);
        throw error; // Rethrow the error for handling in calling function
    }
};

//
// FUNCOES AUXILIARES PARA INPUT DE DADOS 
// 

// Adiciona linhas dinamicamente a tabela. 
// Listener para habilitar ou desabilitar os campos, dependendo do tipo de transacao
function addRow() {
    var table = document.getElementById("transactionsTableInput");
    var newRow = table.insertRow(-1);

    var cell0 = newRow.insertCell(0);
    var cell1 = newRow.insertCell(1);
    var cell2 = newRow.insertCell(2);
    var cell3 = newRow.insertCell(3);
    var cell4 = newRow.insertCell(4);
    var cell5 = newRow.insertCell(5);
    var cell6 = newRow.insertCell(6);
    var cell7 = newRow.insertCell(7);
    var cell8 = newRow.insertCell(8);

    cell0.innerHTML = '<select class="transactionType" style="width: 70px;text-align: center;"><option value="0">Entrada</option><option value="1">Saida</option><option value="2">Estoque</option></select>';
    cell1.innerHTML = '<input type="number" class="tankId" style="width: 70px;text-align: center;">';
    cell2.innerHTML = '<input type="number" class="nozzleId" style="width: 70px;text-align: center;">';
    cell3.innerHTML = '<input type="text" class="volume" style="width: 150px;text-align: right;" onblur="formatNumberInput(this)">';
    cell4.innerHTML = '<input type="text" class="cash" style="width: 150px;text-align: right;" onblur="formatNumberInput(this)">';
    cell5.innerHTML = '<input type="number" class="productCode" style="width: 70px;text-align: center;">';
    cell6.innerHTML = '<input type="number" class="invoiceXmlKey" style="width: 390px;text-align: center;">';
    cell7.innerHTML = '<button onclick="removeRow(this)">-</button>';
    cell8.innerHTML = '<button onclick="addRow()">+</button>';

    // Add event listener to the transactionType select element
    var transactionTypeSelect = newRow.querySelector('.transactionType');
    transactionTypeSelect.addEventListener('change', function() {
        handleTransactionTypeChange(this);
    });

    // Initialize the row based on the default transactionType
    handleTransactionTypeChange(transactionTypeSelect);
}

// Remove linhas dinamicamente da tabela. 
function removeRow(button) {
    var table = button.parentNode.parentNode.parentNode; // Get the table element
    var rowCount = table.rows.length;

    // Check if the number of rows is greater than 2 (header + at least one data row)
    if (rowCount > 2) {
        var row = button.parentNode.parentNode;
        row.parentNode.removeChild(row);
    } else {
        console.log("Cannot remove the last row.");
    }
}

// Garantir o formato dos campos volume e cash com 2 casas decimais. 
function formatNumberInput(input) {
    // Replace any non-numeric characters except for the dot
    input.value = input.value.replace(/[^0-9.]/g, '');

    // Parse the cleaned input as a float
    var number = parseFloat(input.value);

    // Format the number to two decimal places if it's a valid number
    if (!isNaN(number)) {
        input.value = number.toFixed(2);
    }
}

// Habilitar ou desabilitar os campos editaveis, dependendo do tipo de transacao
function handleTransactionTypeChange(selectElement) {
    var row = selectElement.parentNode.parentNode;
    var tankId = row.querySelector('.tankId');
    var volume = row.querySelector('.volume');
    var cash = row.querySelector('.cash');
    var productCode = row.querySelector('.productCode');
    var invoiceXmlKey = row.querySelector('.invoiceXmlKey');
    var nozzleId = row.querySelector('.nozzleId');

    // Reset fields to be editable
    [tankId, volume, cash, productCode, invoiceXmlKey, nozzleId].forEach(input => {
        input.disabled = false;
        input.value = '';
    });

    switch (selectElement.value) {
        case '0': // Entrada
            nozzleId.disabled = true;
            nozzleId.value = 0;
            break;
        case '1': // Venda
            [invoiceXmlKey, productCode].forEach(input => {
                input.disabled = true;
                input.value = 0;
            });
            break;
        case '2': // Estoque
            [invoiceXmlKey, productCode, nozzleId, cash].forEach(input => {
                input.disabled = true;
                input.value = 0;
            });
            break;
    }
}

// Add an event listener to existing row(s)
document.querySelectorAll('#transactionsTableInput.transactionType').forEach(select => {
    select.addEventListener('change', function() {
        handleTransactionTypeChange(this);
    });
    // Initialize each existing row based on its current transactionType
    handleTransactionTypeChange(select);
});









//
// FUNCOES AUXILIARES PARA RECUPERAR DADOS 
// 

// Subfuncao - formatar a data
function formatDate(referenceDate) {
    return `${referenceDate.year}-${pad(referenceDate.month)}-${pad(referenceDate.day)}`;
}

// Subfuncao - adicionar zero a esquerda se o numero de meses ou dias e menor que 10
function pad(number) {
    return number < 10 ? '0' + number : number;
}

// Subfuncao - De-Para entre o tipo de transacao e nome human-readable 
function transactionTypeToString(type) {
    switch (Number(type)) { // Convert type to a number
        case 0:
            return "Entrada";
        case 1:
            return "Saída";
        case 2:
            return "Estoque";
        default:
            return "ERRO";
    }
}

// Principal - Popular tabela com dados recuperados
function populateTable(transactions) {
    const table = document.getElementById('transactionsTableOutput').getElementsByTagName('tbody')[0];
    table.innerHTML = ''; // Clear existing rows
    transactions.forEach(function(productTransaction) {
        // Format the reference date
        const formattedDate = formatDate(productTransaction.referenceDate);

        productTransaction.transactions.forEach(function(transactionData) {
            const row = table.insertRow();
            const cellValues = [
                productTransaction.userAddress.substring(0, 6), //So mostra os 6 primeiros caracteres do endereco do usuario
                formattedDate,
                transactionTypeToString(transactionData.transactionType),
                transactionData.tankId,
                transactionData.nozzleId,
                transactionData.volume,
                transactionData.cash,
                transactionData.productCode,
                transactionData.invoiceXmlKey
            ];

            cellValues.forEach(function(value) {
                const cell = row.insertCell();
                cell.textContent = value.toString() || 'N/A'; // Handle null or undefined values
            });
        });
    });
}


// So habilita as funcoes abaixo relacionadas a leitura ou escrita no blockchain depois que o documento esta carregado

document.addEventListener('DOMContentLoaded', async function() {
    await connectWallet();
    document.getElementById('submitTransactionButton').addEventListener('click', async () => {
        const referenceDateString = document.getElementById('referenceDate').value;
        if (!referenceDateString) {
            alert("Data inválida.");
            return;
        }
        const referenceDateParsed = {
            year: parseInt(referenceDateString.substring(0, 4)),
            month: parseInt(referenceDateString.substring(5, 7)),
            day: parseInt(referenceDateString.substring(8, 10)),
        };
        const referenceDate = [referenceDateParsed.year, referenceDateParsed.month, referenceDateParsed.day];
        const transactionsData = [];
        document.querySelectorAll('#transactionsTableInput tr:not(:first-child)').forEach(row => {
            const transactionType = row.querySelector('.transactionType').value;
            const tankId = row.querySelector('.tankId').value;
            const nozzleId = row.querySelector('.nozzleId').value;
            const volume = row.querySelector('.volume').value*100;
            const cash = row.querySelector('.cash').value*100;
            const productCode = row.querySelector('.productCode').value;
            const invoiceXmlKey = row.querySelector('.invoiceXmlKey').value;
            transactionsData.push({
                transactionType: parseInt(transactionType),
                tankId: parseInt(tankId),
                nozzleId: parseInt(nozzleId),
                volume: parseInt(volume),
                cash: parseInt(cash),
                productCode: parseInt(productCode),
                invoiceXmlKey: parseInt(invoiceXmlKey)
            });
        });

        try {
            const account = (await web3.eth.getAccounts())[0];
            document.getElementById("errorMessage").textContent = "Conta conectada: " + account;
            contract.methods.checkRecordExists(referenceDate).call({
                    from: account
                })
                .then(exists => {
                    if (exists) {
                        alert("Data já registrada.");
                    } else {
                        contract.methods.recordTransaction(referenceDate, transactionsData)
                            .send({
                                from: account
                            })
                            .then(receipt => {
                                console.log("Recibo: ", receipt);
                                document.getElementById("errorMessage").textContent = "Dados enviados. Seu recibo: " + receipt.transactionHash;
                            })
                            .catch(err => {
                                console.error("Transaction error: ", err);
                                alert("Erro no envio da transação. Contate o suporte ou tente novamente mais tarde.");
                            });
                    }
                })
                .catch(err => {
                    console.error("Error checking record existence: ", err);
                    alert("Verifique se preencheu todos os dados e tente novamente.");
                });
        } catch (err) {
            console.error(err);
        }
    });

//
// RECUPERAR DADOS
//

    document.getElementById('readDataButton').addEventListener('click', function() {
        web3.eth.getAccounts().then(accounts => {
            // Assuming the first account is the user's account
            const userAccount = accounts[0];
            document.getElementById("errorMessage").textContent = "Conta conectada: " + userAccount;
            return contract.methods.readTransactions().call({
                from: userAccount
            });
        }).then(function(transactions) {
            console.log(transactions);
            // Adjust transactions data here
            const adjustedTransactions = transactions.map(transaction => {
                return {
                    ...transaction,
                    transactions: transaction.transactions.map(trans => ({
                        ...trans,
                        volume: (Number(trans.volume) / 100).toFixed(2),
                        cash: (Number(trans.cash) / 100).toFixed(2)
                    }))
                };
            });
            populateTable(adjustedTransactions);
        }).catch(function(error) {
            console.error("Error reading transactions:", error);
        });
    });



//
// CALCULAR DIVERGENCIAS
//

    document.getElementById('calculateVolumesButton').addEventListener('click', function() {
        web3.eth.getAccounts().then(accounts => {
            // Assuming the first account is the user's account
            const userAccount = accounts[0];
            document.getElementById("errorMessage").textContent = "Conta conectada: " + userAccount;
            return contract.methods.calculateVolumes().call({
                from: userAccount
            });
        }).then(function(volumeCalculations) {
            console.log(volumeCalculations);
            displayVolumeCalculations(volumeCalculations);
        }).catch(function(error) {
            console.error("Error calculating volumes:", error);
        });
    });

    function displayVolumeCalculations(volumeCalculations) {
        const table = document.getElementById('volumesTableOutput').getElementsByTagName('tbody')[0];
        table.innerHTML = ''; // Clear existing rows

        volumeCalculations.forEach(function(calculation) {
            const row = table.insertRow();
            const cellValues = [
                calculation.tankId,
                Number(calculation.totalVolumeIn) / 100, // Divided by 100
                Number(calculation.totalVolumeOut) / 100, // Divided by 100
                Number(calculation.lastVolumeStock) / 100, // Divided by 100
                Number(calculation.volumeDivergence) / 100 // Divided by 100
            ];

            cellValues.forEach(function(value, index) {
                const cell = row.insertCell();
                // Format the value with two decimal places for the divided fields
                cell.textContent = (index > 0) ? (value.toFixed(2) || 'N/A') : value.toString();
            });
        });
    }



});