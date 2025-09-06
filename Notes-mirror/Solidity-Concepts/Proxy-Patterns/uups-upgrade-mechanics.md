# UUPS Upgrade Mechanics

## Raw UUPS Implementation

### Core Components
1. **Proxy Contract**: Holds storage, forwards calls via `delegatecall`
2. **Implementation Contract**: Contains logic, must include upgrade function
3. **Storage Slot**: EIP-1967 standard slot `0x360894a13ba1a067e2f00000eb11f67f85f1174d00d5...` stores implementation address

### Key Difference from Transparent Proxy
The upgrade logic lives in the implementation, not the proxy.

### Simplified UUPS Proxy
```solidity
contract UUPSProxy {
    bytes32 constant IMPLEMENTATION_SLOT = 0x360894a13ba1a067e2f00000eb11f67f85f1174d00d5;
    
    fallback() external payable {
        address impl = _getImplementation();
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}
```

## OpenZeppelin UUPS Implementation

### What You Inherit
```solidity
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract MyContract is UUPSUpgradeable {
    function _authorizeUpgrade(address newImplementation) 
        internal 
        override 
        onlyRole(UPGRADE_ROLE) 
    {}
}
```

### What OpenZeppelin Provides
- `upgradeToAndCall(address, bytes)` public function
- `_authorizeUpgrade()` hook for access control
- Storage layout management
- Safety checks (implementation validation, storage gaps)

## Upgrade Process & Call Flow

### Public Interface (What You Call from Offchain)
```javascript
// Call the PROXY's public upgradeToAndCall function
await proxyContract.upgradeToAndCall(newImplAddress, initData);
```

### Internal Flow
1. Call goes to proxy → `delegatecall` to current implementation
2. Current implementation's `upgradeToAndCall()` runs
3. Checks `_authorizeUpgrade()` (your role check)
4. Calls `ERC1967Utils.upgradeToAndCall()` internally
5. Updates implementation slot
6. If `initData` provided, `delegatecall`s new implementation with that data

### Important: You Don't Call ERC1967Utils Directly
```solidity
// Inside UUPSUpgradeable (what you inherit)
function upgradeToAndCall(address newImplementation, bytes memory data) 
    public 
    payable 
    virtual 
    onlyProxy 
{
    _authorizeUpgrade(newImplementation);  // Your access control
    ERC1967Utils.upgradeToAndCall(newImplementation, data);  // Internal call
}
```

## Reinitializer Pattern

### Version System
```solidity
initializer     // version 1 - first deployment
reinitializer(2) // version 2 - first upgrade  
reinitializer(3) // version 3 - second upgrade
```

### Use Cases
- Adding new storage variables that need initialization
- Setting up new functionality introduced in upgrade
- **Never** reinitialize existing systems like AccessControl

### AccessControl Preservation
```solidity
// ✅ Correct - preserve AccessControl
function initializeV2(uint256 _newFeature) public reinitializer(2) {
    // NO AccessControl initialization calls
    // Roles and permissions remain unchanged
    newFeature = _newFeature;
}

// ❌ Wrong - resets all roles
function initializeV2() public reinitializer(2) {
    __AccessControl_init();  // This resets all roles!
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender); // Removes existing admins
}
```

## Practical Examples

### Simple Upgrade (No Reinitialization)
```javascript
await proxyContract.upgradeToAndCall(newImplAddress, "0x");
```

### Upgrade with New Features
```javascript
const initData = newImpl.interface.encodeFunctionData("initializeV2", [1000]);
await proxyContract.upgradeToAndCall(newImplAddress, initData);
```

### Complete Upgrade Script
```javascript
// 1. Deploy new implementation
const newImpl = await MetaNodeStakeV2.deploy();

// 2. Encode reinitializer call (if needed)
const initData = newImpl.interface.encodeFunctionData("initializeV2", [param1]);

// 3. Call the PROXY's public function
await proxyContract.upgradeToAndCall(newImpl.address, initData);
```

## Key Principles

1. **Call Flow**: Offchain → Proxy → Current Implementation → Internal Utils → New Implementation (if initData)
2. **Access Control**: Caller must have appropriate role (checked in `_authorizeUpgrade()`)
3. **Initialization**: Only initialize NEW storage/functionality, never reinitialize existing systems
4. **Data Parameter**: Optional encoded call to new implementation's reinitializer function