const { logRoundData } = require('../utils/logging');

async function mockExecuteRound(contract) {
    const epoch = await contract.getCurrentEpoch();
    logRoundData(contract, epoch - BigInt(2));
    console.log(`Epoch: ${epoch}`);
    // await contract._safeLockRound(epoch);
    // await contract._safeEndRound(epoch - BigInt(1));
    // await contract._startRound(epoch + BigInt(1));
}

module.exports = {
    mockExecuteRound,
};
