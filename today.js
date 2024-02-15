    // Function to format the date in YYYY-MM-DD
    function formatDate(date) {
        var d = new Date(date),
            month = '' + (d.getUTCMonth() + 1),
            day = '' + d.getUTCDate(),
            year = d.getUTCFullYear();

        if (month.length < 2) 
            month = '0' + month;
        if (day.length < 2) 
            day = '0' + day;

        return [year, month, day].join('-');
    }

    // Get today's date in GMT-3
    var today = new Date();
    today.setHours(today.getHours() - 3); // Adjust for GMT-3

    // Set the default value of the input field
    document.getElementById('referenceDate').value = formatDate(today);