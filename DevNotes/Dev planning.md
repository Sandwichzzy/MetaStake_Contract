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

Original contract used UUPS, I used to think this approach inferior, ~~I might want to implement upgradability with
TProxy~~
I will try and implement UUPS

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
Funds immediately available, easy to implement, but is not flexible and exposes risks, so I will be minting on need(like
mint on reward claim) in my implementation

### 4.2 Stake contract design

#### 4.2.1 Additional control components to add

- Access Control
    - Contract scope, use role-based
- Reentrancy guard
    - Add to functions
- ~~TProxy~~ UUPS
    - For general purposed contracts, TProxy is better because of separation of proxy and business logic, but when
      implementing a DeFi project, users can benefit from the lower gas costs of UUPS, plus the standard is improving

##### 4.2.1.1 UUPS

Difference from TProxy is that its upgradability is embedded in the contract itself

The verification LOGIC and RULES are stored in the logic contract, when upgrading, the upgrade functions like:
`_authorizedUpgrade(address)`(with owner verification) gets executed in proxy context

The function calls are identical: User -> Proxy -`fallback`-> Logic, the key difference lies in upgrade logic

Key differences:

- More direct
    - TProxy uses: Owner(EOA) -> ProxyAdmin(contract) -> Proxy -`Upgrade funcs`-> Upgraded state, UUPS is: Owner(EOA) ->
      Proxy -`Upgrade funcs from logic`-> Upgraded state

##### 4.2.1.2 Access control

I want access control for the functions, as well as upgradability, so `AccessControlUpgradeable`

##### 4.2.1.3 Pausable(upgradable)

This is also a must-have to give emergency brakes

#### 4.2.2 How-tos

- What do I want
    - Stakers can lock assets(ERC20 and ETH)
    - Contract can create / record pools
    - Contract can calculate rewards
    - Stakers can claim rewards
    - Contract can be paused
    - Contract can be upgraded
    - Contract has access control
- How-tos
    - Stakers can lock assets(ERC20 and ETH)
        - `payable` and `approve`
    - Contract can create / record pools
        - Create pool contracts?
        - Use example approach: just a storage of pool structs to store info about the pools
    - Contract can calculate rewards
        - Based on time locked and locked amount
    - Stakers can claim rewards
        - Can transfer reward tokens to stakers when required
    - Contract can be paused
        - Can pause contract execution
    - Contract can be upgraded
        - Upgradability
    - Contract has access control
        - Role based access control
- What do I need
    - Stakers can lock assets(ERC20 and ETH)
        - `payable` and `approve`
        - Data storage:
            - By pool + `userAddress`
    - Contract can create / record pools
        - Pool + userAddress
        - One pool only supports one token, so it is possible to use tokenAddress + userAddress to track amount, but
          using token address will increase gas usage, so maybe use pool id
    - Contract can calculate rewards
        - Based on some rules, not clear on this yet
    - Stakers can claim rewards
        - Claim if there are available rewards
        - Stake contract can mint token on demand -> Stake contract owning the token contract
    - Contract can be paused
        - OpenZeppelin
    - Contract can be upgraded
        - OpenZeppelin UUPS
    - Contract has access control
        - OpenZeppelin

#### 4.2.3 Deployment flow
1. Deploy token contract
    - This would set the token's admin to deployer
2. Deploy implementation
    - Deploy the logic for later
3. Deploy proxy
    - Calls implementation's `initializer` with `ERC1967Proxy`'s constructor, which then calls `upgradeToAndCall`, which sets the implementation target and initializes the storage: saving the deployed token address, etc., these logic and storage variables are in logic contract
    - The `INITIALIZABLE_STORAGE` slot stores a struct

    ```solidity
    struct InitializableStorage {
        /**
         * @dev Indicates that the contract has been initialized.
         */
        uint64 _initialized;
        /**
         * @dev Indicates that the contract is in the process of being initialized.
         */
        bool _initializing;
    }
    ```

    `_initialized` being the version of the currently initialized implementation, this will be used to check if the initialization is valid(0 on first init and bigger than previous value on upgrades), this is how `initializer` and `reinitializer` modifiers are different(`initializer` is equivalent to `reinitializer(1)`), and that's how UUPS works.
4. Now that Proxy contract is deployed, I can call `setMinter` to set the Proxy's address as `MINTER_ROLE`
    - Future mints happen when stakers request rewards, the txn is made to the proxy, proxy delegatecalls logic(in which lies the call to `mint`), so the actual minter should be the proxy
