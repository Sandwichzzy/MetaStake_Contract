# Solidity Naming Conventions and Code Style

## Underscore (`_`) Patterns

### 1. Private/Internal Functions
Functions prefixed with `_` indicate internal or private implementation functions:

```solidity
// Public interface function
function grantRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
    _grantRole(role, account);  // Calls internal implementation
}

// Internal implementation function
function _grantRole(bytes32 role, address account) internal virtual returns (bool) {
    // Core logic implementation
}
```

**Examples from OpenZeppelin:**
- `grantRole()` → `_grantRole()`
- `revokeRole()` → `_revokeRole()`
- `checkRole()` → `_checkRole()`

### 2. Storage Variables
Private state variables often use `_` prefix to avoid naming conflicts:

```solidity
mapping(bytes32 => RoleData) private _roles;
uint256 private _totalSupply;
string private _name;
```

### 3. Function Parameters
Parameters in constructors/functions use `_` to distinguish from storage variables:

```solidity
constructor(string memory _name, string memory _symbol) {
    name = _name;     // Avoids conflict with storage variable 'name'
    symbol = _symbol; // Avoids conflict with storage variable 'symbol'
}
```

## Public → Internal Pattern

### Purpose
This is a **security and modularity pattern** that separates:
- **Public function**: Handles access control, validation, events, external interface
- **Internal function**: Contains core logic, can be overridden by inheriting contracts

### Benefits
1. **Separation of Concerns**: Access control separate from business logic
2. **Inheritance Flexibility**: Child contracts can override internal functions
3. **Gas Optimization**: Internal functions can be called directly by inheriting contracts
4. **Security**: Public functions enforce all necessary checks

### Example Pattern
```solidity
// Public function - handles access control and validation
function transfer(address to, uint256 amount) public virtual returns (bool) {
    address owner = _msgSender();
    _transfer(owner, to, amount);  // Delegates to internal function
    return true;
}

// Internal function - contains core logic
function _transfer(address from, address to, uint256 amount) internal virtual {
    require(from != address(0), "ERC20: transfer from zero address");
    require(to != address(0), "ERC20: transfer to zero address");
    // Core transfer logic...
}
```

## Official Style Guide References

### Primary Sources
1. **Solidity Style Guide**: https://docs.soliditylang.org/en/latest/style-guide.html
   - Official naming conventions
   - Function ordering guidelines
   - Indentation and formatting rules

2. **OpenZeppelin Conventions**: https://docs.openzeppelin.com/contracts/
   - Industry-standard patterns
   - Security-focused implementations
   - Upgradeable contract patterns

3. **EIP Standards**: https://eips.ethereum.org/
   - Interface specifications (ERC20, ERC721, etc.)
   - Standard function signatures

4. **Consensys Best Practices**: https://consensys.github.io/smart-contract-best-practices/
   - Security considerations
   - Gas optimization patterns

### Key Conventions Summary
- **Functions**: `camelCase` (public), `_camelCase` (internal/private)
- **Variables**: `camelCase` (public), `_camelCase` (private)
- **Constants**: `UPPER_SNAKE_CASE`
- **Events**: `PascalCase`
- **Modifiers**: `camelCase`
- **Contracts**: `PascalCase`

## Dollar Sign (`$`) Pattern in Upgradeable Contracts

### Diamond Storage Pattern
The `$` symbol is a naming convention used with OpenZeppelin's upgradeable contracts for storage structs in the diamond storage pattern:

```solidity
AccessControlStorage storage $ = _getAccessControlStorage();
return $._roles[role].adminRole;
```

### Purpose
- **Upgrade Safety**: Ensures storage variables don't conflict during contract upgrades
- **Storage Isolation**: Each functionality gets its own storage namespace
- **Collision Prevention**: Uses specific storage slots based on hash calculations

### How It Works
```solidity
// Storage struct definition
struct AccessControlStorage {
    mapping(bytes32 => RoleData) _roles;
    // other storage variables...
}

// Storage location constant (computed hash)
bytes32 private constant AccessControlStorageLocation = 0x...;

// Storage getter function
function _getAccessControlStorage() private pure returns (AccessControlStorage storage $) {
    assembly {
        $.slot := AccessControlStorageLocation
    }
}
```

### Usage Pattern
1. Define a storage struct for related variables
2. Calculate a unique storage slot using keccak256 hash
3. Use assembly to point to that specific slot
4. Access storage through the `$` reference

### Benefits
- **Upgrade-Safe**: No storage layout conflicts between contract versions
- **Organized**: Related storage variables grouped together
- **Gas Efficient**: Direct storage slot access
- **Standard**: OpenZeppelin convention for upgradeable contracts

### Essential for UUPS Contracts
This pattern is crucial in UUPS upgradeable contracts like `MetaNodeStake.sol` to prevent storage collisions during upgrades.

## Practical Application
The underscore pattern helps distinguish between:
- **Interface/API functions** (what users interact with)
- **Implementation details** (internal contract logic)

This follows object-oriented programming principles and makes contract inheritance more predictable and secure.