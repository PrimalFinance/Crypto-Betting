const { getParams } = require('../utils/params.js');
const { ethers } = require('hardhat');

/**-------------------------------------------------- BettingPool Contract */
async function deployContract(
    _chainId,
    p = { symbol0: 'LINK', symbol1: 'MATIC', interval: 30 }
) {
    const params = await getParams(_chainId, p);
    const factory = await ethers.getContractFactory('BettingPool');
    const contract = await factory.deploy(
        params.admin,
        params.operator,
        params.token0,
        params.token1,
        params.priceFeed0,
        params.priceFeed1,
        params.interval,
        params.paymentToken
    );
    return contract;
}
/**-------------------------------------------------- Connect Contract */
async function connectContract(
    contractAddress = '0xEAEa45b8078f9fcA46DFb42b16016c8C234F7ff3 ', // This address is valid, assuming a fresh hardhat node, and MockERC was deployed *first*
    contractName = 'BettingPool'
) {
    const contractFactory = await ethers.getContractFactory(contractName);
    const contract = contractFactory.attach(contractAddress);
    return contract;
}

/**-------------------------------------------------- Mock ERC-20 Contract */
async function deployErc20(
    _minter = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'
) {
    const factory = await ethers.getContractFactory('MockToken');
    const contract = await factory.deploy({
        from: _minter,
    });
    return contract;
}

async function connectErc20(
    _address = '0xD86bc69b52508368622E4F9f8f70a603FFbFC89C'
) {
    const contractFactory = await ethers.getContractFactory('MockToken');
    const contract = contractFactory.attach(_address);
    return contract;
}

/**-------------------------------------------------- Factory Contract */
async function deployFactory() {
    const factory = await ethers.getContractFactory('BettingPoolFactory');
    const contract = await factory.deploy();
    return contract;
}

async function connectFactory(
    _address = '0xEAEa45b8078f9fcA46DFb42b16016c8C234F7ff3'
) {
    const factory = await ethers.getContractFactory('BettingPoolFactory');
    const contract = factory.attach(_address);
    return contract;
}

module.exports = {
    connectContract,
    connectErc20,
    connectFactory,
    deployContract,
    deployErc20,
    deployFactory,
};
