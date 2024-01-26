const { ethers } = require('hardhat');
const {
    connectContract,
    connectErc20,
    connectFactory,
} = require('./periphery/contract-actions/deployments.js');
const {
    simulateEqualDeposits,
} = require('./periphery/contract-actions/simulateDeposits.js');
const { getDataManager } = require('./periphery/utils/dataManager.js');
const { getWallet } = require('./periphery/utils/wallet.js');
const { Logger } = require('./periphery/utils/logging.js');

// Contract interactions.
const {
    depositToken0,
    depositToken1,
} = require('./periphery/contract-actions/deposits.js');

const contractAddress = '0xfe435387201d3327983d19293b60c1c014e61650';
const factoryAddress = '0xEAEa45b8078f9fcA46DFb42b16016c8C234F7ff3';
const mockTokenAddress = '0xe28a1b108b07c9cfa4636165ee7ca3927ee17797';

async function displayAllRounds(_contract) {
    const epoch = await _contract.getCurrentEpoch();
    const logger = new Logger(_contract);
    for (let i = 0; i <= epoch; i++) {
        logger.logFullRound(i);
    }
}
async function displayInformation(_contract) {
    const logger = new Logger(_contract);
    const epoch = await _contract.getCurrentEpoch();

    //logger.logRoundDeposits(epoch, true);
    logger.logRoundRewards(epoch - BigInt(1), true);
}

async function quickStart(params, chainId) {
    const dataManager = await getDataManager();
    const token0 = await dataManager.getTokenAddress(params.symbol0, chainId);
    const token1 = await dataManager.getTokenAddress(params.symbol1, chainId);
    const factory = await connectFactory(factoryAddress);
    const poolAddress = await factory.getPool(token0, token1, params.interval);
    const poolContract = await connectContract(poolAddress);
    return poolContract;
}

async function getBalance(wallet) {
    const minABI = [
        {
            constant: true,
            inputs: [{ name: '_owner', type: 'address' }],
            name: 'balanceOf',
            outputs: [{ name: 'balance', type: 'uint256' }],
            type: 'function',
        },
    ];
    const tokenContract = await connectErc20(mockTokenAddress);
    const balance = await tokenContract.methods
        .balanceOf(wallet.address)
        .call();
    return balance;
}

async function main() {
    const params = {
        symbol0: 'LINK',
        symbol1: 'MATIC',
        interval: 300,
    };
    const chainId = 137;
    const signers = await ethers.getSigners();
    const pool = await quickStart(params, chainId);
    const balance = await getBalance(signers[0]);
    console.log(`Balance: ${balance}`);
    const epoch = await pool.getCurrentEpoch();
    await pool.connect(signers[0]).betToken0(epoch, ethers.parseEther('1'));
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
