document.addEventListener('DOMContentLoaded', (event) => {
    const printButton = document.getElementById('printButton');
    printButton.addEventListener('click', function () {
        window.print();
    });
    console.log('add a visit to the visit log')
});