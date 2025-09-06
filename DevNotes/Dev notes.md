# Notes mid dev

## Access control

### Basic usage

- Define role with: `keccak256("SOME_ROLE")`, this will provide a byte32(64-hex string)
- Grant address with this role
- Access control with modifier `onlyRole(byte32 role)`

## Token

### Ownership

- Only the staking contract should have minting privilege, token deployer should only be the admin
    - This can be done with initializing the token contract with the stake contract: `msg.sender` set as the token's
      admin, the stake contract itself set as minter

### Upgradability consideration

- When upgrading the stake contract, should also update the minter address
- Will this mean that I also have to make the token contract upgradeable, this would add overhead
    - Regarding the token, the minter should be the stake contract(in reality, the proxy), the admin should be the
      deployer of proxy, so in the token contract, access control is enough
- Considering the above, the token would be deployed by the proxy contract:
    - In the proxy contract, send `msg.sender` as `deployer`, `address(this)` as minter
- Proxy should not contain state variables, so how to keep track of this token contract?

### OpenZeppelin: Upgradability variants

For example, `AccessControl` vs `AccessControlUpgradeable`, in the upgradeable version, I need to call
`__AccessControl_init()` in `initializer`, to check whether it is fired in initialization call, to avoid storage
overwrites of previous role data

## Stake

### Why use array instead of creating separate contracts

When user interacts with the stake, `reward per token` and `user reward paid` will be updated, it would be better to manage in the same contract

### How to auto handle chain native token

### Process

Stake comes with native token of the chain, and pools for different tokens can be created by admin

For each pool, there will be variable(s) to track that need to be updated when every a user withdrew or staked token from / into the pool, hence calculating the reward for the user.

There's a weight for each pool that can be adjusted to control the actual reward per token for different assets

#### Storage

Hence, what do we need in storage?

- [ ] Pools
    - [ ] Token
    - [ ] Weight
    - [ ] Total token staked(locked)
    - [ ] Lock period between withdraw request and unlock
- [ ] Users
    - [ ] Staked amount for each pool
    - [ ] Pending reward amount for each pool(this should be updated each action?)
    - [ ] Claimed reward
    - [ ] Unstake request?
- [ ] Season tracking
    - Start and end
- [ ] Rate
- [ ] Total weight

### Reward calculation

[**Video explanation**](https://www.youtube.com/watch?v=iNZWMj4USUM), very well explained, should watch repeatedly

Key components:

**Contract wise**

1. Total reward amount
2. Reward per time unit(block)
3. Reward period(contract scope)
4. Total tokens staked

**User wise**

1. Stake time
2. Stake amount

To calculate total reward, I should be able to calculate reward for each block for each user:

> reward = rewardPerBlock \* (userStaked / poolTotal)

The total amount would be the sum of this from start block to end block, during this period, the amount of `userStaked` and `poolTotal` might change, and
for long periods, the calculation can be gas intensive, hence we need an equivalent formula

First, from block _n_ to block _k_, the sum of blocks from _n_ to _k_ is equal to:

> [Sum of *0* to *n - 1*] - [Sum of *0* to *k - 1*], just like a prefix sum subtraction

And to calculate reward from _j0_ to _j_:

> r0 = 0
> rj = rj0 + (R / T) * (j - j0)
> Where `j` is the target time, `j0` is the last time reward changed(someone deposited or withdrew, initially, it would be 0), *R\* is the reward rate, `T` is the total token amount staked where the amount of token staked is constant during this calculation: `j0 <= i <= j`

So in implementation, the reward is calculated each time the user change their stake amount, by calculate the current stake reward, minus the last time it is changed
