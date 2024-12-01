document.addEventListener('DOMContentLoaded', async (event) => {
    const printButton = document.getElementById('printButton');
    printButton.addEventListener('click', function () {
        window.print();
    });
    console.log('add a visit to the visit log');

    // Function to get geolocation
    function getGeolocation() {
        return new Promise((resolve, reject) => {
            if (navigator.geolocation) {
                navigator.geolocation.getCurrentPosition(resolve, reject);
            } else {
                reject(new Error('Geolocation is not supported by this browser.'));
            }
        });
    }

    // Function to log visitor information
    async function logVisitorInfo() {
        const visitorInfo = {
            userAgent: navigator.userAgent,
            platform: navigator.platform,
            language: navigator.language,
            screenResolution: `${window.screen.width}x${window.screen.height}`,
            viewportSize: `${window.innerWidth}x${window.innerHeight}`,
            referrer: document.referrer,
            currentURL: window.location.href,
            timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone,
            connection: navigator.connection ? {
                effectiveType: navigator.connection.effectiveType,
                downlink: navigator.connection.downlink,
                rtt: navigator.connection.rtt
            } : 'Not available',
            geolocation: null
        };

        // Get geolocation
        try {
            const position = await getGeolocation();
            visitorInfo.geolocation = {
                latitude: position.coords.latitude,
                longitude: position.coords.longitude
            };
        } catch (error) {
            console.error('Error getting geolocation:', error);
        }

        return visitorInfo;
    }

    // Function to send visitor information to Azure Function
    async function sendVisitorInfo(visitorInfo) {
        try {
            const response = await fetch('https://<your-function-app-name>.azurewebsites.net/api/logVisitorInfo', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(visitorInfo)
            });
            if (response.ok) {
                console.log('Visitor information stored successfully.');
            } else {
                console.error('Error storing visitor information:', response.statusText);
            }
        } catch (error) {
            console.error('Error sending visitor information:', error);
        }
    }

    // Check for user consent
    var modal = document.getElementById("disclaimerModal");
    var span = document.getElementsByClassName("close")[0];
    var pageContainer = document.getElementsByClassName('pageContainer').item(0);
    const consentButton = document.getElementById('consentButton');
    const goBackButton = document.getElementById('goBackButton');

    modal.style.display = 'block';
    pageContainer.classList.add('blur');

    span.onclick = function () {
        modal.style.display = 'none';
    }

    consentButton.addEventListener('click', async function () {
        modal.style.display = 'none';
        // Log visitor information on page load
        const visitorInfo = await logVisitorInfo();

        // Send visitor information to Azure Function
        await sendVisitorInfo(visitorInfo);

        // Example: Log visitor information when a button is clicked
        console.log(visitorInfo);

        // Hide the consent button after consent is given
        consentButton.style.display = 'none';
        pageContainer.classList.remove('blur');
    });

    // go back button return to previous page
    goBackButton.addEventListener('click', function () {
        window.history.back();
    });
});