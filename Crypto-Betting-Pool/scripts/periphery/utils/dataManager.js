const { DataManager } = require('D:/CryptoData/crypto-data/src/dataManager.js');

async function getDataManager() {
    return new DataManager();
}

module.exports = {
    getDataManager,
};
