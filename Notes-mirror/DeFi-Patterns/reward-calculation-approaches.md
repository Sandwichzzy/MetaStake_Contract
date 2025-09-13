# Reward Calculation Approaches in DeFi

## Overview

This document compares different reward calculation patterns used in DeFi staking protocols, specifically contrasting the Synthetix StakingRewards approach with more complex multiplier-based systems.

## Synthetix StakingRewards Pattern

### Core Mechanism
- **Reward Per Token**: Accumulates over time based on reward rate
- **Formula**: `rewardPerToken += rewardRate * (currentTime - lastUpdateTime) / totalSupply`
- **User Rewards**: `userBalance * (rewardPerToken - userRewardPerTokenPaid)`

### Key Characteristics
- Time-based or block-based reward distribution
- Continuous reward rate per unit time
- Updates triggered on user actions (stake/unstake)
- Simple state management with `userRewardPerTokenPaid` tracking

### Multi-Pool Implementation
```solidity
struct Pool {
    IERC20 stakingToken;
    uint256 rewardRate;
    uint256 lastUpdateTime;
    uint256 rewardPerTokenStored;
    uint256 totalSupply;
}

function rewardPerToken(uint256 poolId) public view returns (uint256) {
    Pool storage pool = pools[poolId];
    if (pool.totalSupply == 0) return pool.rewardPerTokenStored;
    
    return pool.rewardPerTokenStored + 
           (pool.rewardRate * (block.timestamp - pool.lastUpdateTime) * 1e18) / 
           pool.totalSupply;
}
```

## Complex Multiplier-Based Pattern (Original Implementation)

### Core Mechanism
- **Accumulated Rewards Per Staking Token**: `accMetaNodePerST`
- **Block Multiplier System**: Uses start/end blocks with reward multipliers
- **Formula**: `accMetaNodePerST += (totalReward * 1 ether) / stSupply`
- **User Rewards**: `user.stAmount * pool.accMetaNodePerST / (1 ether) - user.finishedMetaNode`

### Key Characteristics
- Block-based reward periods with defined start/end
- Weighted pool system for proportional distribution
- More complex state with `finishedMetaNode` and `pendingMetaNode`
- Global reward distribution control

## Comparison Analysis

### Synthetix Approach Advantages
- **Simplicity**: Easier to understand and audit
- **Gas Efficiency**: More predictable gas costs
- **Modularity**: Each pool operates independently
- **Flexibility**: Easier to add/remove pools dynamically
- **Established Pattern**: Well-tested in production

### Complex Multiplier Advantages
- **Global Control**: Centralized reward distribution management
- **Pool Weighting**: Built-in system for weighted rewards across pools
- **Precision Control**: Block-based precision vs time-based
- **Complex Tokenomics**: Better for sophisticated reward mechanisms

## Current Industry Usage (2024-2025)

### Synthetix Pattern Used By:
- **Synthetix** - Original implementation
- **Curve Finance** - Gauge rewards
- **Convex Finance** - Multi-pool staking
- **Yearn Finance** - Vault rewards
- **SushiSwap** - MasterChef v2 variations

### Complex Patterns Used By:
- **MasterChef variants** - Complex farming protocols
- **Custom tokenomics protocols** - Projects requiring precise reward control

## Decision Framework

### Use Synthetix Pattern When:
- Simple multi-asset staking required
- Gas efficiency is priority
- Dynamic pool management needed
- Standard reward distribution acceptable

### Use Complex Pattern When:
- Precise tokenomics control required
- Global reward distribution management needed
- Complex weighted rewards across pools
- Block-based precision preferred over time-based

## Implementation Considerations

### Multi-Pool Synthetix Setup:
1. Pool array structure with independent reward rates
2. Per-pool reward calculations
3. Separate user info mappings per pool
4. Individual pool state management

### State Management Patterns:
- **Synthetix**: `userRewardPerTokenPaid` + `rewards[user]`
- **Complex**: `finishedMetaNode` + `pendingMetaNode` + withdrawal requests

## Conclusion

Both patterns remain valid and actively used in modern DeFi. The Synthetix approach is often preferred for its simplicity and gas efficiency, while complex multiplier systems are chosen when sophisticated reward distribution control is required. The choice depends on specific protocol requirements rather than one being universally superior.