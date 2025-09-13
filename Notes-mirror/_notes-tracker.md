# Notes Tracker

This file tracks all notes and their organization in the Notes-mirror directory.

## Directory Structure

```
Notes-mirror/
├── _notes-tracker.md (this file)
├── Solidity-Concepts/
│   ├── Proxy-Patterns/
│   │   ├── uups-vs-transparent-proxy.md
│   │   └── uups-upgrade-mechanics.md
│   ├── Code-Style/
│   │   └── naming-conventions.md
├── DeFi-Patterns/
│   └── staking-window-restrictions.md
├── Deployment-Strategy/
│   └── deployment-flow-review.md
```

## Notes Index

### Solidity Concepts
- **Proxy Patterns**
  - `uups-vs-transparent-proxy.md`: Comprehensive comparison between UUPS and Transparent Proxy patterns, including when to use each and practical recommendations
  - `uups-upgrade-mechanics.md`: Detailed explanation of UUPS upgrade process, reinitializer pattern, AccessControl preservation, and practical upgrade examples
- **Code Style**
  - `naming-conventions.md`: Solidity naming conventions, underscore patterns, public-internal function patterns, and style guide references
  - `contract-layout-template.md`: Standard contract organization template with function/modifier ordering rules

### DeFi Patterns
- **Staking Patterns**
  - `staking-window-restrictions.md`: Standard pattern for restricting parameter changes during active reward periods, industry practices and variations
- **Reward Calculation**
  - `reward-calculation-approaches.md`: Comprehensive comparison between Synthetix StakingRewards pattern and complex multiplier-based systems, including multi-pool implementations and current industry usage

### Deployment Strategy
- **Deployment Flow**
  - `deployment-flow-review.md`: Review and assessment of the UUPS deployment strategy, including strengths, technical accuracy, and improvement recommendations

## Topics Coverage
- [ ] Smart Contract Security
- [x] Proxy Patterns
- [x] Code Style & Conventions
- [ ] Access Control
- [x] Upgradeability
- [ ] Gas Optimization
- [x] DeFi Patterns
- [x] Deployment Strategy

## Note Creation Guidelines
- Max 3 levels of subdirectories
- Use general topic folders rather than specific content
- Prefer updating existing notes over creating new ones
- Check this tracker before creating new notes