// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import "./MetaNodeToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol"; // Safe handling ERC20

import "@openzeppelin/contracts/utils/math/Math.sol";

// TODO: Organize notes to natspec

contract MetaNodeStake is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable
{
    // Roles, constants
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Types

    struct Pool {
        address stakeToken;
        uint256 poolWeight;
        uint256 totalSupply;
        uint256 rewardPerTokenStored;
        uint256 lastUpdateBlock;
        uint256 minTokenLock;
        uint256 lockPeriod;
    }

    struct UserRecord {
        uint256 stakedAmount;
        uint256 rewardPerTokenPaid;
        uint256 rewardsEarned;
        WithdrawRequest[] WithdrawRequests;
    }

    struct WithdrawRequest {
        uint256 amount;
        uint256 unlockBlock;
    }

    // States
    MetaNodeToken public metaNodeToken;

    bool private _claimPaused;
    bool private _withdrawPaused;

    uint256 public startBlock;
    uint256 public endBlock;
    uint256 public rewardRate;
    uint256 public totalWeight;

    Pool[] public pools;

    // Storing user staked
    mapping(uint256 => mapping(address => UserRecord)) public userLedger;

    // Events
    event TokenSet(address indexed curr);

    event StartBlockSet(uint256 indexed value, address indexed by);
    event EndBlockSet(uint256 indexed value, address indexed by);
    event RewardPerBlockSet(uint256 indexed value, address indexed by);

    event ClaimPaused(uint256 indexed blockNum, address indexed operator);
    event ClaimUnpaused(uint256 indexed blockNum, address indexed operator);
    event WithdrawPaused(uint256 indexed blockNum, address indexed operator);
    event WithdrawUnpaused(uint256 indexed blockNum, address indexed operator);

    // Errors
    error InvalidWindow(uint256 start, uint256 end);
    error InvalidRewardAmount(uint256 rewardPerBlock);
    error InvalidMintAmount(uint256 mindAmount);
    error RewardSeasonActive();
    error InvalidRewardRate();

    error ClaimAlreadyPaused();
    error ClaimNotPausedYet();

    error WithdrawAlreadyPaused();
    error WithdrawNotPausedYet();

    // Modifiers
    modifier claimNotPaused() {
        if (_claimPaused) {
            revert ClaimAlreadyPaused();
        }
        _;
    }

    modifier claimPaused() {
        if (!_claimPaused) {
            revert ClaimNotPausedYet();
        }
        _;
    }

    modifier withdrawNotPaused() {
        if (_withdrawPaused) {
            revert WithdrawAlreadyPaused();
        }
        _;
    }

    modifier withdrawPaused() {
        if (!_withdrawPaused) {
            revert WithdrawNotPausedYet();
        }
        _;
    }

    modifier validWindow(uint256 _startBlock, uint256 _endBlock) {
        if (_startBlock > _endBlock) {
            revert InvalidWindow(_startBlock, _endBlock);
        }
        if (block.number >= startBlock) {
            revert RewardSeasonActive();
        }
        _;
    }

    /**
     * Made a modifier, will be fired by any actions that changes rewardRate: reward amount change, user stake/withdraw
     */
    modifier updatesRewardRate(uint256 _pId, address _user) {
        if (_pId != 0) {
            // Triggered by user stake/withdraw
            Pool storage pool_ = pools[_pId];
            pool_.rewardPerTokenStored = getRewardPerToken(_pId); // Calculate rj
            pool_.lastUpdateBlock = getLastValidRewardBlock(); // Update blocknum

            UserRecord storage userLedger_ = userLedger[_pId][_user];
            userLedger_.rewardsEarned = earnedReward(_pId, _user); // Update reward
            userLedger_.rewardPerTokenPaid = pool_.rewardPerTokenStored; // Record this rj
        } else {
            // Bulk update pools using for loop
            for (uint i = 0; i < pools.length; i++) {
                Pool storage pool_ = pools[i];
                pool_.rewardPerTokenStored = getRewardPerToken(i); // Calculate rj
                pool_.lastUpdateBlock = getLastValidRewardBlock(); // Update blocknum
            }
        }

        _;
    }

    constructor() {
        _disableInitializers();
    }

    /**
     * Public functions
     */

    function initialize(
        address _defaultAdmin,
        address _pauser,
        address _upgrader,
        address _rewardToken,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _rewardRate
    ) public initializer {
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        _grantRole(ADMIN_ROLE, _defaultAdmin);
        _grantRole(PAUSER_ROLE, _pauser);
        _grantRole(UPGRADER_ROLE, _upgrader);

        metaNodeToken = MetaNodeToken(_rewardToken);
        emit TokenSet(_rewardToken);

        startBlock = _startBlock;
        emit StartBlockSet(_startBlock, msg.sender);
        endBlock = _endBlock;
        emit EndBlockSet(_endBlock, msg.sender);
        _rewardRate = _rewardRate;
        emit RewardPerBlockSet(_rewardRate, msg.sender);
    }

    // Admin funcs

    function pauseClaim() public onlyRole(PAUSER_ROLE) claimNotPaused {
        _claimPaused = true;

        emit ClaimPaused(block.number, msg.sender);
    }

    function unpauseClaim() public onlyRole(PAUSER_ROLE) claimPaused {
        _claimPaused = false;

        emit ClaimUnpaused(block.number, msg.sender);
    }

    function pauseWithdraw() public onlyRole(PAUSER_ROLE) withdrawNotPaused {
        _withdrawPaused = true;

        emit WithdrawPaused(block.number, msg.sender);
    }

    function unpauseWithdraw() public onlyRole(PAUSER_ROLE) withdrawPaused {
        _withdrawPaused = false;

        emit WithdrawUnpaused(block.number, msg.sender);
    }

    function setMetaNodeToken(address _token) public onlyRole(ADMIN_ROLE) {
        metaNodeToken = MetaNodeToken(_token);

        emit TokenSet(_token);
    }

    // Configure season
    function setStartBlock(
        uint256 _startBlock
    ) public onlyRole(ADMIN_ROLE) validWindow(_startBlock, endBlock) {
        startBlock = _startBlock;
        emit StartBlockSet(_startBlock, msg.sender);
    }

    function setEndBlock(
        uint256 _endBlock
    ) public onlyRole(ADMIN_ROLE) validWindow(startBlock, _endBlock) {
        endBlock = _endBlock;
        emit StartBlockSet(_endBlock, msg.sender);
    }

    function getLastValidRewardBlock() public view returns (uint256 lastValidRewardBlock) {
        lastValidRewardBlock = _min(block.number, endBlock);
    }

    function getWeightedRewardRate(uint256 _pId) public view returns (uint256) {
        // Calculates `R` based on pool weight
        Pool memory pool = pools[_pId];
        return rewardRate * (pool.poolWeight / totalWeight);
    }

    function getRewardPerToken(uint256 _pId) public view returns (uint256) {
        // Calculating rj

        Pool memory pool = pools[_pId];
        if (pool.totalSupply == 0) {
            return pool.rewardPerTokenStored;
        }

        return
            pool.rewardPerTokenStored +
            (getWeightedRewardRate(_pId) / pool.totalSupply) *
            (getLastValidRewardBlock() - pool.lastUpdateBlock) *
            1e18;
    }

    function earnedReward(uint256 _pId, address _user) public view returns (uint256) {
        // Calculation of reward: see math note
        UserRecord memory userRecord = userLedger[_pId][_user];
        return (userRecord.stakedAmount *
            (getRewardPerToken(_pId) - userRecord.rewardPerTokenPaid) +
            userRecord.rewardsEarned /
            1e18);
    }

    /**
     * External functions
     */

    function setTotalReward(
        uint256 _amount
    ) external onlyRole(ADMIN_ROLE) updatesRewardRate(0, address(0)) {
        // Season ended
        if (block.number >= endBlock) {
            rewardRate = _amount / (endBlock - startBlock);
        } else {
            // Not ended

            // Changes only concern future reward calculation
            uint256 currRemainingReward = (endBlock - block.number) * rewardRate;
            rewardRate = (currRemainingReward + _amount) / (endBlock - startBlock);
        }

        require(rewardRate > 0, InvalidRewardRate());
        _mintReward(_amount);
        endBlock += endBlock - startBlock;
    }

    function stake(uint256 _pId, uint256 _amount) external {
        // TODO: To be implemented
        /**
         * Updates pool's totalSupply, transfers token, updates user's stakedAmount(balance)
         */
    }

    function withdraw(uint256 _pId, uint256 _amount) external {
        // TODO: To be implemented
    }

    function claim(uint256 _pId) external {
        // TODO: To be implemented
    }

    /**
     * Internal functions
     */

    function _depositEth(uint256 _amount) internal {}

    function _deposit(address token, uint256 _amount) internal {}

    /**
     * Private functions
     */

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    function _min(uint256 _x, uint256 _y) private pure returns (uint256 minValue) {
        minValue = _x <= _y ? _x : _y;
    }

    function _mintReward(uint256 _amount) private {
        require(_amount > 0, InvalidMintAmount(_amount));

        metaNodeToken.mint(_amount);
    }
}
