// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

// Hardhat imports.
import 'hardhat/console.sol';

// Openzeppelin
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Pausable} from '@openzeppelin/contracts/utils/Pausable.sol';
import {ReentrancyGuard} from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';

// Chainlink imports
import '@chainlink/contracts/src/v0.8/interfaces/FeedRegistryInterface.sol';
import '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';
import '@chainlink/contracts/src/v0.8/Denominations.sol';

// Interfaces
import './interfaces/IBettingPool.sol';
import './interfaces/IBettingPoolFactory.sol';

contract BettingPool is Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    IERC20 public paymentToken =
        IERC20(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619); // WETH on Polygon.
    // Genisis round settings.
    bool public genesisLockOnce = false;
    bool public genesisStartOnce = false;
    // Pool adminAddress & operatorAddress.
    address public adminAddress;
    address public operatorAddress;
    // Pool token pair
    IERC20 public immutable token0;
    IERC20 public immutable token1;
    // Price feeds
    AggregatorV3Interface public immutable pool0;
    AggregatorV3Interface public immutable pool1;
    // Time settings of the pool.
    uint256 public intervalSeconds;
    uint256 public currentEpoch;
    uint256 public bufferSeconds = 20;
    uint256 public immutable MINIMUM_POOL_DURATION = 0;
    bool public simulateRounds = true;

    uint256 public minBetAmount; // minimum betting amount (denominated in wei)
    uint256 public treasuryFee; // treasury rate (e.g. 200 = 2%, 150 = 1.50%)
    uint256 public treasuryAmount; // treasury amount that was not claimed
    uint256 public oracleLatestRoundId0; // converted from uint80 (Chainlink)
    uint256 public oracleLatestRoundId1; // converted from uint80 (Chainlink)

    // Epoch =>
    mapping(uint256 => mapping(address => BetInfo)) public ledger;
    // Epoch => Round
    mapping(uint256 => Round) public rounds;
    // User address => Array of rounds participated.
    mapping(address => uint256[]) public userRounds;

    constructor(
        address _admin,
        address _operator,
        address _token0,
        address _token1,
        address _feed0,
        address _feed1,
        uint256 _intervalSeconds
    ) {
        require(
            _intervalSeconds >= MINIMUM_POOL_DURATION,
            'Contract constructor error. [Reason] Pool duration too small.'
        );
        adminAddress = _admin;
        operatorAddress = _operator;
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        pool0 = AggregatorV3Interface(_feed0);
        pool1 = AggregatorV3Interface(_feed1);
        intervalSeconds = _intervalSeconds;
    }

    // constructor() {
    //     (
    //         adminAddress,
    //         operatorAddress,
    //         token0,
    //         token1,
    //         intervalSeconds
    //     ) = IBettingPoolDeployer(msg.sender).parameters();

    //     pool0 = FeedRegistryInterface(_token0, Denominations.USD);
    //     pool1 = FeedRegistryInterface(_token1, Denominations.USD);
    // }

    /*----------------------------------------------------------------------------------
    /  Data Structures
    / ---------------------------------------------------------------------------------- */
    struct Round {
        uint256 epoch;
        uint256 startTimestamp;
        uint256 lockTimestamp;
        uint256 closeTimestamp;
        TokenOracleData token0Data;
        TokenOracleData token1Data;
        RoundDeposits roundDeposits;
        uint256 rewardBaseCalAmount;
        uint256 rewardAmount;
        bool oracleCalled;
    }
    struct RoundDeposits {
        uint256 token0Deposits;
        uint256 token1Deposits;
        uint256 totalDeposits;
    }
    struct TokenOracleData {
        int256 lockPrice;
        int256 closePrice;
        int256 performance;
        uint256 lockId;
        uint256 closeId;
    }
    struct BetInfo {
        Position position;
        uint256 amount;
        bool claimed; // default false
    }

    enum Position {
        Token0,
        Token1
    }

    /*----------------------------------------------------------------------------------
    /  Modifiers
    / ---------------------------------------------------------------------------------- */
    modifier onlyAdmin() {
        require(
            msg.sender == adminAddress,
            'Contract call restricted. [Reason] Not adminAddress.'
        );
        _;
    }
    modifier onlyAdminOrOperator() {
        require(
            msg.sender == adminAddress || msg.sender == operatorAddress,
            'Contract call restricted. [Reason] Not adminAddress or operatorAddress.'
        );
        _;
    }
    modifier onlyOperator() {
        require(
            msg.sender == operatorAddress,
            'Contract call restricted. [Reason] Not operatorAddress.'
        );
        _;
    }
    modifier notContract() {
        require(
            !_isContract(msg.sender),
            'Contract call restricted. [Reason] Origin caller is external contract.'
        );
        require(
            msg.sender == tx.origin,
            'Contract call restricted. [Reason] Origin caller does not match sender in txn.'
        );
        _;
    }

    /*----------------------------------------------------------------------------------
    /  Events
    / ---------------------------------------------------------------------------------- */
    event BetToken0(
        address indexed sender,
        uint256 indexed epoch,
        uint256 amount
    );
    event BetToken1(
        address indexed sender,
        uint256 indexed epoch,
        uint256 amount
    );
    event ClaimToken0(
        address indexed sender,
        uint256 indexed epoch,
        uint256 amount
    );
    event ClaimToken1(
        address indexed sender,
        uint256 indexed epoch,
        uint256 amount
    );
    event EndRound(
        uint256 indexed epoch,
        uint256 indexed token0RoundId,
        uint256 indexed token1RoundId,
        int256 token0Price,
        int256 token1Price,
        int256 token0Perfomance,
        int256 token1Performance
    );
    event LockRound(
        uint256 indexed epoch,
        uint256 indexed token0RoundId,
        uint256 indexed token1RoundId,
        int256 token0Price,
        int256 token1Price
    );
    event NewBufferAndIntervalSeconds(
        uint256 bufferSeconds,
        uint256 intervalSeconds
    );
    event NewMinBetAmount(uint256 indexed epoch, uint256 minBetAmount);
    event NewTreasuryFee(uint256 indexed epoch, uint256 treasuryFee);
    event NewOperatorAddress(address operatorAddress);
    event NewOracleUpdateAllowance(uint256 oracleUpdateAllowance);
    event Pause(uint256 indexed epoch);
    event RewardsCalculated(
        uint256 indexed epoch,
        uint256 rewardBaseCalAmount,
        uint256 rewardAmount,
        uint256 treasuryAmount
    );
    event StartRound(uint256 indexed epoch);
    event TokenRecovery(address indexed token, uint256 amount);
    event TreasuryClaim(uint256 amount);
    event Unpause(uint256 indexed epoch);

    /*----------------------------------------------------------------------------------
    /  Round Start/Stop
    / ---------------------------------------------------------------------------------- */
    function _safeStartRound(uint256 epoch) public {
        require(
            genesisStartOnce,
            'Unable to safeStart round. [Reason] Can only run after genesisStartRound is triggered.'
        );
        require(
            rounds[epoch - 2].closeTimestamp != 0,
            'Unable to safeStart round. [Reason] Can only start after round n-2 has ended'
        );
        require(
            block.timestamp >= rounds[epoch - 2].closeTimestamp,
            'Unable to safeStart round. [Reason] Can only start new round after round n-2 closeTimestamp.'
        );
        _startRound(epoch);
    }

    /**
     * @notice Start round
     * Previous round n-2 must end
     * @param epoch: epoch
     */
    function _startRound(uint256 epoch) internal {
        Round storage round = rounds[epoch];
        round.startTimestamp = block.timestamp;
        round.lockTimestamp = block.timestamp + intervalSeconds;
        round.closeTimestamp = block.timestamp + (2 * intervalSeconds);
        round.epoch = epoch;
        round.roundDeposits.totalDeposits = 0;
        emit StartRound(epoch);
    }

    /**
     * @notice Lock round.
     * @param _epoch: epoch of the round.
     * @param _roundId0: roundId for token0.
     * @param _roundId1: roundId for token1.
     * @param _price0: price of token0 in the round.
     * @param _price1: price of token1 in the round.
     */
    function _safeLockRound(
        uint256 _epoch,
        uint256 _roundId0,
        uint256 _roundId1,
        int256 _price0,
        int256 _price1
    ) public {
        require(
            rounds[_epoch].startTimestamp != 0,
            'Unable to lock pool. [Reason] Can only lock pool after round has started.'
        );
        require(
            block.timestamp >= rounds[_epoch].lockTimestamp,
            'Unable to lock pool. [Reason] Can only lock round after lockTimestamp.'
        );
        require(
            block.timestamp <= rounds[_epoch].lockTimestamp + bufferSeconds,
            'Unable to lock pool. [Reason] Can only lock round within bufferSeconds, after lockTimestamp.'
        );
        // Assign 'lock' data for round.
        Round storage round = rounds[_epoch];
        round.closeTimestamp = block.timestamp + intervalSeconds;
        round.token0Data.lockId = _roundId0;
        round.token0Data.lockPrice = _price0;
        round.token1Data.lockId = _roundId1;
        round.token1Data.lockPrice = _price1;
        emit LockRound(_epoch, _roundId0, _roundId1, _price0, _price1);
    }

    /**
     * @notice End round
     * @param _epoch: epoch
     * @param _roundId0: roundId for token0.
     * @param _roundId1: roundId for token1.
     * @param _price0: price of token0 in the round.
     * @param _price1: price of token1 in the round.
     */
    function _safeEndRound(
        uint256 _epoch,
        uint256 _roundId0,
        uint256 _roundId1,
        int256 _price0,
        int256 _price1
    ) public {
        require(
            rounds[_epoch].lockTimestamp != 0,
            'Unable to end round. [Reason] Can only end round after round has locked.'
        );
        require(
            block.timestamp >= rounds[_epoch].closeTimestamp,
            'Unable to end round. [Reason] Can only end round after closeTimestamp.'
        );
        require(
            block.timestamp <= rounds[_epoch].closeTimestamp + bufferSeconds,
            'Unable to end round. [Reason] Can only end round within bufferSeconds.'
        );
        uint256 decimals = 8;

        // Assign 'close' data for round.
        Round storage round = rounds[_epoch];
        int256 token0Performance = ((_price0 - round.token0Data.lockPrice) *
            int256(10 ** decimals)) / round.token0Data.lockPrice;
        int256 token1Performance = ((_price1 - round.token1Data.lockPrice) *
            int256(10 ** decimals)) / round.token1Data.lockPrice;
        round.token0Data.closeId = _roundId0;
        round.token0Data.closePrice = _price0;
        round.token0Data.performance = token0Performance;
        round.token1Data.closeId = _roundId1;
        round.token1Data.closePrice = _price1;
        round.token1Data.performance = token1Performance;
        round.oracleCalled = true;
        emit EndRound(
            _epoch,
            _roundId0,
            _roundId1,
            _price0,
            _price1,
            token0Performance,
            token1Performance
        );
    }

    /**
     * @notice Start the next round n, lock price for round n-1, end round n-2
     * @dev Callable by operator
     */
    function executeRound() external whenNotPaused onlyOperator {
        require(
            genesisStartOnce && genesisLockOnce,
            'Cannot execute round. [Reason] Can only run after genesisStartRound and genesisLockRound is triggered.'
        );
        console.log('-- Epoch --: ', currentEpoch);
        // Get prices.
        (uint80 roundId0, int256 price0) = _getToken0Price();
        (uint80 roundId1, int256 price1) = _getToken1Price();

        oracleLatestRoundId0 = uint256(roundId0);
        oracleLatestRoundId1 = uint256(roundId1);

        // CurrentEpoch refers to previous round (n-1)
        _safeLockRound(currentEpoch, roundId0, roundId1, price0, price1);
        _safeEndRound(currentEpoch - 1, roundId0, roundId1, price0, price1);
        _calculateRewards(currentEpoch - 1);

        // Increment currentEpoch to current round (n)
        currentEpoch = currentEpoch + 1;
        _safeStartRound(currentEpoch);
    }

    function executeRound2(
        int256 randPrice0,
        int256 randPrice1,
        uint256 id
    ) external {
        require(
            genesisStartOnce && genesisLockOnce,
            'Cannot execute round. [Reason] Can only run after genesisStartRound and genesisLockRound is triggered.'
        );
        // CurrentEpoch refers to previous round (n-1)
        _safeLockRound(currentEpoch, id, id, randPrice0, randPrice1);
        _safeEndRound(currentEpoch - 1, id, id, randPrice0, randPrice1);
        _calculateRewards(currentEpoch - 1);

        // Increment currentEpoch to current round (n)
        currentEpoch = currentEpoch + 1;
        _safeStartRound(currentEpoch);
    }

    function getRounds() public view returns (Round[] memory) {
        Round[] memory ret = new Round[](currentEpoch);
        for (uint i = 0; i < currentEpoch; i++) {
            ret[i] = rounds[i];
        }
        return ret;
    }

    /*----------------------------------------------------------------------------------
    /  Genesis Rounds
    / ---------------------------------------------------------------------------------- */
    /**
     * @notice Start genesis round
     * @dev Callable by admin or operator
     */
    function genesisStartRound() external whenNotPaused onlyOperator {
        require(
            !genesisStartOnce,
            'Unable to start genesis round. [Reason] Can only run genesisStartRound once.'
        );

        rounds[currentEpoch].startTimestamp = block.timestamp;
        rounds[currentEpoch].lockTimestamp = block.timestamp;
        rounds[currentEpoch].closeTimestamp = block.timestamp;
        currentEpoch = currentEpoch + 1;
        _startRound(currentEpoch);
        genesisStartOnce = true;
    }

    /**
     * @notice Lock genesis round
     * @dev Callable by operator
     */
    function genesisLockRound() external whenNotPaused onlyOperator {
        require(
            genesisStartOnce,
            'Unable to lock genesis round. [Reason] Can only run after genesisStartRound is triggered.'
        );
        require(
            !genesisLockOnce,
            'Unable to lock genesis round. [Reason] Can only run genesisLockRound once'
        );

        (uint80 roundId0, int256 price0) = _getToken0Price();
        (uint80 roundId1, int256 price1) = _getToken1Price();

        oracleLatestRoundId0 = uint256(roundId0);
        oracleLatestRoundId1 = uint256(roundId1);

        _safeLockRound(currentEpoch, roundId0, roundId1, price0, price1);
        currentEpoch = currentEpoch + 1;
        _startRound(currentEpoch);
        genesisLockOnce = true;
    }

    /*----------------------------------------------------------------------------------
    /  Token Betting
    / ---------------------------------------------------------------------------------- */
    function betToken0(uint256 _epoch, uint256 _amount) public payable {
        require(
            _epoch == currentEpoch,
            "Unable to bet token0. [Reason] Parameter '_epoch' does not match 'currentEpoch'."
        );
        require(
            ledger[_epoch][msg.sender].amount == 0,
            'Unable to bet token0. [Reason] Already placed a bet.'
        );
        require(
            _bettable(_epoch),
            'Unable to bet token0. [Reason] Pool is not bettable.'
        );
        require(
            _amount > 0,
            'Unable to bet token0. [Reason] Amount placed must be greater than 0.'
        );
        //Transfer payment token from user to contract.
        paymentToken.safeTransferFrom(msg.sender, address(this), _amount);
        // Update round data.
        Round storage round = rounds[_epoch];
        round.roundDeposits.token0Deposits += _amount;
        round.roundDeposits.totalDeposits += _amount;
        // Update user data.
        BetInfo storage betInfo = ledger[_epoch][msg.sender];
        betInfo.position = Position.Token0;
        betInfo.amount += _amount;
        userRounds[msg.sender].push(_epoch);
        // Emit bet information.
        emit BetToken0(msg.sender, _epoch, _amount);
    }

    function betToken1(uint256 _epoch, uint256 _amount) public payable {
        require(
            _epoch == currentEpoch,
            "Unable to bet token0. [Reason] Parameter '_epoch' does not match 'currentEpoch'."
        );
        require(
            ledger[_epoch][msg.sender].amount == 0,
            'Unable to bet token0. [Reason] Already placed a bet.'
        );
        require(
            _bettable(_epoch),
            'Unable to bet token0. [Reason] Pool is not bettable.'
        );
        require(
            _amount > 0,
            'Unable to bet token0. [Reason] Amount placed must be greater than 0.'
        );
        //Transfer payment token from user to contract.
        paymentToken.safeTransferFrom(msg.sender, address(this), _amount);
        // Update round data.
        Round storage round = rounds[_epoch];
        round.roundDeposits.token1Deposits += _amount;
        round.roundDeposits.totalDeposits += _amount;
        // Update user data.
        BetInfo storage betInfo = ledger[_epoch][msg.sender];
        betInfo.position = Position.Token1;
        betInfo.amount += _amount;
        userRounds[msg.sender].push(_epoch);
        // Emit bet information.
        emit BetToken1(msg.sender, _epoch, _amount);
    }

    /*----------------------------------------------------------------------------------
    /  Token Prices
    / ---------------------------------------------------------------------------------- */
    /**
     * @notice Get the latest price of token0.
     * return: Round Id and Price form oracle price feed.
     */
    function _getToken0Price() public view returns (uint80, int256) {
        (uint80 roundId, int256 price, , , ) = pool0.latestRoundData();
        return (roundId, price);
    }

    /**
     * @notice Get the latest price of token1.
     * return: Round Id and Price form oracle price feed.
     */
    function _getToken1Price() public view returns (uint80, int256) {
        (uint80 roundId, int256 price, , , ) = pool1.latestRoundData();
        return (roundId, price);
    }

    /**
     *
     * @notice Calculate the tokens performance from the lock price and close price.
     * @param epoch: Epoch of the round to return data for.
     * return: The % performance of token
     */
    function _getToken0Performance(uint256 epoch) public view returns (int256) {
        /**TODO Get decimal from price feed rather than manually setting it.  */
        uint256 decimals = 8;
        int256 startPrice = rounds[epoch].token0Data.lockPrice;
        int256 closePrice = rounds[epoch].token0Data.closePrice;
        int performance = ((closePrice - startPrice) * int256(10 ** decimals)) /
            startPrice;
        return performance;
    }

    function _getToken1Performance(uint256 epoch) public view returns (int256) {
        uint256 decimals = 8;
        int256 startPrice = rounds[epoch].token1Data.lockPrice;
        int256 closePrice = rounds[epoch].token1Data.closePrice;
        int performance = ((closePrice - startPrice) * int256(10 ** decimals)) /
            startPrice;
        return performance;
    }

    /*----------------------------------------------------------------------------------
    /  Get State Variables
    / ---------------------------------------------------------------------------------- */
    function getCurrentEpoch() public view returns (uint256) {
        return currentEpoch;
    }

    function getRound(uint256 epoch) public view returns (Round memory) {
        return rounds[epoch];
    }

    function getRoundTokenData(
        uint256 epoch
    ) public view returns (TokenOracleData memory, TokenOracleData memory) {
        return (rounds[epoch].token0Data, rounds[epoch].token1Data);
    }

    function getBlockTimestamp() public view returns (uint256) {
        return block.timestamp;
    }

    function getToken0() public view returns (address) {
        return address(token0);
    }

    function getToken1() public view returns (address) {
        return address(token1);
    }

    /*----------------------------------------------------------------------------------
    /  Rewards
    / ---------------------------------------------------------------------------------- */
    /**
     * @notice Calculate rewards for round
     * @param epoch: epoch
     */
    function _calculateRewards(uint256 epoch) internal {
        require(
            rounds[epoch].rewardBaseCalAmount == 0 &&
                rounds[epoch].rewardAmount == 0,
            'Rewards already calculated'
        );
        Round storage round = rounds[epoch];
        uint256 rewardBaseCalAmount;
        uint256 treasuryAmt;
        uint256 rewardAmount;

        // Token0 wins
        if (round.token0Data.performance > round.token1Data.performance) {
            rewardBaseCalAmount = round.roundDeposits.token0Deposits;
            treasuryAmt =
                (round.roundDeposits.totalDeposits * treasuryFee) /
                10000;
            rewardAmount = round.roundDeposits.totalDeposits - treasuryAmt;
        }
        // Token1 wins
        else if (round.token0Data.performance < round.token1Data.performance) {
            rewardBaseCalAmount = round.roundDeposits.token1Deposits;
            treasuryAmt =
                (round.roundDeposits.totalDeposits * treasuryFee) /
                10000;
            rewardAmount = round.roundDeposits.token0Deposits - treasuryAmt;
        }
        // Token0 & Token1 performance are tied.
        else {
            rewardBaseCalAmount = 0;
            rewardAmount = 0;
            treasuryAmt = 0;
        }
        round.rewardBaseCalAmount = rewardBaseCalAmount;
        round.rewardAmount = rewardAmount;

        // Add to the treasury.
        treasuryAmount += treasuryAmt;
        emit RewardsCalculated(
            epoch,
            rewardBaseCalAmount,
            rewardAmount,
            treasuryAmount
        );
    }

    /*----------------------------------------------------------------------------------
    /  Claims
    / ---------------------------------------------------------------------------------- */
    function claim(
        uint256[] calldata epochs
    ) external nonReentrant notContract {
        uint256 token0Reward; // Initialize reward for token0
        uint256 token1Reward; // Initialize reward for token0
        for (uint256 i = 0; i < epochs.length; i++) {
            require(
                rounds[epochs[i]].startTimestamp != 0,
                'Round has not started'
            );
            require(
                block.timestamp > rounds[epochs[i]].closeTimestamp,
                'Round has not ended'
            );

            uint256 token0AddedReward = 0;
            uint256 token1AddedReward = 0;
            // Round valid, claim rewards.
            if (rounds[epochs[i]].oracleCalled) {
                // Check if the user bet on token 0.
                if (ledger[epochs[i]][msg.sender].position == Position.Token0) {
                    // Check if the epoch is claimable for token0.
                    require(
                        token0Claimable(epochs[i], msg.sender),
                        'Not eligible for claim of token0.'
                    );
                    Round memory round = rounds[epochs[i]];
                    token0AddedReward =
                        (ledger[epochs[i]][msg.sender].amount *
                            round.rewardAmount) /
                        round.rewardBaseCalAmount;
                } else {
                    // Check if the epoch is claimable for token1.
                    require(
                        token1Claimable(epochs[i], msg.sender),
                        'Not eligible for claim of token1.'
                    );
                    Round memory round = rounds[epochs[i]];
                    token1AddedReward =
                        (ledger[epochs[i]][msg.sender].amount *
                            round.rewardAmount) /
                        round.rewardBaseCalAmount;
                }
            }
            // Round invalid, refund bet amount.
            else {
                // Check if the user bet on token0.
                if (ledger[epochs[i]][msg.sender].position == Position.Token0) {
                    require(
                        token0Refundable(epochs[i], msg.sender),
                        'Not eligble for refund of token0.'
                    );
                    Round memory round = rounds[epochs[i]];
                    token0AddedReward = ledger[epochs[i]][msg.sender].amount;
                } else {
                    require(
                        token0Refundable(epochs[i], msg.sender),
                        'Not eligble for refund of token1.'
                    );
                    Round memory round = rounds[epochs[i]];
                    token1AddedReward = ledger[epochs[i]][msg.sender].amount;
                }
            }

            ledger[epochs[i]][msg.sender].claimed = true; // Set claimed for the epoch to true.
            token0Reward += token0AddedReward;
            token1Reward += token1AddedReward;
            emit ClaimToken0(msg.sender, epochs[i], token0AddedReward);
            emit ClaimToken1(msg.sender, epochs[i], token1AddedReward);
        }

        // If any rewards in token0, transfer to user.
        if (token0Reward > 0) {
            token0.safeTransfer(msg.sender, token0Reward);
        }
        // If any rewards in token1, transfer to user.
        if (token1Reward > 0) {
            token1.safeTransfer(msg.sender, token1Reward);
        }
    }

    /**
     * @notice Get the claimable stats of specific epoch and user account for token0.
     * @param epoch: epoch
     * @param user: user address
     */
    function token0Claimable(
        uint256 epoch,
        address user
    ) public view returns (bool) {
        BetInfo memory betInfo = ledger[epoch][user];
        Round memory round = rounds[epoch];
        // Calculate the performance of the tokens in the round.
        int256 token0Performance = (round.token0Data.closePrice -
            round.token0Data.lockPrice) / round.token0Data.lockPrice;
        int256 token1Performance = (round.token1Data.closePrice -
            round.token1Data.lockPrice) / round.token1Data.lockPrice;
        if (token0Performance == token1Performance) {
            return false;
        }
        // If all conditions below are met, return true.
        return
            round.oracleCalled && // True if the oracle was called for the round.
            betInfo.amount != 0 && // True if greater than 0.
            !betInfo.claimed && // True if claimed is 'false'.
            (token0Performance > token1Performance &&
                betInfo.position == Position.Token0); // True if token0 performs better, and the user betted on token0.
    }

    /**
     * @notice Get the claimable stats of specific epoch and user account for token1.
     * @param epoch: epoch
     * @param user: user address
     */
    function token1Claimable(
        uint256 epoch,
        address user
    ) public view returns (bool) {
        BetInfo memory betInfo = ledger[epoch][user];
        Round memory round = rounds[epoch];
        // Calculate the performance of the tokens in the round.
        int256 token0Performance = round.token0Data.performance;
        int256 token1Performance = round.token1Data.performance;
        if (token0Performance == token1Performance) {
            return false;
        }
        // If all conditions below are met, return true.
        return
            round.oracleCalled && // True if the oracle was called for the round.
            betInfo.amount != 0 && // True if greater than 0.
            !betInfo.claimed && // True if claimed is 'false'.
            (token0Performance < token1Performance &&
                betInfo.position == Position.Token1); // True if token1 performs better, and the user betted on token0.
    }

    /*----------------------------------------------------------------------------------
    /  Refunds
    / ---------------------------------------------------------------------------------- */
    /**
     * @notice Check if the token0 is refundable in the epoch for the user.
     * @param epoch: Epoch of the round.
     * @param user: Address of the user.
     * @return Boolean if token0 is refundable in the epoch.
     */

    function token0Refundable(
        uint256 epoch,
        address user
    ) public view returns (bool) {
        BetInfo memory betInfo = ledger[epoch][user];
        Round memory round = rounds[epoch];
        return
            !round.oracleCalled &&
            !betInfo.claimed &&
            block.timestamp > round.closeTimestamp + bufferSeconds &&
            betInfo.amount != 0 &&
            betInfo.position == Position.Token0;
    }

    /**
     * @notice Check if the token1 is refundable in the epoch for the user.
     * @param epoch: Epoch of the round.
     * @param user: Address of the user.
     * @return Boolean if token1 is refundable in the epoch.
     */
    function token1Refundable(
        uint256 epoch,
        address user
    ) public view returns (bool) {
        BetInfo memory betInfo = ledger[epoch][user];
        Round memory round = rounds[epoch];
        return
            !round.oracleCalled &&
            !betInfo.claimed &&
            block.timestamp > round.closeTimestamp + bufferSeconds &&
            betInfo.amount != 0 &&
            betInfo.position == Position.Token1;
    }

    /**--------------------------------------------- X ---------------------------------------------*/
    /**
     * @dev
     * @notice
     * @param
     * @param
     */

    /*----------------------------------------------------------------------------------
    /  Utilities
    / ---------------------------------------------------------------------------------- */
    /**
     * @dev
     * @notice
     * @param
     * @param
     */
    function _bettable(uint256 epoch) internal view returns (bool) {
        return
            rounds[epoch].startTimestamp != 0 &&
            rounds[epoch].lockTimestamp != 0 &&
            block.timestamp > rounds[epoch].startTimestamp &&
            block.timestamp < rounds[epoch].lockTimestamp;
    }

    /**
     * @notice Returns true if `account` is a contract.
     * @param account: account address
     */
    function _isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @notice It allows the owner to recover tokens sent to the contract by mistake
     * @param _token: token address
     * @param _amount: token amount
     * @dev Callable by owner
     */
    function recoverToken(address _token, uint256 _amount) external onlyAdmin {
        require(
            _token != address(token0) || _token != address(token1),
            'Cannot recover token. [Reason] Cannot be prediction token.'
        );
        IERC20(_token).safeTransfer(address(msg.sender), _amount);

        emit TokenRecovery(_token, _amount);
    }
}

/**
[Directory]
--------------------------
- Data Structures
- Modifiers
- Events
- Round Start/Stop
- Genisis Rounds
- Token Betting
- Token Prices
- Get State Variables
- Rewards
- Claims
- Refunds
- Utilities
-  */
