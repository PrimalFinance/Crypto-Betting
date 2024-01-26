async function depositToken0(contract, epoch, amount) {
    await contract.betToken0(epoch, amount);
}

async function depositToken1(contract, epoch, amount) {
    await contract.betToken1(epoch, amount);
}

module.exports = {
    depositToken0,
    depositToken1,
};
