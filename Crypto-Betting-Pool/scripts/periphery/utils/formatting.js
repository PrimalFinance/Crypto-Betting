function formatNumber(number, decimals = 8) {
    const denominator = 10 ** decimals;
    let formattedNumber = (Number(number) / denominator).toFixed(decimals);
    return formattedNumber;
}

function formatToWei(number, decimals = 8) {
    const num = 41665.13346449;
    let factor = Math.pow(10, decimals);
    return Math.round(number * factor);
}

// function sqrtToPrice(sqrt, decimals0, decimals1, token0IsInput = true)

module.exports = {
    formatNumber,
    formatToWei,
};
