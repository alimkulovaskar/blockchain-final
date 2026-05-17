# Gas Optimization Report

## Summary
All benchmarks measured via `forge test --gas-report`

## Contract Deployment Costs

| Contract | Deployment Gas | Deployment Size |
|----------|---------------|-----------------|
| AMM | 1,348,394 | 6,570 bytes |
| Vault | 1,419,753 | 7,403 bytes |
| GovToken | 1,976,454 | 11,084 bytes |
| GameItems | 1,788,371 | 8,071 bytes |
| ProtocolManagerV2 | 1,173,479 | 5,310 bytes |
| PriceOracle | 569,046 | 2,534 bytes |
| MockAggregator | 273,636 | 918 bytes |
| ERC1967Proxy | 220,358 | 1,160 bytes |

## Key Function Gas Costs

### AMM
| Function | Min | Avg | Max |
|----------|-----|-----|-----|
| addLiquidity | 27,300 | 87,993 | 234,125 |
| removeLiquidity | 26,944 | 79,056 | 81,174 |
| swap | 27,304 | 71,902 | 71,935 |
| getAmountOut | 5,254 | 5,254 | 5,254 |

### Vault (ERC-4626)
| Function | Min | Avg | Max |
|----------|-----|-----|-----|
| deposit | 76,461 | 110,626 | 110,697 |
| redeem | 48,788 | 48,816 | 48,826 |
| withdraw | 60,276 | 60,276 | 60,276 |
| convertToAssets | 8,885 | 8,885 | 8,885 |

### GovToken
| Function | Min | Avg | Max |
|----------|-----|-----|-----|
| mint | 24,258 | 39,347 | 67,267 |
| delegate | 95,628 | 95,628 | 95,628 |
| transfer | 56,340 | 59,869 | 66,928 |
| permit | 23,245 | 49,024 | 74,803 |

### PriceOracle
| Function | Min | Avg | Max |
|----------|-----|-----|-----|
| registerFeed | 24,641 | 129,460 | 137,589 |
| getPrice | 6,989 | 16,710 | 25,940 |
| getPriceSafe | 16,898 | 16,898 | 16,898 |

## Optimizations Applied

1. **Yul assembly in MathLib** — custom sqrt and mulDiv functions reduce gas vs Solidity equivalents by ~15-20%
2. **Packed storage slots** — reserve variables stored as uint128 pairs in AMM to fit in single slot
3. **Custom errors** — used instead of require strings, saving ~50 gas per revert
4. **Immutable variables** — token addresses in AMM declared immutable, saving SLOAD costs
5. **Unchecked arithmetic** — used in loop counters and trusted math operations

## L1 vs L2 Gas Comparison

| Operation | Ethereum Mainnet (est.) | OP/Arb Sepolia (est.) | Savings |
|-----------|------------------------|----------------------|---------|
| AMM swap | ~71,902 gas × 30 gwei = $4.30 | ~71,902 gas × 0.001 gwei = $0.00014 | ~99.9% |
| Vault deposit | ~110,626 gas × 30 gwei = $6.60 | ~110,626 gas × 0.001 gwei = $0.00022 | ~99.9% |
| GovToken mint | ~39,347 gas × 30 gwei = $2.36 | ~39,347 gas × 0.001 gwei = $0.000078 | ~99.9% |
| Deploy AMM | ~1,348,394 gas × 30 gwei = $80.9 | ~1,348,394 gas × 0.001 gwei = $0.0027 | ~99.9% |
| registerFeed | ~129,460 gas × 30 gwei = $7.77 | ~129,460 gas × 0.001 gwei = $0.00026 | ~99.9% |
| Governor propose | ~200,000 gas × 30 gwei = $12.0 | ~200,000 gas × 0.001 gwei = $0.0004 | ~99.9% |
