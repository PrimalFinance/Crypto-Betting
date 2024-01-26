function getRandomNumber(min = 0.01, max = 10, leadingDecimals = 8) {
    return (Math.random() * (max - min) + min).toFixed(leadingDecimals);
}

function getRandomNumberList(
    numOfElements = 5,
    min = 0.01,
    max = 10,
    leadingDecimals = 8
) {
    let arr = [];
    for (let i = 0; i < numOfElements; i++) {
        arr.push(getRandomNumber(min, max, leadingDecimals));
    }
    return arr;
}

module.exports = {
    getRandomNumber,
    getRandomNumberList,
};
