# Architecture & Design Document
## DeFi Super-App — Blockchain Technologies 2 Final Project

**Team:** Alim Kulovaskar  
**Date:** May 2026  
**Network:** Ethereum Sepolia Testnet  
**Commit:** see GitHub repository

---

## 1. System Context (C4 Level 1)

The DeFi Super-App is a decentralized protocol allowing users to:
- Swap tokens via an AMM (Automated Market Maker)
- Deposit assets into a yield-bearing ERC-4626 vault
- Participate in DAO governance via ERC20Votes token
- Monitor protocol activity via The Graph subgraph

### External Actors
- **End User** — interacts via frontend dApp (MetaMask)
- **Chainlink** — provides price feeds with staleness checks
- **The Graph** — indexes protocol events for frontend queries
- **Ethereum Sepolia** — L2-compatible testnet for deployment
[User] → [Frontend dApp] → [Smart Contracts on Sepolia]
↓
[Chainlink Oracle]
↓
[The Graph Subgraph]

---

## 2. Container & Component Diagram

### Smart Contract Architecture
┌─────────────────────────────────────────────────────┐
│                  Protocol Layer                      │
│                                                     │
│  ┌─────────────┐    ┌─────────────────────────────┐ │
│  │  GovToken   │    │      DeFi Governor           │ │
│  │ ERC20Votes  │───▶│  + TimelockController        │ │
│  │ ERC20Permit │    │  voting delay: 1 day         │ │
│  └─────────────┘    │  voting period: 1 week       │ │
│                     │  quorum: 4%                  │ │
│                     └─────────────────────────────-┘ │
│                                                     │
│  ┌─────────────┐    ┌─────────────────────────────┐ │
│  │     AMM     │    │          Vault               │ │
│  │   x·y=k    │    │        ERC-4626              │ │
│  │  fee: 0.3% │    │   tokenized yield vault      │ │
│  └─────────────┘    └─────────────────────────────-┘ │
│                                                     │
│  ┌─────────────┐    ┌─────────────────────────────┐ │
│  │ PriceOracle │    │       AMMFactory             │ │
│  │  Chainlink  │    │  CREATE + CREATE2            │ │
│  │  staleness  │    │  deterministic addresses     │ │
│  └─────────────┘    └─────────────────────────────-┘ │
│                                                     │
│  ┌─────────────┐    ┌─────────────────────────────┐ │
│  │ProtocolMgr  │    │       GameItems              │ │
│  │ UUPS Proxy  │    │       ERC-1155               │ │
│  │  V1 → V2   │    │   multi-token standard       │ │
│  └─────────────┘    └─────────────────────────────-┘ │
└─────────────────────────────────────────────────────┘

### Access Control Roles

| Contract | Role | Holder |
|----------|------|--------|
| GovToken | Owner | Deployer |
| GovToken | Minter | Owner only |
| PriceOracle | Owner | Deployer |
| AMMFactory | Owner | Deployer |
| Vault | Owner | Deployer |
| DeFiTimelock | PROPOSER_ROLE | DeFiGovernor |
| DeFiTimelock | EXECUTOR_ROLE | DeFiGovernor |
| DeFiTimelock | TIMELOCK_ADMIN | Deployer |
| ProtocolManager | Owner | Deployer |

### External Dependencies

| Dependency | Purpose | Address (Sepolia) |
|------------|---------|-------------------|
| Chainlink ETH/USD | Price feed | 0x694AA1769357215DE4FAC081bf1f309aDC325306 |
| The Graph | Event indexing | Studio subgraph |
| OpenZeppelin | Base contracts | v5.6.1 |

---

## 3. Sequence Diagrams

### 3.1 AMM Swap Flow
User          Frontend        AMM Contract      TokenA/B
│                │                │                │
│ input amount   │                │                │
│───────────────▶│                │                │
│                │ approve(amm)   │                │
│                │───────────────────────────────▶│
│                │ swap(tokenIn, amt, minOut)      │
│                │───────────────▶│                │
│                │                │ check: amountIn > 0
│                │                │ check: token valid
│                │                │ calc: amountOut = (amtIn997resOut)
│                │                │              /(resIn1000+amtIn997)
│                │                │ check: amountOut >= minOut
│                │                │ effect: reserveA += amtIn
│                │                │ effect: reserveB -= amtOut
│                │                │ interact: transferFrom(user)
│                │                │ interact: transfer(user, amtOut)
│                │ emit Swap()    │                │
│ receive tokens │                │                │
│◀───────────────│                │                │

### 3.2 Governance: Propose → Vote → Queue → Execute
Proposer      Governor       Timelock       Target Contract
│               │               │               │
│ propose()     │               │               │
│──────────────▶│               │               │
│               │ check: threshold (1% supply)  │
│               │ emit ProposalCreated()         │
│               │               │               │
│ [1 day voting delay]          │               │
│               │               │               │
│ castVote(id, 1│)              │               │
│──────────────▶│               │               │
│               │ check: quorum (4%)            │
│               │ emit VoteCast()               │
│               │               │               │
│ [1 week voting period]        │               │
│               │               │               │
│ queue(id)     │               │               │
│──────────────▶│               │               │
│               │ schedule()    │               │
│               │──────────────▶│               │
│               │               │               │
│ [2 day timelock delay]        │               │
│               │               │               │
│ execute(id)   │               │               │
│──────────────▶│               │               │
│               │ execute()     │               │
│               │──────────────▶│               │
│               │               │ call target   │
│               │               │──────────────▶│

### 3.3 ERC-4626 Vault Deposit Flow
User          Frontend        GovToken         Vault
│                │                │               │
│ enter amount   │                │               │
│───────────────▶│                │               │
│                │ approve(vault, │amount)        │
│                │───────────────▶│               │
│                │ deposit(assets,│receiver)      │
│                │────────────────────────────────▶│
│                │                │ transferFrom(user, vault, assets)
│                │                │ shares = convertToShares(assets)
│                │                │ mint(receiver, shares)
│                │                │ emit Deposit()
│ receive shares │                │               │
│◀───────────────│                │               │

---

## 4. Storage Layout

### GovToken
| Slot | Variable | Type |
|------|----------|------|
| inherited | ERC20 storage | name, symbol, balances, allowances |
| inherited | ERC20Votes | checkpoints, delegation |
| inherited | Ownable | _owner |
| 0 | MAX_SUPPLY | uint256 (constant) |

### AMM
| Slot | Variable | Type |
|------|----------|------|
| inherited | ERC20 | LP token storage |
| inherited | ReentrancyGuard | _status |
| inherited | Ownable | _owner |
| 0 | tokenA | address (immutable) |
| 1 | tokenB | address (immutable) |
| 2 | reserveA | uint256 |
| 3 | reserveB | uint256 |

### ProtocolManagerV1 (UUPS — storage collision proof)
| Slot | Variable | Type | Notes |
|------|----------|------|-------|
| 0 | amm | address | |
| 1 | vault | address | |
| 2 | oracle | address | |
| 3 | govToken | address | |
| 4 | version | uint256 | |
| 5 | whitelisted | mapping | |

### ProtocolManagerV2 (extends V1 — appends only)
| Slot | Variable | Type | Notes |
|------|----------|------|-------|
| 0-5 | (V1 storage) | — | unchanged |
| 6 | ammFactory | address | NEW in V2 |
| 7 | protocolFee | uint256 | NEW in V2 |
| 8 | feeRecipient | address | NEW in V2 |

**Storage collision proof:** V2 only appends new variables after V1 slots. No V1 slot is reused or reordered.

---

## 5. Trust Assumptions

### Who Can Do What

| Actor | Power | Risk if Compromised |
|-------|-------|-------------------|
| Deployer (EOA) | Owner of all contracts initially | Can drain vault, change oracle, pause protocol |
| DeFiGovernor | Controls Timelock | Can execute any protocol change after 2-day delay |
| DeFiTimelock | Executes governance decisions | Delayed execution prevents instant attacks |
| Token Holders | Propose and vote | Whale can push malicious proposal if >4% quorum |

### Timelock Powers
- Can call any function on any contract registered in ProtocolManager
- 2-day minimum delay on all actions
- Governor is sole PROPOSER — no one else can schedule

### What Happens if Deployer Key is Compromised
- Attacker can immediately: pause protocol, change fee recipient
- Attacker cannot immediately: steal funds (vault uses user-controlled shares)
- Mitigation: transfer ownership to Timelock after deployment

---

## 6. Architecture Decision Records (ADR)

### ADR-001: UUPS vs Transparent Proxy
- **Context:** Need upgradeable ProtocolManager
- **Options:** Transparent Proxy, UUPS, Beacon Proxy
- **Decision:** UUPS — cheaper deployment, upgrade logic in implementation
- **Consequences:** Must call `_disableInitializers()` in constructor

### ADR-002: AMM from Scratch vs Fork
- **Context:** Need constant-product AMM
- **Options:** Fork Uniswap V2, build from scratch
- **Decision:** Build from scratch — required by spec, better understanding
- **Consequences:** Less battle-tested but fully understood codebase

### ADR-003: Chainlink vs Custom Oracle
- **Context:** Need price feeds for protocol
- **Options:** Chainlink, Uniswap TWAP, custom
- **Decision:** Chainlink — industry standard, staleness check built-in
- **Consequences:** Dependency on Chainlink infrastructure

### ADR-004: ERC-1155 vs ERC-721
- **Context:** Need NFT standard for GameItems
- **Options:** ERC-721 (one token per ID), ERC-1155 (batch)
- **Decision:** ERC-1155 — more gas efficient for multiple item types
- **Consequences:** More complex transfer logic but better UX

### ADR-005: Ethereum Sepolia vs Arbitrum Sepolia
- **Context:** Need L2 testnet deployment
- **Options:** Arbitrum Sepolia, Optimism Sepolia, Base Sepolia
- **Decision:** Ethereum Sepolia — faucets available, Alchemy supported
- **Consequences:** Not true L2 but testnet environment is equivalent

### ADR-006: Governor Quorum 4%
- **Context:** Need governance quorum
- **Options:** 1%, 4%, 10%, 51%
- **Decision:** 4% — matches OpenZeppelin default, prevents spam proposals
- **Consequences:** Low enough for participation, high enough for security

---

## 7. Design Patterns Used

| Pattern | Contract | Justification |
|---------|----------|---------------|
| Factory | AMMFactory | Deploys AMM pairs deterministically via CREATE2 |
| UUPS Proxy | ProtocolManager | Allows protocol upgrades without redeployment |
| Checks-Effects-Interactions | AMM, Vault | Prevents reentrancy by ordering operations |
| ReentrancyGuard | AMM, Vault | Extra protection on state-changing functions |
| Access Control | All contracts | Ownable restricts privileged functions |
| Pausable / Circuit Breaker | ProtocolManager | Emergency stop mechanism |
| Oracle Adapter | PriceOracle | Abstracts Chainlink interface behind protocol interface |
| Timelock | DeFiTimelock | 2-day delay on all governance actions |
| Pull-over-push | Vault | Users pull their own shares, no push payments |
| State Machine | DeFiGovernor | Proposal states: Pending→Active→Succeeded→Queued→Executed |