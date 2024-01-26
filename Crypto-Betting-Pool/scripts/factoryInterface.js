const { ethers } = require('hardhat');
const { getWallet } = require('./periphery/utils/wallet.js');

const { getDataManager } = require('./periphery/utils/dataManager.js');

const {
    connectFactory,
    deployErc20,
    deployFactory,
    connectContract,
} = require('./periphery/contract-actions/deployments.js');

const {
    Simulation,
} = require('./periphery/contract-actions/simulateRounds.js');

const factoryAddress = '0xEAEa45b8078f9fcA46DFb42b16016c8C234F7ff3';

class Factory {
    contract;
    deploy;
    chainId;
    constructor(_chainId = 137) {
        this.chainId = _chainId;
    }

    async setContract(
        _factoryAddress = '0xEAEa45b8078f9fcA46DFb42b16016c8C234F7ff3',
        _deploy = true
    ) {
        if (_deploy) {
            this.contract = await deployFactory();
        } else {
            this.contract = await connectFactory();
        }
    }

    async createPool(
        _params = { symbol0: 'LINK', symbol1: 'MATIC', interval: 300 }
    ) {
        console.log(`ChainId: ${this.chainId}`);
        const dataManager = await getDataManager();
        const token0 = await dataManager.getTokenAddress(
            _params.symbol0,
            this.chainId
        );
        const token1 = await dataManager.getTokenAddress(
            _params.symbol1,
            this.chainId
        );
        const feed0 = await dataManager.localData.getOraclePriceFeedAddress(
            _params.symbol0,
            'USD',
            this.chainId
        );
        const feed1 = await dataManager.localData.getOraclePriceFeedAddress(
            _params.symbol1,
            'USD',
            this.chainId
        );
        await this.contract.createPool(
            token0,
            token1,
            feed0,
            feed1,
            _params.interval
        );
    }

    async getPool(
        _params = { symbol0: 'LINK', symbol1: 'MATIC', interval: 300 }
    ) {
        const dataManager = await getDataManager();
        const token0 = await dataManager.getTokenAddress(
            _params.symbol0,
            this.chainId
        );
        const token1 = await dataManager.getTokenAddress(
            _params.symbol1,
            this.chainId
        );
        const poolAddress = await this.contract.getPool(
            token0,
            token1,
            _params.interval
        );
        return poolAddress;
    }
}

async function quickStart(params) {
    // =====================================
    // [Step 1] || Factory
    // =====================================
    // 1. Deploy factory contract.
    // 2. Create pool within factory.
    // 3. Store the address that the pool is deployed to.
    const factory = new Factory(137);
    await factory.setContract();
    await factory.createPool(params);
    const address = await factory.getPool(params);
    console.log(`Address: ${address}`);
    // =====================================
    // [Step 2] || Mint Payment Tokens
    // =====================================
    // 1. Get the wallets of the signers.
    // 2. Deploy token contract.
    // 3. Mint a quantity of tokens to each wallet.
    const signers = await ethers.getSigners();
    const erc20 = await deployErc20();
    for (let i = 0; i < signers.length; i++) {
        await erc20._mint(signers[i].address, ethers.parseEther('1000'));
    }
    // =====================================
    // [Step 3] || Round Simulation
    // =====================================
    // 1. Connect to pool contract.
    // 2. Start round simulation.
    const poolContract = await connectContract(address);
    const simulate = new Simulation(poolContract, params);
    await simulate.simulateFullRounds();
}

async function main() {
    const params = {
        symbol0: 'LINK',
        symbol1: 'MATIC',
        interval: 300,
    };
    await quickStart(params);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
