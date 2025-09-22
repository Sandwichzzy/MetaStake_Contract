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

See [math note](../MathNotes/Forloop%20reconstruct.pdf)

#### Reward per token calculation

Why is does calculation used reward per token across users? For example

> Alice staked 100 at 3
> Bob staked 200 at 5
> To calculate reward per token at 5, i.e., `r5`:
> `r5 = r3 + (R / T) * (5 - 3)`
> It is cuz when Alice staked, reward per token changed, and when Bob staked, reward per token also changed, I am "updating" the reward per token for the entire season, not just Bob, so it relates to `r3` instead of `r0` for `r3` is the last

#### When to calculate reward earned by user?

Whenever staked amount changed(exclude initial stake)
**The reward per token to use**:
When calculating reward per token, we use global previous, when calculating actual reward earned, we use user specific previous, so we need to keep track of this data

#### Algorithm

1. On total amount change(i.e., user stake or withdraw)
    1. Calculate reward per token
    2. Calculate reward earned by user
    3. Update user reward per token paid
    4. Update last update time
    5. Update stake amount

#### Implementation of this mechanism

##### Algorithm

**On Stake or Withdraw**

1. Calculate current reward per token
    - r: reward per token
    - `r += R / totalSupply * (currBlock - lastUpdateBlock)`
2. Calculate reward earned by user
    - `rewards[user] += balanceOf[user] * (r - userRewardPerTokenPaid[user])`
3. Update user reward per token paid
    - `userRewardPerTokenPaid[user] = r`
4. Update last update time
    - `lastUpdateBlock = currBlock`
5. Update staked amount
    - `balanceOfUser[user] += amount` / `balanceOfUser -= amount`
    - `totalSupply += amount` / `totalSupply -= amount`

##### Details

1. `rewardRate` is not directly set, it is calculated, by either `totalSupply` update or admin adjusting total reward

- Storing reward per token
    - Need to store global changes and user changes
    - I can store entire history with array for both user and pool structs, but this would increase storage usage
    - **Final verdict**: Just store calculation essentials, much cheaper, and history can always be retrieved by logs and events from off-chain
- Token minting
    - I would mint the tokens on season declaration

2. Setting season
    - The validation of season window is buggy: Need to adjust `endBlock` first -> Must result in active season -> Blocks adjustments of `startBlock`
    - Combine the two, and to avoid duplicate `sstore`, add equality check

3. Decimal handling by scaling
    - When dealing with reward per token and reward per token paid, scale by `1e18` to handle decimals, this is where I should employ `SafeMath`;

4. Duplicate pool
    - Need to handle dup pool, the cleanest approach is mapping
    - Padded approach