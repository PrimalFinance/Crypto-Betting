const { getWallet } = require('../utils/wallet.js');
const { getDataManager } = require('../utils/dataManager.js');

/**-------------------------------------------------- Param Creation */
async function getParams(
    _chainId,
    p = { symbol0: 'LINK', symbol1: 'MATIC', interval: 30 }
) {
    const dataManager = await getDataManager();
    const wallet = getWallet();
    const walletAddress = await (await wallet).getAddress();
    // Get token addresses for token args.
    const token0 = await dataManager.getTokenAddress(p.symbol0, _chainId);
    const token1 = await dataManager.getTokenAddress(p.symbol1, _chainId);

    // Get price-feed addresses for price-feed args.
    const priceFeed0 = await dataManager.localData.getOraclePriceFeedAddress(
        p.symbol0,
        'USD',
        _chainId
    );
    const priceFeed1 = await dataManager.localData.getOraclePriceFeedAddress(
        p.symbol1,
        'USD',
        _chainId
    );

    const params = {
        admin: walletAddress,
        operator: walletAddress,
        token0: token0,
        token1: token1,
        priceFeed0: priceFeed0,
        priceFeed1: priceFeed1,
        interval: p.interval,
        paymentToken: '0xfe435387201d3327983d19293b60c1c014e61650',
    };
    return params;
}

module.exports = {
    getParams,
};
