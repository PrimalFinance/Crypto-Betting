const { ethers } = require('hardhat');

async function getWallet(index = 0) {
    const signers = await ethers.getSigners();
    return signers[index];
}

async function getSigners0() {
    return [
        await getWallet(0),
        await getWallet(1),
        await getWallet(2),
        await getWallet(3),
        await getWallet(4),
    ];
}

async function getSigners1() {
    return [
        await getWallet(5),
        await getWallet(6),
        await getWallet(7),
        await getWallet(8),
        await getWallet(9),
    ];
}

async function massDepositToken0(contract, epoch, amount) {
    const wallets = await getSigners0();

    for (let i = 0; i < wallets.length; i++) {
        console.log(`Wallet0: ${wallets[i]}`);
        await contract.connect(wallets[i]).betToken0(epoch, amount);
    }
}
async function massDepositToken1(contract, epoch, amount) {
    const wallets = await getSigners1();

    for (let i = 0; i < wallets.length; i++) {
        console.log(`Wallet1: ${wallets[i]}`);
        await contract.connect(wallets[i]).betToken1(epoch, amount);
    }
}
module.exports = {
    getWallet,
    massDepositToken0,
    massDepositToken1,
};
