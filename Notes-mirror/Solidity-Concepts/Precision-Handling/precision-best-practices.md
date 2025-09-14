# Solidity Precision Handling Best Practices

## Key Principle: Multiply Before Divide

In Solidity's integer arithmetic, division truncates, causing precision loss. Always multiply first, then divide to preserve maximum precision.

## Example from MetaNodeStake

### ❌ Wrong (precision loss):
```solidity
(rate / totalSupply) * blocks * 1e18
// If rate=100, totalSupply=3, blocks=2
// Result: (100/3) * 2 * 1e18 = 33 * 2 * 1e18 = 66e18
```

### ✅ Correct (maximum precision):
```solidity
(rate * blocks * 1e18) / totalSupply
// Result: (100 * 2 * 1e18) / 3 = 200e18 / 3 = 66.666...e18
```

## Pattern in Reward Calculations

**Standard scaling pattern:**
1. Multiply all numerators first
2. Apply scaling factor (1e18)
3. Divide by denominator last

**Applied in `getRewardPerToken()`:**
```solidity
return pool.rewardPerTokenStored +
    (getWeightedRewardRate(_pId) *
     (getLastValidRewardBlock() - pool.lastUpdateBlock) *
     1e18) /
    pool.totalSupply;
```

## Why 1e18?

- **1e18 = 1 ether** in Solidity
- Standard precision factor for financial calculations
- Matches ERC20 decimal standard (18 decimals)
- Provides sufficient precision for most DeFi applications

## Critical for Financial Contracts

Small precision errors accumulate over time in staking/reward systems, potentially causing:
- Incorrect reward distributions
- Loss of funds
- System imbalances

Always prioritize precision in financial calculations.