window.addEventListener('load', async () => {
    if (window.ethereum) {
        try {
            await window.ethereum.request({
                method: 'eth_requestAccounts'
            });
            window.web3 = new Web3(window.ethereum);
            initApp();
        } catch (error) {
            console.error("User denied account access or an error occurred:", error);
            var errorMessage = "Usuario negou acesso a conta ou ocorreu um erro: " + (error.message || JSON.stringify(error));
            document.getElementById("errorMessage").textContent = errorMessage;
            //document.getElementById("errorMessage").textContent = "Usuario negou acesso a conta ou ocorreu um erro";
            document.getElementById("errorModal").style.display = "block";
        }
    } else if (window.web3) {
        window.web3 = new Web3(web3.currentProvider);
        initApp();
    } else {
        console.error('Non-Ethereum browser detected. You should consider trying MetaMask!');
        document.getElementById("errorMessage").textContent = "Browser sem extensao Ethereum. Considere instalar o https://metamask.io";
        document.getElementById("errorModal").style.display = "block";
    }
});

let contract; // Declare contract globally

async function loadContractABI() {
    const response = await fetch('contractABI.json');
    const data = await response.json();
    return data;
}

async function startApp() {
    let contractAddress = "0x89c6a06755be8CE794C4994ead34408f3307d55F";
    const contractABI = await loadContractABI();
    contract = new web3.eth.Contract(contractABI, contractAddress); // Remove 'let' to use the global variable
}

async function initApp() {
    try {
        await startApp();
        console.log("Contract is initialized and ready for interactions");
    } catch (error) {
        console.error("Error initializing the app:", error);
        alert("Error initializing the app:", error);
    }
}

function addRow(tableName, tableColumns) {
    const table = document.getElementById(tableName).getElementsByTagName('tbody')[0];
    const newRow = table.insertRow();

    for (let i = 0; i < (tableColumns - 1); i++) {
        let cell = newRow.insertCell(i);
        let input = document.createElement("input");
        input.type = "text";
        cell.appendChild(input);
    }

    // Add delete button in the last cell
    let deleteCell = newRow.insertCell(tableColumns - 1);
    let deleteButton = document.createElement("button");
    deleteButton.innerHTML = "Apagar";
    deleteButton.onclick = function() {
        deleteRow(this);
    };
    deleteCell.appendChild(deleteButton);
}

function deleteRow(btn) {
    let row = btn.parentNode.parentNode;
    row.parentNode.removeChild(row);
}

async function productIn() {
    const referenceDate = document.getElementById("referenceDate").value;
    const table = document.getElementById("productsInTable").getElementsByTagName('tbody')[0];
    const rows = table.rows;

    let tankIds = [];
    let volumeDeciliters = [];
    let cashCents = [];
    let productNames = [];
    let invoiceXmlKeys = [];

    for (let i = 0; i < rows.length; i++) {
        tankIds.push(parseInt(rows[i].cells[0].getElementsByTagName('input')[0].value));
        volumeDeciliters.push(parseInt(rows[i].cells[1].getElementsByTagName('input')[0].value));
        cashCents.push(parseInt(rows[i].cells[2].getElementsByTagName('input')[0].value));
        productNames.push(rows[i].cells[3].getElementsByTagName('input')[0].value);
        invoiceXmlKeys.push(parseInt(rows[i].cells[4].getElementsByTagName('input')[0].value));
    }

    const accounts = await web3.eth.getAccounts();
    await contract.methods.productIn(referenceDate, tankIds, volumeDeciliters, cashCents, productNames, invoiceXmlKeys)
        .send({
            from: accounts[0]
        });
}

async function productOut() {
    const referenceDate = document.getElementById("referenceDate").value;
    const table = document.getElementById("productsOutTable").getElementsByTagName('tbody')[0];
    const rows = table.rows;

    let tankIds = [];
    let nozzleIds = [];
    let volumeDeciliters = [];
    let cashCents = [];

    for (let i = 0; i < rows.length; i++) {
        tankIds.push(parseInt(rows[i].cells[0].getElementsByTagName('input')[0].value));
        nozzleIds.push(parseInt(rows[i].cells[1].getElementsByTagName('input')[0].value));
        volumeDeciliters.push(parseInt(rows[i].cells[2].getElementsByTagName('input')[0].value));
        cashCents.push(parseInt(rows[i].cells[3].getElementsByTagName('input')[0].value));
    }

    const accounts = await web3.eth.getAccounts();
    await contract.methods.productOut(referenceDate, tankIds, nozzleIds, volumeDeciliters, cashCents)
        .send({
            from: accounts[0]
        });
}

async function productStock() {
    const referenceDate = document.getElementById("referenceDate").value;
    const table = document.getElementById("productStockTable").getElementsByTagName('tbody')[0];
    const rows = table.rows;

    let tankIds = [];
    let volumeDeciliters = [];

    for (let i = 0; i < rows.length; i++) {
        tankIds.push(parseInt(rows[i].cells[0].getElementsByTagName('input')[0].value));
        volumeDeciliters.push(parseInt(rows[i].cells[1].getElementsByTagName('input')[0].value));
    }

    const accounts = await web3.eth.getAccounts();
    await contract.methods.productStock(referenceDate, tankIds, volumeDeciliters)
        .send({
            from: accounts[0]
        });
}



function replacer(key, value) {
    if (typeof value === 'bigint') {
        return value.toString();
    } else {
        return value;
    }
}

async function audit() {
    console.log('function audit() called');
    const address = document.getElementById("audit_address").value;
    if (!web3.utils.isAddress(address)) {
        alert("Invalid address");
        return;
    }
    const rawData = await contract.methods.audit(address).call();
    const simplifiedOutput = simplifyData(rawData);
    console.log(simplifiedOutput);
    //document.getElementById("auditResult").textContent = JSON.stringify(simplifiedOutput, replacer, 2);
    // Populate tables with the simplified output
    populateTables(simplifiedOutput);
}

function simplifyData(originalData) {
    const simplifiedData = {};

    for (const key in originalData) {
        if (Array.isArray(originalData[key])) {
            simplifiedData[key] = originalData[key].map((item) => {
                const transformedItem = {};

                for (const prop in item) {
                    if (!isNaN(prop) || prop === "__length__") {
                        continue; // Skip indexed properties and "__length__"
                    }
                    transformedItem[prop] = item[prop];
                }

                return transformedItem;
            });
        } else {
            simplifiedData[key] = originalData[key];
        }
    }

    delete simplifiedData["__length__"]; // Remove "__length__" property if it exists at the top level

    return simplifiedData;
}

function populateTables(data) {
    const table1 = document.querySelector('#table1 tbody');
    const table2 = document.querySelector('#table2 tbody');
    const table3 = document.querySelector('#table3 tbody');

    table1.innerHTML = data["0"].map(item =>
        `<tr>
            <td>${item.referenceDate}</td>
            <td>${item.tankId}</td>
            <td>${item.volumeDeciliters}</td>
            <td>${item.cashCents}</td>
            <td>${item.productName}</td>
            <td>${item.invoiceXmlKey}</td>
        </tr>`
    ).join('');

    table2.innerHTML = data["1"].map(item =>
        `<tr>
            <td>${item.referenceDate}</td>
            <td>${item.tankId}</td>
            <td>${item.nozzleId}</td>
            <td>${item.volumeDeciliters}</td>
            <td>${item.cashCents}</td>
        </tr>`
    ).join('');

    table3.innerHTML = data["2"].map(item =>
        `<tr>
            <td>${item.referenceDate}</td>
            <td>${item.tankId}</td>
            <td>${item.volumeDeciliters}</td>
        </tr>`
    ).join('');
}