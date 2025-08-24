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
