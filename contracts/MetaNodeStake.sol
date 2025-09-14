// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import "./MetaNodeToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol"; // Safe handling ERC20

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

// TODO: Organize notes to natspec

contract MetaNodeStake is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
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

    /**
     * @dev Padded approach: stores `pId + 1` -> 0 being nonexistent
     */
    mapping(address => uint256) tokenPoolIds;

    /**
     * @notice `rewardPerTokenPaid` is updated with `getRewardPerToken(uint256)`, so it is also scaled by 1e18
     */
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
    event PoolCreated(address indexed token, uint256 indexed poolId);

    event SeasonWindowSet(uint256 indexed startBlock, uint256 indexed endBlock);
    event RewardRateUpdated(uint256 indexed value, address indexed by);

    event ClaimPaused(uint256 indexed blockNum, address indexed operator);
    event ClaimUnpaused(uint256 indexed blockNum, address indexed operator);
    event WithdrawPaused(uint256 indexed blockNum, address indexed operator);
    event WithdrawUnpaused(uint256 indexed blockNum, address indexed operator);

    // Errors
    error InvalidPoolId(uint256 pId);

    error InvalidWindow(uint256 start, uint256 end);
    error InvalidRewardAmount(uint256 rewardPerBlock);
    error InvalidMintAmount(uint256 mindAmount);

    error InvalidRewardRate();
    error RewardSeasonActive();

    error DuplicatePool(address token);
    error InvalidPoolWeight();
    error InvalidMinStakeAmount();
    error InvalidLockPeriod();

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
        if (block.number <= endBlock) {
            revert RewardSeasonActive();
        }
        if (_startBlock >= _endBlock) {
            revert InvalidWindow(_startBlock, _endBlock);
        }
        _;
    }

    modifier validPid(uint256 _pId) {
        require(_pId < pools.length, InvalidPoolId(_pId));
        _;
    }

    /**
     * Made a modifier, will be fired by any actions that changes rewardRate: reward amount change, user stake/withdraw
     * The actions calculates the reward prior of the change that triggered this, updates the related states, so it
     * runs BEFORE the update of rewardRates, etc.,
     */
    function updatesReward(uint256 _pId, address _user) private {
        if (_pId == 0) {
            /**
             * Triggered by user stake/withdraw, since there's no user stake or withdraw involved,
             * no need to update user's `rewardPerTokenPaid`
             */
            // Bulk update pools using for loop, this will be expensive
            for (uint i = 0; i < pools.length; i++) {
                Pool storage pool_ = pools[i];
                pool_.rewardPerTokenStored = getRewardPerToken(i); // Calculate rj
                pool_.lastUpdateBlock = getLastValidRewardBlock(); // Update blocknum
            }
        } else {
            // Triggered by pool update or s/w
            Pool storage pool_ = pools[_pId];
            pool_.rewardPerTokenStored = getRewardPerToken(_pId); // Calculate rj
            pool_.lastUpdateBlock = getLastValidRewardBlock(); // Update blocknum

            // Triggered by user stake/withdraw
            if (_user != address(0)) {
                UserRecord storage userLedger_ = userLedger[_pId][_user];
                userLedger_.rewardsEarned = earnedReward(_pId, _user); // Update reward
                userLedger_.rewardPerTokenPaid = pool_.rewardPerTokenStored; // Record this rj
            }
        }
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
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        _grantRole(ADMIN_ROLE, _defaultAdmin);
        _grantRole(PAUSER_ROLE, _pauser);
        _grantRole(UPGRADER_ROLE, _upgrader);

        metaNodeToken = MetaNodeToken(_rewardToken);
        emit TokenSet(_rewardToken);

        setSeasonWindow(_startBlock, _endBlock);

        rewardRate = _rewardRate;
        emit RewardRateUpdated(_rewardRate, msg.sender);
        _mintReward((_endBlock - _startBlock) * _rewardRate);

        createPool(address(0), 100, 0.01 ether, 5);
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

    function createPool(
        address _token,
        uint256 _poolWeight,
        uint256 _minAmount,
        uint256 _lockPeriod
    ) public onlyRole(ADMIN_ROLE) {
        require(tokenPoolIds[_token] == 0, DuplicatePool(_token));
        require(_poolWeight > 0, InvalidPoolWeight());
        require(_minAmount > 0, InvalidMinStakeAmount());
        require(_lockPeriod > 0, InvalidLockPeriod());

        Pool memory newPool = Pool({
            stakeToken: _token,
            poolWeight: _poolWeight,
            totalSupply: 0,
            rewardPerTokenStored: 0,
            lastUpdateBlock: block.number,
            minTokenLock: _minAmount,
            lockPeriod: _lockPeriod
        });

        uint256 poolId = pools.length;
        tokenPoolIds[_token] = poolId + 1;
        pools.push(newPool);
        totalWeight += _poolWeight;

        emit PoolCreated(_token, poolId);
    }

    function updatePool(
        uint256 _pId,
        uint256 _poolWeight,
        uint256 _minAmount,
        uint256 _lockPeriod
    ) public onlyRole(ADMIN_ROLE) validPid(_pId) {
        require(_poolWeight > 0, InvalidPoolWeight());
        require(_minAmount > 0, InvalidMinStakeAmount());
        require(_lockPeriod > 0, InvalidLockPeriod());

        Pool storage pool_ = pools[_pId];
        uint256 oldWeight = pool_.poolWeight;
        uint256 oldMin = pool_.minTokenLock;
        uint256 oldLockPeriod = pool_.lockPeriod;

        if (oldWeight != _poolWeight) {
            updatesReward(_pId, address(0));
            totalWeight += _poolWeight - oldWeight;
            pool_.poolWeight = _poolWeight;
        }
        if (oldMin != _minAmount) {
            pool_.minTokenLock = _minAmount;
        }
        if (oldLockPeriod != _lockPeriod) {
            pool_.lockPeriod = _lockPeriod;
        }
    }

    //Season configuration

    /**
     * This can only be called outside of active season, and the previous reward rate is not
     * updated in this function, should combine this call with `setTotalReward` when starting
     * a new season, to ensure minting the needed reward
     * @param _startBlock Start block of new season
     * @param _endBlock End block of new season
     */
    function setSeasonWindow(
        uint256 _startBlock,
        uint256 _endBlock
    ) public onlyRole(ADMIN_ROLE) validWindow(_startBlock, _endBlock)  {
        updatesReward(0, address(0));
        if (_startBlock != startBlock) {
            startBlock = _startBlock;
        }
        if (_endBlock != endBlock) {
            endBlock = _endBlock;
        }

        emit SeasonWindowSet(_startBlock, _endBlock);
    }

    function getLastValidRewardBlock() public view returns (uint256 lastValidRewardBlock) {
        lastValidRewardBlock = _min(block.number, endBlock);
    }

    function getWeightedRewardRate(uint256 _pId) public view validPid(_pId) returns (uint256) {
        // Calculates `R` based on pool weight
        Pool memory pool = pools[_pId];
        return rewardRate * (pool.poolWeight / totalWeight);
    }

    /**
     * Calculates reward per token(rj) for pool: _pId, scaled by 1e18 to handle decimals
     * @param _pId Pool id
     */
    function getRewardPerToken(uint256 _pId) public view validPid(_pId) returns (uint256) {
        // Calculating rj

        Pool memory pool = pools[_pId];
        if (pool.totalSupply == 0) {
            return pool.rewardPerTokenStored;
        }

        return
            pool.rewardPerTokenStored +
            (getWeightedRewardRate(_pId) *
                (getLastValidRewardBlock() - pool.lastUpdateBlock) *
                1e18) /
            pool.totalSupply;
    }

    function earnedReward(
        uint256 _pId,
        address _user
    ) public view validPid(_pId) returns (uint256) {
        // Calculation of reward: see math note
        UserRecord memory userRecord = userLedger[_pId][_user];
        return
            userRecord.rewardsEarned +
            (userRecord.stakedAmount * (getRewardPerToken(_pId) - userRecord.rewardPerTokenPaid)) /
            1e18;
    }

    /**
     * External functions
     */

    function setTotalReward(uint256 _amount) external onlyRole(ADMIN_ROLE) {
        updatesReward(0, address(0));
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
        emit RewardRateUpdated(rewardRate, msg.sender);
        _mintReward(_amount);
        endBlock += endBlock - startBlock;
    }

    function stake(uint256 _pId, uint256 _amount) external payable validPid(_pId) {
        updatesReward(_pId, msg.sender);
        // TODO: To be implemented
        /**
         * Updates pool's totalSupply, transfers token, updates user's stakedAmount(balance)
         */
    }

    function requestWithdraw(uint256 _pId, uint256 _amount) external validPid(_pId) {
        updatesReward(_pId, msg.sender);
        // TODO: To be implemented
    }

    function claim(uint256 _pId) external validPid(_pId) nonReentrant {
        // TODO: To be implemented
    }

    function claimAll() external nonReentrant {
        // TODO: To be implemented
    }

    /**
     * Internal functions
     */

    function _depositEth(uint256 _amount) internal {
        // TODO: Implement
    }

    function _deposit(address token, uint256 _amount) internal {
        // TODO: Implement
    }

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
