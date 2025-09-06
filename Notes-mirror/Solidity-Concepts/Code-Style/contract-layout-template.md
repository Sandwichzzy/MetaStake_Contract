# Solidity Contract Layout Template

## Standard Layout Order

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "...";

contract ContractName {
    // 1. Type declarations
    using SafeMath for uint256;
    
    // 2. State variables (public -> internal -> private)
    uint256 public totalSupply;
    mapping(address => uint256) internal balances;
    uint256 private _secret;
    
    // 3. Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    // 4. Errors
    error InsufficientBalance(uint256 available, uint256 required);
    
    // 5. Modifiers (grouped together, not scattered)
    modifier onlyOwner() { _; }
    modifier validAmount(uint256 amount) { _; }
    
    // 6. Functions (constructor -> receive/fallback -> external -> public -> internal -> private)
    constructor() {}
    receive() external payable {}
    function externalFunc() external {}
    function publicFunc() public {}
    function _internalFunc() internal {}
    function _privateFunc() private {}
}
```

## Key Rules

- **Function Order**: constructor → receive/fallback → external → public → internal → private
- **Modifiers**: Group together, don't scatter near functions that use them
- **State Variables**: public → internal → private