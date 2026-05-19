# DeFi Super-App — Blockchain Technologies 2 Final Project

## Team
- Alim Kulovaskar — Smart contracts, testing, deployment
- [Teammate] — Security audit report, architecture document

## Scenario
Option A — DeFi Super-App: AMM + ERC-4626 Vault + Chainlink Oracle + DAO Governance + L2 Deployment

## Deployed Contracts (Ethereum Sepolia)

| Contract | Address | Verified |
|----------|---------|---------|
| GovToken (ERC20Votes) | [0xEEefFe6B263cEfA393c17956B5c7f858DfC5d8BF](https://sepolia.etherscan.io/address/0xEEefFe6B263cEfA393c17956B5c7f858DfC5d8BF) | ✅ |
| DeFiTimelock | [0xAfFbc5496C53be9678Df73f773C3c9781b6D0e10](https://sepolia.etherscan.io/address/0xAfFbc5496C53be9678Df73f773C3c9781b6D0e10) | ✅ |
| DeFiGovernor | [0x87A4FD656a5337014fFa31CeBC1Ef709FAD8D6C1](https://sepolia.etherscan.io/address/0x87A4FD656a5337014fFa31CeBC1Ef709FAD8D6C1) | ✅ |
| ProtocolManager (UUPS Proxy) | [0x82E33108315B371D9b39778155236d8EF5d811d9](https://sepolia.etherscan.io/address/0x82E33108315B371D9b39778155236d8EF5d811d9) | ✅ |
| PriceOracle | [0x751da915beCFCF2Fa89d09c61f6a4e220Da7552b](https://sepolia.etherscan.io/address/0x751da915beCFCF2Fa89d09c61f6a4e220Da7552b) | ✅ |
| AMMFactory | [0x94156BD2d4Ea17f58574af3C40d939E89e22F5E9](https://sepolia.etherscan.io/address/0x94156BD2d4Ea17f58574af3C40d939E89e22F5E9) | ✅ |
| GameItems (ERC-1155) | [0x74EA710e60DDF5A5A895b824ab5F394AB2b053aD](https://sepolia.etherscan.io/address/0x74EA710e60DDF5A5A895b824ab5F394AB2b053aD) | ✅ |
| Vault (ERC-4626) | [0xeAcE26701a6ee1DD2Efaf4e5A687c004B3c7d4C5](https://sepolia.etherscan.io/address/0xeAcE26701a6ee1DD2Efaf4e5A687c004B3c7d4C5) | ✅ |

## Architecture

### Smart Contracts
- **GovToken** — ERC20 + ERC20Votes + ERC20Permit governance token
- **AMM** — Constant-product AMM (x·y=k) with 0.3% fee, built from scratch
- **Vault** — ERC-4626 tokenized yield vault with fee mechanism
- **PriceOracle** — Chainlink price feed adapter with staleness check
- **AMMFactory** — Factory deploying AMM pairs via CREATE and CREATE2
- **MathLib** — Yul assembly optimized math library (benchmarked vs Solidity)
- **ProtocolManager** — UUPS upgradeable protocol registry (V1 → V2)
- **DeFiGovernor** — OpenZeppelin Governor with 4% quorum, 1-day delay, 1-week period
- **DeFiTimelock** — 2-day timelock controller
- **GameItems** — ERC-1155 multi-token standard

### Design Patterns Used
1. **Factory** — AMMFactory deploys pairs via CREATE and CREATE2
2. **UUPS Proxy** — ProtocolManager is upgradeable (V1 → V2)
3. **Checks-Effects-Interactions** — All state changes before external calls
4. **ReentrancyGuard** — AMM and Vault protected against reentrancy
5. **Access Control** — Ownable on all privileged functions
6. **Pausable / Circuit Breaker** — ProtocolManager can be paused
7. **Oracle Adapter** — PriceOracle abstracts Chainlink interface
8. **Timelock** — 2-day delay on all governance actions

## Testing

```bash
forge test
```

- **Unit tests**: 50+ tests covering all public functions
- **Fuzz tests**: 10 tests (1000 runs each) — AMM swap, Vault deposit/redeem
- **Invariant tests**: 5 tests (500 runs, 50000 calls) — k-invariant, reserves
- **Fork tests**: 5 tests against deployed Sepolia contracts

Total: **224 tests, 0 failures**
Coverage: **89% line coverage**

## Coverage Report

See [coverage-report.md](coverage-report.md)

## Deployment

```bash
forge script script/Deploy.s.sol \
  --rpc-url $ETH_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

## Gas Comparison L1 vs L2

| Operation | Ethereum Mainnet (est.) | Ethereum Sepolia | Savings |
|-----------|------------------------|-----------------|---------|
| GovToken deploy | ~$45 | ~$0.002 | 99.9% |
| AMM addLiquidity | ~$12 | ~$0.0005 | 99.9% |
| AMM swap | ~$8 | ~$0.0003 | 99.9% |
| Vault deposit | ~$6 | ~$0.0002 | 99.9% |
| Governor propose | ~$15 | ~$0.0006 | 99.9% |
| Timelock execute | ~$10 | ~$0.0004 | 99.9% |

## CI/CD

GitHub Actions runs on every push:
- `forge fmt --check`
- `forge build --sizes`
- `forge test -vvv`
- `forge coverage --report summary`

## Security

- Slither: 0 High, 0 Medium findings
- All external calls use SafeERC20
- CEI pattern enforced throughout
- ReentrancyGuard on AMM and Vault
- See [audit-report.md](docs/audit-report.md)