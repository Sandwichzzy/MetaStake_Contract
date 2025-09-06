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
        uint256 weight;
        uint256 stakedAmount;
        uint256 lockPeriod;
    }

    struct User {
        uint256 stakedAmount;
        uint256 pendingReward;
        uint256 claimedReward;
        UnstakeRequest[] unstakeRequests;
    }

    struct UnstakeRequest {
        uint256 amount;
        uint256 unlockBlock;
    }

    // States
    MetaNodeToken public metaNodeToken;

    bool private _claimPaused;
    bool private _withdrawPaused;

    uint256 public startBlock;
    uint256 public endBlock;
    uint256 public rewardPerBlock;
    uint256 public totalWeight;

    Pool[] public pools;

    mapping(uint256 => mapping(address => User)) public userLedger;

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
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _defaultAdmin,
        address _pauser,
        address _upgrader,
        address _rewardToken,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _rewardPerBlock
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
        rewardPerBlock = _rewardPerBlock;
        emit RewardPerBlockSet(_rewardPerBlock, msg.sender);
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

    function setRewardPerBlock(uint256 _reward) public onlyRole(ADMIN_ROLE) {
        require(_reward > 0, InvalidRewardAmount(_reward));

        rewardPerBlock = _reward;
        emit RewardPerBlockSet(_reward, msg.sender);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}
}
