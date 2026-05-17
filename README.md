# Blockchain Final Project — DeFi Super-App

## Overview
A production-grade decentralized protocol implementing Option A (DeFi Super-App):
AMM + ERC-4626 Vault + Chainlink Oracle + DAO Governance + ERC-1155 GameItems.

## Team
- Alimkulov Askar — Smart Contracts, Testing, Deployment

## Deployed Contracts (Ethereum Sepolia)

| Contract | Address | Etherscan |
|----------|---------|-----------|
| GovToken | `0xC1f7DC526304E2686757B9fB3e791e9Ee079191E` | [View](https://sepolia.etherscan.io/address/0xC1f7DC526304E2686757B9fB3e791e9Ee079191E) |
| DeFiTimelock | `0x3Fa7a651Ad14954fBf236980346d4de5AA735260` | [View](https://sepolia.etherscan.io/address/0x3Fa7a651Ad14954fBf236980346d4de5AA735260) |
| DeFiGovernor | `0xbd1573f57F70B0f5EAaE7Bd05690a354f50cbb96` | [View](https://sepolia.etherscan.io/address/0xbd1573f57F70B0f5EAaE7Bd05690a354f50cbb96) |
| ProtocolManager (Proxy) | `0x52be027546874447C5d43aaF1B1A6daA3b84C8aF` | [View](https://sepolia.etherscan.io/address/0x52be027546874447C5d43aaF1B1A6daA3b84C8aF) |
| PriceOracle | `0x9878cc95b37903b0e191CD74f818E2F0e07cc48c` | [View](https://sepolia.etherscan.io/address/0x9878cc95b37903b0e191CD74f818E2F0e07cc48c) |
| AMMFactory | `0x20d49b0588B8cB7379f05C49ca79de608Ab75E79` | [View](https://sepolia.etherscan.io/address/0x20d49b0588B8cB7379f05C49ca79de608Ab75E79) |
| GameItems | `0x8a82858C2e9Acee25afCF4cEeCBd5857f657a697` | [View](https://sepolia.etherscan.io/address/0x8a82858C2e9Acee25afCF4cEeCBd5857f657a697) |
| Vault | `0xd43758A28d5433A76Ce25391e3D58d43376e6f24` | [View](https://sepolia.etherscan.io/address/0xd43758A28d5433A76Ce25391e3D58d43376e6f24) |

## Architecture

### Smart Contracts
- **GovToken** — ERC20Votes + ERC20Permit governance token
- **DeFiGovernor** — OpenZeppelin Governor with 1-day voting delay, 1-week period, 4% quorum
- **DeFiTimelock** — TimelockController with 2-day delay
- **AMM** — Constant-product AMM (x*y=k) with 0.3% fee, LP tokens, slippage protection
- **AMMFactory** — Deploys AMM pairs via CREATE and CREATE2
- **Vault** — ERC-4626 tokenized yield vault
- **PriceOracle** — Chainlink price feed integration with staleness check
- **ProtocolManager** — UUPS upgradeable contract (V1 → V2 upgrade path)
- **GameItems** — ERC-1155 multi-token with minting, burning, pausable

### Design Patterns Used
1. **UUPS Proxy** — ProtocolManager upgradeable V1→V2
2. **Factory** — AMMFactory using CREATE and CREATE2
3. **Checks-Effects-Interactions** — All state-changing functions
4. **Access Control** — Ownable + role-based permissions
5. **Timelock** — 2-day delay on governance actions
6. **Reentrancy Guard** — AMM and Vault
7. **Pausable / Circuit Breaker** — GameItems and ProtocolManagerV2
8. **Oracle Adapter** — PriceOracle abstracts Chainlink interface
9. **Pull-over-push** — Fee collection pattern in Vault

## Installation

```bash
git clone https://github.com/alimkulovaskar/blockchain-final
cd blockchain-final
forge install
```

## Testing

```bash
# Run all tests
forge test -vvv

# Run with gas report
forge test --gas-report

# Run coverage
forge coverage

# Run specific suite
forge test --match-contract AMMTest -vvv
```

## Test Results
- **101 tests total** — all passing
- Unit tests: 68
- Fuzz tests: 10 (1000 runs each)
- Invariant tests: 3 (500 runs, 50,000 calls each)
- Fork tests: 5

## Deployment

```bash
# Deploy to Sepolia
source .env && forge script script/Deploy.s.sol \
  --rpc-url $ETH_SEPOLIA_RPC_URL \
  --broadcast --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY -vvv
```

## Documentation
- `docs/gas-report.md` — Gas optimization report
- `docs/architecture.md` — Architecture & design document (see napkin)
- `docs/audit.md` — Security audit report

## CI/CD
GitHub Actions runs on every push:
- `forge build` — compilation check
- `forge test -vvv` — full test suite
- `forge fmt --check` — formatting check