// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

// Hardhat imports.
import 'hardhat/console.sol';

import './interfaces/IBettingPoolFactory.sol';
import './NoDelegateCall.sol';
import './BettingPoolV1.sol';

contract BettingPoolFactory is IBettingPoolFactory, NoDelegateCall {
    address public override owner;

    /// token0 address => token1 address => intervalSeconds => contract address.
    /// NOTE: Pairs are saved in both orders. So searching the mapping in either configuration (token0/token1 or token1/token0) will return the same contract address.
    mapping(address => mapping(address => mapping(uint256 => address)))
        public poolLedger;

    constructor() {
        owner = msg.sender;
        emit OwnerChanged(address(0), msg.sender);
    }

    function getPool(
        address _token0,
        address _token1,
        uint256 _intervalSeconds
    ) external view returns (address pool) {
        pool = poolLedger[_token0][_token1][_intervalSeconds];
    }

    function createPool(
        address _token0,
        address _token1,
        address _feed0,
        address _feed1,
        uint256 _intervalSeconds
    ) external override noDelegateCall returns (address pool) {
        require(_token0 != _token1);

        require(_token0 != address(0) || _token1 != address(0));
        require(poolLedger[_token0][_token1][_intervalSeconds] == address(0));
        BettingPool poolBetting = new BettingPool(
            owner,
            msg.sender,
            _token0,
            _token1,
            _feed0,
            _feed1,
            _intervalSeconds
        );

        console.log('--- Address ---', address(poolBetting));

        poolLedger[_token0][_token1][_intervalSeconds] = address(poolBetting);
        // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
        poolLedger[_token1][_token0][_intervalSeconds] = address(poolBetting);
        emit PoolCreated(
            owner,
            msg.sender,
            _token0,
            _token1,
            _intervalSeconds,
            pool
        );
    }

    function setOwner(address _owner) external override {
        require(msg.sender == owner);
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }
}
