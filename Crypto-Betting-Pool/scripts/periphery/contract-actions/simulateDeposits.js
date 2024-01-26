const { getRandomNumber } = require('../utils/numberGeneration.js');

async function simulateEqualDeposits(
    wallets,
    poolContract,
    ercContract,
    depositAmount = '1'
) {
    const halfway = wallets.length / 2;
    const poolAddress = await poolContract.getAddress();
    const epoch = await poolContract.getCurrentEpoch();
    for (let i = 0; i < wallets.length; i++) {
        await ercContract.approve(poolAddress, depositAmount * 5, {
            from: wallets[i],
        });
        if (i < halfway) {
            await poolContract
                .connect(wallets[i])
                .betToken0(epoch, depositAmount);
        } else {
            await poolContract
                .connect(wallets[i])
                .betToken1(epoch, depositAmount);
        }
    }
}

module.exports = {
    simulateEqualDeposits,
};
