const { getParams } = require('../utils/params.js');

class Logger {
    contract;
    constructor(_contract) {
        this.contract = _contract;
    }
    // ------------------------------------------------------------- Deposits

    async logRoundDeposits(epoch, isolated = false, includeHeader = false) {
        const round = await this.contract.getRound(epoch);
        const deposits = round[6];
        if (includeHeader) {
            console.log(createHeader(epoch));
        }
        if (isolated) {
            console.log(`
[Deposits]
Token0: ${deposits[0]}
Token1: ${deposits[1]}
Total: ${deposits[2]}`);
        } else {
            return `
[Deposits]
Token0: ${deposits[0]}
Token1: ${deposits[1]}
Total: ${deposits[2]}`;
        }
    }
    // ------------------------------------------------------------- Rewards
    async logRoundRewards(epoch, isolated = false, includeHeader = false) {
        let round = await this.contract.getRound(epoch);
        if (includeHeader) {
            console.log(createHeader(epoch));
        }
        if (isolated) {
            console.log(`
[Rewards]
Reward Base Calc: ${round[7]}
Reward total: ${round[8]}`);
        } else {
            return `
[Rewards]
Reward Base Calc: ${round[7]}
Reward total: ${round[8]}`;
        }
    }
    // ------------------------------------------------------------- Token Data
    async logTokenData(epoch, isolated = false, includeHeader = false) {
        let tokenData = await this.contract.getRoundTokenData(epoch);
        if (includeHeader) {
            console.log(createHeader(epoch));
        }
        if (isolated) {
            console.log(`
[Token0]
Lock Price: ${tokenData[0][0]}
Close Price: ${tokenData[0][1]}
Performance: ${tokenData[0][2]}
        
[Token1]
Lock Price: ${tokenData[1][0]}
Close Price: ${tokenData[1][1]}
Performance: ${tokenData[1][2]}`);
        } else {
            return `
[Token0]
Lock Price: ${tokenData[0][0]}
Close Price: ${tokenData[0][1]}
Performance: ${tokenData[0][2]}
        
[Token1]
Lock Price: ${tokenData[1][0]}
Close Price: ${tokenData[1][1]}
Performance: ${tokenData[1][2]}`;
        }
    }
    // ------------------------------------------------------------- Timestamps
    async logTimestamps(epoch, isolated = false, includeHeaders = false) {
        let round = await this.contract.getRound(epoch);
        if (includeHeaders) {
            console.log(createHeader(epoch));
        }
        if (isolated) {
            console.log(`
[Timestamps]
Start: ${round[1]} 
Lock: ${round[2]} (${round[2] - round[1]} seconds)
End: ${round[3]} (${round[3] - round[2]} seconds)
        `);
        } else {
            return `
[Timestamps]
Start: ${round[1]} 
Lock: ${round[2]} (${round[2] - round[1]} seconds)
End: ${round[3]} (${round[3] - round[2]} seconds)
        `;
        }
    }
    // ------------------------------------------------------------- All Round
    async logFullRound(epoch, includeHeaders = false) {
        console.log(`
---------------------------------------------------------------------------------------------------
[Round ${epoch}]
-------------------
${await this.logTimestamps(epoch)}
        
${await this.logTokenData(epoch)}

${await this.logRoundDeposits(epoch)}

${await this.logRoundRewards(epoch)}
        `);
    }
    // ------------------------------------------------------------- Params
    async logParams(chainId, remix = true) {
        const params = await getParams(chainId);
        if (remix) {
            console.log(
                `${params.admin},${params.operator},${params.token0},${params.token1},${params.priceFeed0},${params.priceFeed1},${params.interval}`
            );
        } else {
            console.log(`${JSON.stringify(params, null, 2)}`);
        }
    }
}

function createHeader(epoch) {
    return `--------------\n-- Round ${epoch} --\n`;
}

module.exports = {
    Logger,
};
