# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Solidity smart contract project for MetaNode staking. The system allows users to stake ETH and ERC20 tokens
across multiple pools and earn MetaNode token rewards based on their stake amount and duration.

## Core Architecture

### Smart Contracts

- **MetaNodeStake.sol**: Main upgradeable staking contract with multi-pool support
    - Uses OpenZeppelin's UUPS upgradeable pattern
    - Implements role-based access control (DEFAULT_ADMIN_ROLE, UPGRADE_ROLE, ADMIN_ROLE)
    - Supports both ETH staking (pool 0) and ERC20 token staking
    - Features delayed withdrawal mechanism (unstake -> withdraw after lock period)

- **MetaNode.sol**: ERC20 reward token contract
    - Simple ERC20 implementation with initial supply of 10M tokens

### Key Design Patterns

- **Multi-pool staking**: Each pool has independent staking tokens, weights, and parameters
- **Reward calculation**: Uses accumulated rewards per staking token mechanism
- **Delayed withdrawals**: Anti-rush protection with configurable lock periods
- **Pausable operations**: Admin can pause withdraw/claim functions independently

### Data Structures

- `Pool`: Contains staking token address, weight, rewards, and configuration
- `User`: Tracks staked amount, finished rewards, pending rewards, and withdrawal requests
- `UnstakeRequest`: Manages delayed withdrawal with unlock block numbers

## Development Commands

### Setup

```bash
npm install
```

### Compilation

```bash
npx hardhat compile
```

### Deployment

```bash
# Deploy MetaNode token first
npx hardhat ignition deploy ./ignition/modules/Rcc.js

# Deploy MetaNodeStake (update token address in scripts/RCCStake.js first)
npx hardhat run scripts/RCCStake.js --network sepolia
```

### Testing

```bash
# Note: Test framework not yet configured in package.json
# Tests should be added - see test/ directory with existing placeholder files
```

## Network Configuration

- **Sepolia testnet** configured in hardhat.config.js
- Requires environment variables: ALCHEMY_API_KEY, PRIVATE_KEY, ETHERSCAN_API_KEY
- Gas price set to 30 Gwei for Sepolia

## Code Style

- Prettier configured with 4-space indentation, no tabs
- Solidity version: 0.8.20
- Uses OpenZeppelin contracts for security and upgradeability

## Important Development Notes

1. **Security**: Contract uses defensive programming with overflow checks and safe transfers
2. **Upgradeability**: UUPS pattern requires UPGRADE_ROLE for contract upgrades
3. **Pool Management**: First pool (pid=0) must be ETH pool with address(0x0)
4. **Block-based rewards**: System calculates rewards based on block numbers, not timestamps
5. **Role Management**: Three-tier permission system for different administrative functions

## Testing Requirements

Based on requirements documents, comprehensive testing should be implemented covering:

- Multi-pool staking and unstaking scenarios
- Reward calculation accuracy
- Access control and role management
- Upgrade functionality
- Edge cases and error conditions

## Personal specifications

### Standard workflow

1. First think through the problem, read the codebase for relevant files, and write a plan to todo.md.
2. The plan should have a list of todo items that you can check off as you complete them
3. Before you begin working, check in with me and I will verify the plan.
4. Then, begin working on the todo items, marking them as complete as you go.
5. Please every step of the way just give me a high level explanation of what changes you made
6. Make every task and code change you do as simple as possible. We want to avoid making any massive or complex changes.
   Every change should impact as little code as possible. Everything is about simplicity.
7. Finally, add a review section to the todo.md file with a summary of the changes you made and any other relevant
   information.

### Requirements

- This is a learning project, so I would require your utmost accuracy, provide reference whenever possible.
- You will not edit codes unless I explicitly instruct you to, implicit instructions like "Complete" my code will mean:
  Provide examples
- I would need you to review my code, and you need to generate review notes in `Notes-mirror`, to keep things
  structured, you should strictly keep the structure of the project, treating `Notes-mirror` as root, and strictly
  follow one-file-one-note pattern, if referring to the same file, you should always update the existing one instead of
  creating a new file, note that this entry only affects code review, not note-taking
- For other notes like suggestions you should also keep them in `Notes-mirror`, and keep them organized, you should
  create folders with clear topics, subtopics to contain the corresponding notes
- You should try and make the arrangement clear avoid duplicates and massive expansions of file count, you should create
  another file in `Notes-mirror` to keep note just for yourself to reference in the future before creating notes, this
  is not restricted, as long as you get it done, you can choose a human-readable format that is most efficient for you
  to r/w, this note would also be used as a lookup table for me, the tracker file name should be: `_notes-tracker.md`
- Referencing this tracker file before your write and updating this file after your write is a must-have step
- When creating notes, you should follow this pattern: Broadest scope folder -> Some minor scope
  folder -> [the same process] -> Note file, you should go at most 3 folders deep starting from `Notes-mirror`, i.e.,
  max 3 levels of sub-folders
- When creating new dir or notes, you should follow the 3-level-sub-folder rule and come up with the optimal structure,
  when creating note, you should try and create with larger scope rather than the exact content, this should help you
  organize the expansion of notes
- If you are asked to make notes, you should first check if the new content can fit in any old notes, ideally
  you can just append contents, but if sometimes some similar topics exists but does not exactly match new content, you
  should first determine whether if it is possible to change old note's topic into more general one to include new
  content, if not, then you should move on to create new note
- As a fallback / final check, after creating new notes, you should always refer to the tracker to see if you can merge
  notes, and update your tracker if any change is needed and made

### Project scope

- This project already contains some already-implemented files, but I want to reimplement the contracts myself
- There are two crucial outcome of this project: first, I need to be able to reimplement the expected functions; Second,
  I need to understand the differences between my implementation and the original implementation(which might not be the
  best)
