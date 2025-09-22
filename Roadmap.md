# Dev Roadmap

## Details to enhance

- [ ] Follow standards for Solidity
    - `_` prefix for private functions and variables
    - `_` for function params to avoid naming clashes

## Contract specifics

### OpenZeppelin Components

- [x] Access Control
- [x] UUPS
- [ ] Pause
- [ ] Reentrancy Guard(Implement when hitting the funcs)

### Staker Functionalities

- [ ] Stake
- [ ] Unstake
- [ ] Claim rewards
    - [ ] Reward calculation

### Administrative functionalities

- [x] Upgrade logic
- [x] Pause / Resume txns
    - [x] OpenZeppelin pause logic uses a global `paused()` to track pause state, this can be employed directly or I can declare separate pause states for different purposes like the original

## Progression log

### 20250827

- Token, proxy contract should be good to go， start with stake

### 20250906

- Working on pause

### 20250913

- Initially understand the math behind calculation, start implement it with plain approach
