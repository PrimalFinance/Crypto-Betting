const { ethers } = require('hardhat');
const { Logger } = require('../utils/logging.js');
const { formatNumber, formatToWei } = require('../utils/formatting.js');
const { getRandomNumber } = require('../utils/numberGeneration.js');
const { sleep } = require('../utils/time.js');
const {
    getWallet,
    massDepositToken0,
    massDepositToken1,
} = require('../utils/wallet.js');
const { mockExecuteRound } = require('../contract-actions/psuedoOperations.js');

class Simulation {
    contract;
    params;
    sleepInterval;
    logger;
    constructor(_contract, _params) {
        this.contract = _contract;
        this.params = _params;
        this.sleepInterval = _params.interval;
        this.logger = new Logger(_contract);
    }

    /**
     * Simulate only the genesis rounds.
     */
    async simulateGenesisRounds() {
        await this.contract.genesisStartRound();
        await sleep(this.sleepInterval);
        await this.contract.genesisLockRound();
    }

    /**
     * Simulate rounds *without* genesis rounds.
     */
    async simulateRoundsBasic() {
        let epoch = await this.contract.getCurrentEpoch();
        //----------------------------------- Start Round
        await this.contract.startRound();
        console.log('---------------------------------------\n[Start Round]');
        this.logger.logTokenData(epoch);
        await sleep(this.sleepInterval);
        //----------------------------------- Lock Round
        await this.contract.lockRound();
        console.log('---------------------------------------\n[Lock Round]');
        this.logger.logTokenData(contract, epoch);
        await sleep(this.sleepInterval);
        //----------------------------------- End Round
        await this.contract.endRound();
        console.log('---------------------------------------\n[End Round]');
        this.logger.logTokenData(epoch);
    }
    /**
     * Simulate rounds *without* genesis rounds. And have 2 wallets bet on each side of the pool.
     */

    async simulateRoundsDeposits() {
        let epoch = await this.contract.getCurrentEpoch();
        const wallet0 = await getWallet(0);
        const wallet1 = await getWallet(1);
        //----------------------------------- Start Round
        await this.contract._startRound(epoch);
        console.log(
            `---------------------------------------\n[Start Round ${epoch}]`
        );
        logRoundData(this.contract, epoch);
        await this.contract.connect(wallet0).betToken0(epoch, {
            value: ethers.parseEther('1'),
        });
        await this.contract.connect(wallet1).betToken1(epoch, {
            value: ethers.parseEther('1'),
        });
        await sleep(this.sleepInterval);
        //----------------------------------- Lock Round
        await this.contract._lockRound(epoch);
        console.log(
            `---------------------------------------\n[Lock Round ${epoch}]`
        );
        this.logger.logRoundData(epoch);
        await sleep(this.sleepInterval);
        //----------------------------------- End Round
        await this.contract._endRound(epoch);
        console.log(
            `---------------------------------------\n[End Round ${epoch}]`
        );
        this.logger.logRoundData(epoch);
    }

    /**
     * Simulate rounds *with* genesis rounds. And main rounds.
     */
    async simulateFullRounds() {
        let loopControl = true;
        await this.contract.genesisStartRound();
        await sleep(this.sleepInterval);
        await this.contract.genesisLockRound();
        await sleep(this.sleepInterval);
        while (loopControl) {
            const randPrice0 = formatToWei(getRandomNumber());
            const randPrice1 = formatToWei(getRandomNumber());
            const randId = formatToWei(getRandomNumber());
            // this.logger.logTimestamps(
            //     await this.contract.getCurrentEpoch(),
            //     true
            // );
            await this.contract.executeRound2(randPrice0, randPrice1, randId);
            await sleep(this.sleepInterval);
        }

        // for (let i = 0; i < 10; i++) {
        //     logger.logFullRound(i);
        // }
    }

    async simulateRounds(numRounds = 5) {
        let epoch;
        let index = 0;
        await this.contract.genesisStartRound();
        await sleep(this.sleepInterval);
        await this.contract.genesisLockRound();
        await sleep(this.sleepInterval);

        while (index <= numRounds) {
            epoch = await this.contract.getCurrentEpoch();
            const randPrice0 = formatToWei(getRandomNumber());
            const randPrice1 = formatToWei(getRandomNumber());
            const randId = formatToWei(getRandomNumber());

            await this.contract.executeRound2(randPrice0, randPrice1, randId);
            epoch = await this.contract.getCurrentEpoch();
            await massDepositToken0(
                this.contract,
                epoch,
                ethers.parseEther('1')
            );
            await massDepositToken1(
                this.contract,
                epoch,
                ethers.parseEther('3')
            );
            await sleep(this.sleepInterval);
            index += 1;
        }

        for (let i = 0; i < 10; i++) {
            logger.logFullRound(i);
        }
    }
}

async function simulateGenesisRoundsLoop(
    contract,
    p = { symbol0: 'LINK', symbol1: 'MATIC', interval: 30 }
) {
    const loopControl = true;
    let epoch;
    const sleepInterval = p.interval;

    await contract.genesisStartRound();
    await sleep(sleepInterval);
    await contract.genesisLockRound();
    await sleep(sleepInterval);
    while (loopControl) {
        epoch = await contract.getCurrentEpoch();
        console.log(`-- Round ${epoch} --`);
        const rand1 = formatToWei(getRandomNumber());
        const rand2 = formatToWei(getRandomNumber());
        const rand3 = formatToWei(getRandomNumber());
        await contract.executeRound2(rand1, rand2, rand3);
        await sleep(sleepInterval);
    }
}

/**
Troubleshooting. 
- Error caused by "_safeStartRound()". 
 */

module.exports = {
    Simulation,
};
