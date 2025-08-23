# Stake development notes: MetaNodeStake

## 1. Goals

- Should support staking multiple tokens
- Reward stakers based on amount and time staked
    - Reward with protocol token: `MetaNodeToken`
- Should support multiple staking pools
    - Each pool should have individual staking tokens, reward calculations

## 2. Designs

### 2.1 Components

#### 2.1.1 Reward token

Use this as a reward token, and because I am going to distribute it in quantity, it will have to be ERC20

#### 2.1.2 Staking Pool

### 2.2 Upgrade

#### 2.2.1 Approach

Original contract used UUPS, I used to think this approach inferior, I might want to implement upgradability with TProxy

### 2.3 Pause

Need to be able to pause:

- Staking
- Unstaking
- Rewarding claiming
  Don't know how yet, will need to look

## 3. Considerations

### 3.1 Contract complexity

I don't think this is going to be a very complicated system, its requirements are simple: staking, unstaking, claiming
rewards, adjusting configs for staking pools, upgradability and pause.
These aspects do not involve advanced DeFi terminologies like:

- Collateral
- Over-collateralized loan
- ...

So understanding staking protocols like Aave might not be a must

### 3.2 Complexity impact on designs

Actions on / of each pool will be fairly simple, so the "factory + pool" approach may very well be overkill in this
case, the original design of single contact plus storage var to store different pools will suffice perhaps, may still be
worth reimplementing that

### 3.3 Functionalities

Don't worry about staked token/eth for now, focus on the interaction between staker and the pools:

- Locking / Staking the values
- Unlocking / Unstaking the values
- Claiming rewards

## 4. Details(populate when developing)

### 4.1 Token

#### Initial supply

Original code initialized with `10_000_000` of decimal 18 tokens, and stated that can also mint later, what's the
trade-off?

Pre-mint:
Funds immediately available, easy to implement,
