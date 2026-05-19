# Architecture & Design Document
## DeFi Super-App — Blockchain Technologies 2 Final Project

**Team:** Alimkulov Askar, Zhanadil Bexultan
**Scenario:** Option A — DeFi Super-App
**Network:** Ethereum Sepolia Testnet
**Date:** May 2026
**Repository:** https://github.com/alimkulovaskar/blockchain-final

---

## 1. System Context (C4 Level 1)

The DeFi Super-App is a decentralized protocol that enables users to swap tokens via an AMM, earn yield via an ERC-4626 vault, and govern the protocol via a DAO. All on-chain activity is indexed by The Graph and surfaced via a React frontend dApp.

```
┌──────────────────────────────────────────────────────────────────────┐
│                          SYSTEM CONTEXT                              │
│                                                                      │
│   [End User]                                                         │
│       │  MetaMask wallet                                             │
│       ▼                                                              │
│   [Frontend dApp]  ◀──────────────  [The Graph]                     │
│       │  ethers.js / wagmi                  GraphQL queries          │
│       ▼                                         ▲                   │
│   [Smart Contracts on Ethereum Sepolia]  ───────┘                   │
│       │  events emitted on-chain                                     │
│       ▼                                                              │
│   [Chainlink Oracle Network]                                         │
│       ETH/USD price feed → PriceOracle contract                     │
└──────────────────────────────────────────────────────────────────────┘
```

### External Actors

| Actor | Description | Interaction |
|-------|-------------|-------------|
| End User | Token holder, LP, DAO voter | Frontend → MetaMask → contracts |
| Chainlink | Decentralized oracle network | Provides ETH/USD price feed |
| The Graph | Subgraph indexer | Reads events, serves GraphQL API |
| Ethereum Sepolia | EVM-compatible testnet | Hosts all deployed contracts |

---

## 2. Container & Component Diagram

### 2.1 Smart Contract Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        GOVERNANCE LAYER                             │
│                                                                     │
│  ┌──────────────┐     ┌─────────────────────┐   ┌───────────────┐  │
│  │   GovToken   │     │    DeFiGovernor      │   │ DeFiTimelock  │  │
│  │ ERC20Votes   │────▶│  voting delay: 1d    │──▶│  delay: 2d    │  │
│  │ ERC20Permit  │     │  period: 1 week      │   │  PROPOSER:    │  │
│  │ MAX: 1M tkns │     │  quorum: 4%          │   │  Governor     │  │
│  └──────────────┘     │  threshold: 1%       │   └───────────────┘  │
│                       └─────────────────────┘                       │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                           CORE LAYER                                │
│                                                                     │
│  ┌──────────────┐     ┌─────────────────────┐   ┌───────────────┐  │
│  │     AMM      │     │        Vault         │   │  AMMFactory   │  │
│  │   x·y=k     │     │      ERC-4626        │   │  CREATE2      │  │
│  │  fee: 0.3%  │     │  feeBps max 10%      │   │  determinism  │  │
│  │  LP tokens  │     │  SafeERC20           │   │  pair mapping │  │
│  │  nonReentrant     │  nonReentrant        │   └───────────────┘  │
│  └──────────────┘     └─────────────────────┘                       │
│                                                                     │
│  ┌──────────────┐     ┌─────────────────────┐   ┌───────────────┐  │
│  │ PriceOracle  │     │  ProtocolManager     │   │   GameItems   │  │
│  │  Chainlink   │     │   UUPS Proxy         │   │   ERC-1155    │  │
│  │  staleness   │     │   V1 → V2            │   │   Pausable    │  │
│  │  check       │     │   upgradeable        │   │   AccessCtrl  │  │
│  └──────────────┘     └─────────────────────┘   └───────────────┘  │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                         SUPPORT LAYER                               │
│                                                                     │
│  ┌──────────────┐     ┌─────────────────────┐                       │
│  │   MathLib    │     │   MockAggregator     │                       │
│  │ Yul assembly │     │  test-only oracle    │                       │
│  │ min/max/sqrt │     │  AggregatorV3Interface│                      │
│  └──────────────┘     └─────────────────────┘                       │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 Deployed Contract Addresses (Ethereum Sepolia)

| Contract | Address |
|----------|---------|
| GovToken | `0xEEefFe6B263cEfA393c17956B5c7f858DfC5d8BF` |
| DeFiTimelock | `0xAfFbc5496C53be9678Df73f773C3c9781b6D0e10` |
| DeFiGovernor | `0x87A4FD656a5337014fFa31CeBC1Ef709FAD8D6C1` |
| ProtocolManager (proxy) | `0x82E33108315B371D9b39778155236d8EF5d811d9` |
| PriceOracle | `0x751da915beCFCF2Fa89d09c61f6a4e220Da7552b` |
| AMMFactory | `0x94156BD2d4Ea17f58574af3C40d939E89e22F5E9` |
| GameItems | `0x74EA710e60DDF5A5A895b824ab5F394AB2b053aD` |
| Vault | `0xeAcE26701a6ee1DD2Efaf4e5A687c004B3c7d4C5` |

### 2.3 Access Control Roles

| Contract | Role | Holder | Permissions |
|----------|------|--------|-------------|
| GovToken | Owner | Deployer | mint, transferOwnership |
| PriceOracle | Owner | Deployer | registerFeed, deactivateFeed |
| AMMFactory | Owner | Deployer | createPair |
| Vault | Owner | Deployer | setFeeBps, collectFee, setFeeRecipient |
| DeFiTimelock | PROPOSER_ROLE | DeFiGovernor | schedule operations |
| DeFiTimelock | EXECUTOR_ROLE | DeFiGovernor | execute operations |
| DeFiTimelock | DEFAULT_ADMIN_ROLE | Deployer | grant/revoke roles |
| ProtocolManager | Owner | Deployer | register contracts, pause, upgrade |
| GameItems | MINTER_ROLE | Deployer | mint tokens |
| GameItems | DEFAULT_ADMIN_ROLE | Deployer | grant roles |

### 2.4 External Dependencies

| Dependency | Purpose | Version / Address |
|------------|---------|-------------------|
| OpenZeppelin Contracts | Base contracts (ERC20, Governor, Proxy) | v5.6.1 |
| OpenZeppelin Upgradeable | UUPS upgradeable contracts | v5.6.1 |
| Chainlink ETH/USD feed | Price feed (Sepolia) | `0x694AA1769357215DE4FAC081bf1f309aDC325306` |
| The Graph | Event indexing + GraphQL | Studio hosted subgraph |

---

## 3. Sequence Diagrams

### 3.1 AMM Swap (x·y=k, 0.3% fee)

```
User          Frontend           AMM              TokenA/B
 │               │                │                  │
 │  enter amount │                │                  │
 │──────────────▶│                │                  │
 │               │  approve(amm, amountIn)           │
 │               │─────────────────────────────────▶│
 │               │  swap(tokenIn, amountIn, minOut, to)
 │               │───────────────▶│                  │
 │               │                │ [nonReentrant]   │
 │               │                │ CHECK: amountIn > 0
 │               │                │ CHECK: token == tokenA or tokenB
 │               │                │ CALC:  amountOut =
 │               │                │   (amtIn * 997 * resOut)
 │               │                │   / (resIn * 1000 + amtIn * 997)
 │               │                │ CHECK: amountOut >= minAmountOut
 │               │                │ EFFECT: reserveIn  += amountIn
 │               │                │ EFFECT: reserveOut -= amountOut
 │               │                │ INTERACT: transferFrom(user → AMM)
 │               │                │ INTERACT: transfer(to, amountOut)
 │               │                │ emit Swap(...)    │
 │  receive tokenOut              │                  │
 │◀──────────────│                │                  │
```

### 3.2 Governance: Propose → Vote → Queue → Execute

```
Proposer        Governor          Timelock          Target
 │                 │                  │                │
 │  propose(targets, values, calldatas, description)  │
 │────────────────▶│                  │                │
 │                 │ CHECK: getVotes(proposer) >= proposalThreshold (1%)
 │                 │ EFFECT: store proposal, snapshot block
 │                 │ emit ProposalCreated(proposalId)  │
 │                 │                  │                │
 │   ◀─── 1 day voting delay ───▶    │                │
 │                 │                  │                │
 │  castVote(proposalId, support=1)  │                │
 │────────────────▶│                  │                │
 │                 │ CHECK: state == Active            │
 │                 │ CHECK: !hasVoted(voter)           │
 │                 │ EFFECT: forVotes += getVotes(voter)
 │                 │ emit VoteCast(...)                │
 │                 │                  │                │
 │   ◀─── 1 week voting period ───▶  │                │
 │                 │                  │                │
 │  queue(targets, values, calldatas, descHash)       │
 │────────────────▶│                  │                │
 │                 │ CHECK: state == Succeeded         │
 │                 │ CHECK: forVotes >= quorum (4%)    │
 │                 │ schedule(targets, values...)      │
 │                 │─────────────────▶│                │
 │                 │                  │ store operationId
 │                 │ emit ProposalQueued(...)          │
 │                 │                  │                │
 │   ◀─── 2 day timelock delay ───▶  │                │
 │                 │                  │                │
 │  execute(targets, values, calldatas, descHash)     │
 │────────────────▶│                  │                │
 │                 │ execute(targets, values...)       │
 │                 │─────────────────▶│                │
 │                 │                  │ call(target)  │
 │                 │                  │──────────────▶│
 │                 │ emit ProposalExecuted(proposalId) │
```

### 3.3 ERC-4626 Vault: Deposit & Redeem

```
User          Frontend          GovToken             Vault
 │               │                  │                  │
 │  enter assets │                  │                  │
 │──────────────▶│                  │                  │
 │               │  approve(vault, assets)             │
 │               │─────────────────▶│                  │
 │               │  deposit(assets, receiver)          │
 │               │──────────────────────────────────▶ │
 │               │                  │ [nonReentrant]   │
 │               │                  │ shares = convertToShares(assets)
 │               │                  │ transferFrom(user, vault, assets)
 │               │                  │ _mint(receiver, shares)
 │               │                  │ emit Deposit(...)│
 │  receive vault shares            │                  │
 │◀──────────────│                  │                  │
 │               │                  │                  │
 │  redeem(shares, receiver, owner) │                  │
 │──────────────▶│                  │                  │
 │               │──────────────────────────────────▶ │
 │               │                  │ [nonReentrant]   │
 │               │                  │ assets = convertToAssets(shares)
 │               │                  │ _burn(owner, shares)
 │               │                  │ transfer(receiver, assets)
 │               │                  │ emit Withdraw(...)
 │  receive underlying assets       │                  │
 │◀──────────────│                  │                  │
```

---

## 4. Data Model & Storage Layout

### 4.1 GovToken

| Slot | Variable | Type | Notes |
|------|----------|------|-------|
| inherited | ERC20 state | balances, allowances, name, symbol | OpenZeppelin |
| inherited | ERC20Votes | checkpoints, delegation mapping | snapshot-based |
| inherited | Ownable | `_owner` | address |
| constant | MAX_SUPPLY | uint256 | 1_000_000 ether, not a slot |

### 4.2 AMM

| Slot | Variable | Type | Notes |
|------|----------|------|-------|
| inherited | ERC20 (LP token) | balances, supply, allowances | LP token |
| inherited | ReentrancyGuard | `_status` | uint256 (1 or 2) |
| inherited | Ownable | `_owner` | address |
| 0 | tokenA | address | immutable |
| 1 | tokenB | address | immutable |
| 2 | reserveA | uint256 | updated on every swap |
| 3 | reserveB | uint256 | updated on every swap |

### 4.3 Vault (ERC-4626)

| Slot | Variable | Type | Notes |
|------|----------|------|-------|
| inherited | ERC20 (share token) | balances, supply | share accounting |
| inherited | ERC4626 | `_asset` | underlying ERC-20 |
| inherited | Ownable | `_owner` | address |
| inherited | ReentrancyGuard | `_status` | uint256 |
| 0 | MAX_FEE_BPS | uint256 | constant 1000 (= 10%) |
| 1 | feeBps | uint256 | current fee in bps |
| 2 | feeRecipient | address | fee receiver |
| 3 | totalFeeCollected | uint256 | accumulated fee balance |

### 4.4 ProtocolManagerV1 (UUPS — storage collision proof)

| Slot | Variable | Type | Notes |
|------|----------|------|-------|
| 0 | amm | address | registered AMM |
| 1 | vault | address | registered Vault |
| 2 | oracle | address | registered Oracle |
| 3 | govToken | address | registered GovToken |
| 4 | protocolVersion | uint256 | version number |
| 5 | whitelisted | mapping(address→bool) | access list |

### 4.5 ProtocolManagerV2 (extends V1 — append-only, no collisions)

| Slot | Variable | Type | Notes |
|------|----------|------|-------|
| 0–5 | V1 storage | — | **identical to V1, unchanged** |
| 6 | protocolFee | uint256 | NEW — basis points, max 1000 |
| 7 | feeRecipient | address | NEW — fee receiver |
| 8 | totalFeesCollected | uint256 | NEW — fee accounting |
| 9 | emergencyPaused | bool | NEW — circuit breaker flag |

**Storage collision proof:** V2 exclusively appends new slots after position 5. No V1 variable is reused, reordered, or resized. `_disableInitializers()` called in constructor prevents re-initialization attacks on the implementation contract.

### 4.6 PriceOracle

| Slot | Variable | Type | Notes |
|------|----------|------|-------|
| inherited | Ownable | `_owner` | address |
| 0 | feeds | mapping(address→FeedConfig) | token → config |
| 1 | registeredTokens | address[] | enumerable list |

FeedConfig struct layout:
```
struct FeedConfig {
    AggregatorV3Interface feed;  // Chainlink aggregator address
    uint256 stalenessThreshold;  // max seconds since last update
    bool active;                 // is feed active
}
```

---

## 5. Trust Assumptions

### 5.1 Who Controls What

| Actor | Powers | Risk if Compromised |
|-------|--------|-------------------|
| Deployer EOA | Owner of all contracts | Can pause, change fees, register malicious oracle |
| DeFiGovernor | Sole PROPOSER on Timelock | Can queue malicious protocol changes |
| DeFiTimelock | Executes queued operations | 2-day delay gives community time to react |
| Token Holders (>1%) | Propose changes | Can push self-serving proposals |
| Token Holders (>4%) | Reach quorum alone | Can force through proposal without others |
| MINTER_ROLE holder | Mint GameItems | Can inflate item supply |

### 5.2 Timelock Powers
- Can call `upgradeToAndCall()` on ProtocolManager proxy
- Can update oracle feeds via PriceOracle owner functions
- Can change vault fee parameters
- Can pause/unpause protocol
- **All actions subject to minimum 2-day delay**
- Only DeFiGovernor can schedule — no individual can bypass

### 5.3 If Deployer Key is Compromised
- **Can do immediately:** pause protocol, change fee recipient, register malicious price feed
- **Cannot do immediately:** steal vault assets (ERC-4626 shares are user-controlled), bypass 2-day timelock for governance actions
- **Mitigation:** transfer all contract ownership to Timelock post-deployment; use hardware wallet or multisig

### 5.4 If Governor Contract is Compromised
- Can schedule malicious Timelock operations
- 2-day delay gives token holders time to detect and cancel
- Community can vote to cancel malicious proposals during active voting period

---

## 6. Architecture Decision Records (ADR)

### ADR-001: UUPS vs Transparent Proxy
- **Context:** ProtocolManager stores protocol-wide configuration and must be upgradeable
- **Options considered:** Transparent Proxy (OpenZeppelin), UUPS, Beacon Proxy
- **Decision:** UUPS — upgrade logic lives in implementation, reducing proxy deployment cost; no proxy admin address needed; `_authorizeUpgrade` protected by `onlyOwner`
- **Consequences:** Must call `_disableInitializers()` in constructor to prevent implementation contract initialization attack

### ADR-002: AMM from Scratch vs Uniswap V2 Fork
- **Context:** Protocol requires constant-product AMM with 0.3% fee and LP tokens
- **Options considered:** Fork Uniswap V2 core, build from scratch
- **Decision:** Build from scratch — required by project specification; enables full auditability and understanding of every line
- **Consequences:** Less battle-tested than Uniswap; compensated by 224 tests including invariant testing with 50,000 calls per invariant

### ADR-003: Chainlink vs Custom Oracle
- **Context:** Protocol needs reliable, manipulation-resistant price feeds
- **Options considered:** Chainlink AggregatorV3, Uniswap V3 TWAP, custom price contract
- **Decision:** Chainlink — industry standard, aggregates from multiple sources, staleness check natively supported
- **Consequences:** Dependency on Chainlink infrastructure; mitigated by `getPriceSafe()` fallback that catches oracle failures

### ADR-004: ERC-1155 vs ERC-721 for GameItems
- **Context:** Protocol needs NFT standard supporting multiple item types with supply tracking
- **Options considered:** ERC-721 (one NFT per token ID), ERC-1155 (fungible + non-fungible batch)
- **Decision:** ERC-1155 — batch minting/transfers are more gas efficient; multiple item types supported natively; `totalSupply()` per token ID
- **Consequences:** More complex interface; offset by full test coverage (100% line coverage on GameItems)

### ADR-005: GovernorVotesQuorumFraction vs Fixed Quorum
- **Context:** Governance quorum must be meaningful relative to circulating supply
- **Options considered:** Fixed quorum (e.g. 40,000 tokens), percentage-based fraction
- **Decision:** `GovernorVotesQuorumFraction(4)` — 4% of total supply at snapshot block; scales automatically with token distribution
- **Consequences:** Early governance when supply is concentrated is easier to reach quorum; acceptable tradeoff for testnet phase

### ADR-006: Vault Fee Model
- **Context:** Protocol needs sustainable fee mechanism without complexity
- **Options considered:** Performance fee on yield, management fee on AUM, flat deposit fee
- **Decision:** Basis-point fee on deposits (`feeBps`, max 10%), collected by owner via explicit `collectFee()` call
- **Consequences:** Simple, auditable, owner-controlled; can be adjusted via governance proposal through Timelock

---

## 7. Design Patterns

| Pattern | Contract(s) | Justification |
|---------|-------------|---------------|
| **Factory** | AMMFactory | Deploys AMM pairs via CREATE (standard) and CREATE2 (deterministic addresses). Enables address prediction before deployment and deduplication via pair mapping. |
| **Proxy / UUPS** | ProtocolManager | Protocol parameters must be upgradeable without redeployment. UUPS chosen over Transparent Proxy: lower gas, upgrade logic in implementation, no proxy admin EOA. |
| **Checks-Effects-Interactions** | AMM, Vault, PriceOracle | All state-changing functions: validate inputs (CHECK), update state (EFFECT), then call external contracts (INTERACT). Prevents reentrancy at pattern level. |
| **Reentrancy Guard** | AMM, Vault | `nonReentrant` modifier on all state-changing functions as defense-in-depth beyond CEI ordering. |
| **Access Control / Ownable** | All contracts | Every privileged function gated by `onlyOwner` or AccessControl role check. No unguarded admin functions exist in the codebase. |
| **Pausable / Circuit Breaker** | ProtocolManagerV2, GameItems | `emergencyPause()` allows halting protocol activity instantly in response to detected attack or exploit. |
| **Oracle Adapter** | PriceOracle | Abstracts Chainlink `AggregatorV3Interface` behind a protocol-specific interface. Centralizes staleness check, price validation, and feed management. |
| **Timelock** | DeFiTimelock | All governance decisions delayed minimum 2 days. Prevents flash-loan governance attacks and gives community time to react to malicious proposals. |
| **State Machine** | DeFiGovernor | Proposal lifecycle enforced as explicit state machine: `Pending → Active → Succeeded/Defeated → Queued → Executed/Canceled`. Each transition validated. |
| **Pull-over-Push** | Vault | Users call `redeem()` or `withdraw()` to pull their own assets. No push payments that could fail silently or be frontrun. |

---

## 8. Gas Optimization Report

### 8.1 MathLib: Yul Assembly vs Pure Solidity

All four MathLib functions are implemented in both pure Solidity and inline Yul assembly. Benchmarked via `forge test --match-contract MathLibTest --gas-report`.

| Function | Solidity Gas | Yul Assembly Gas | Gas Saved | Savings % |
|----------|-------------|-----------------|-----------|-----------|
| `min(a, b)` | 312 | 285 | 27 | 8.7% |
| `max(a, b)` | 318 | 289 | 29 | 9.1% |
| `mulDiv(a,b,c)` | 450 | 398 | 52 | 11.6% |
| `sqrt(x)` | 890 | 701 | 189 | 21.2% |

Fuzz tests confirm functional equivalence across all input ranges:
- `testFuzz_minMatchesSolidity` — 1000 runs
- `testFuzz_mulDivMatchesSolidity` — 1000 runs
- `testFuzz_sqrtMatchesSolidity` — 1000 runs

### 8.2 AMM Operations Gas Costs

| Operation | Gas Used | Notes |
|-----------|---------|-------|
| `addLiquidity` (initial) | ~255,000 | Includes LP token mint |
| `addLiquidity` (subsequent) | ~180,000 | No mint overhead |
| `swap` (A→B) | ~90,000 | Two reserve updates + two transfers |
| `removeLiquidity` | ~120,000 | LP burn + two safeTransfers |
| `createPair` (CREATE) | ~1,335,000 | Full AMM deployment |
| `createPair` (CREATE2) | ~1,352,000 | +17k for deterministic salt |

### 8.3 Governance Gas Costs

| Operation | Gas Used | Notes |
|-----------|---------|-------|
| `propose()` | ~75,000 | Snapshot + storage write |
| `castVote()` | ~65,000 | Checkpoint update |
| `queue()` | ~120,000 | Timelock schedule call |
| `execute()` | ~200,000+ | Depends on target call |

### 8.4 Compiler Settings
```toml
optimizer = true
optimizer_runs = 200
solc = "0.8.24"
```
`optimizer_runs = 200` chosen as balance between deployment cost and per-call cost, appropriate for a protocol with moderate transaction volume.