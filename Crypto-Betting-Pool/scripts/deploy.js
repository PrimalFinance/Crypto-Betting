const { ethers } = require('hardhat');

const {
    connectContract,
    deployContract,
    deployErc20,
} = require('./periphery/contract-actions/deployments.js');
const {
    simulateGenesisRounds,
    simulateRounds,
    simulateRoundsBasic,
    simulateRoundsDeposits,
    simulateRoundsDepositsLoop,
    simulateGenesisRoundsLoop,
    simulateRoundsLoop,
} = require('./periphery/contract-actions/simulateRounds.js');

const contractAddress = '0xa004df2beef4ef4a58333b814a16c677c1df4e64';

async function quickDeploy() {
    /**
     * Deploys 'BettingPool' & 'MockERC20'.
     * NOTE: ERC20 contract must be deployed first.
     */
    const params = {
        symbol0: 'LINK',
        symbol1: 'MATIC',
        interval: 300,
    };

    const chainId = 137;
    const erc20 = await deployErc20();
    const contract = await deployContract(chainId, params);
    const signers = await ethers.getSigners();

    for (let i = 0; i < signers.length; i++) {
        await erc20.mint(signers[i].address, ethers.parseEther('1000'));
    }
    simulateGenesisRoundsLoop(contract, params);
}

async function main() {
    quickDeploy();
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
