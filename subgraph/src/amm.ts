import { BigInt, Bytes } from "@graphprotocol/graph-sdk";
import {
  Swap as SwapEvent,
  LiquidityAdded as LiquidityAddedEvent,
  LiquidityRemoved as LiquidityRemovedEvent,
} from "../generated/AMM/AMM";
import { Pool, Swap, LiquidityEvent, ProtocolStats } from "../generated/schema";

function getOrCreatePool(address: Bytes): Pool {
  let pool = Pool.load(address.toHexString());
  if (!pool) {
    pool = new Pool(address.toHexString());
    pool.tokenA = Bytes.empty();
    pool.tokenB = Bytes.empty();
    pool.reserveA = BigInt.fromI32(0);
    pool.reserveB = BigInt.fromI32(0);
    pool.totalLPSupply = BigInt.fromI32(0);
    pool.txCount = BigInt.fromI32(0);
    pool.createdAt = BigInt.fromI32(0);
  }
  return pool;
}

function getOrCreateStats(): ProtocolStats {
  let stats = ProtocolStats.load("1");
  if (!stats) {
    stats = new ProtocolStats("1");
    stats.totalSwaps = BigInt.fromI32(0);
    stats.totalLiquidityEvents = BigInt.fromI32(0);
    stats.totalProposals = BigInt.fromI32(0);
    stats.totalVotes = BigInt.fromI32(0);
    stats.totalVaultDeposits = BigInt.fromI32(0);
    stats.updatedAt = BigInt.fromI32(0);
  }
  return stats;
}

export function handleSwap(event: SwapEvent): void {
  let pool = getOrCreatePool(event.address);
  pool.txCount = pool.txCount.plus(BigInt.fromI32(1));
  pool.save();

  let swap = new Swap(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  swap.pool = pool.id;
  swap.user = event.params.user;
  swap.tokenIn = event.params.tokenIn;
  swap.amountIn = event.params.amountIn;
  swap.amountOut = event.params.amountOut;
  swap.timestamp = event.block.timestamp;
  swap.blockNumber = event.block.number;
  swap.save();

  let stats = getOrCreateStats();
  stats.totalSwaps = stats.totalSwaps.plus(BigInt.fromI32(1));
  stats.updatedAt = event.block.timestamp;
  stats.save();
}

export function handleLiquidityAdded(event: LiquidityAddedEvent): void {
  let pool = getOrCreatePool(event.address);
  pool.reserveA = pool.reserveA.plus(event.params.amountA);
  pool.reserveB = pool.reserveB.plus(event.params.amountB);
  pool.save();

  let liqEvent = new LiquidityEvent(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  liqEvent.pool = pool.id;
  liqEvent.provider = event.params.provider;
  liqEvent.amountA = event.params.amountA;
  liqEvent.amountB = event.params.amountB;
  liqEvent.lpTokens = event.params.lpTokens;
  liqEvent.eventType = "ADD";
  liqEvent.timestamp = event.block.timestamp;
  liqEvent.blockNumber = event.block.number;
  liqEvent.save();

  let stats = getOrCreateStats();
  stats.totalLiquidityEvents = stats.totalLiquidityEvents.plus(BigInt.fromI32(1));
  stats.updatedAt = event.block.timestamp;
  stats.save();
}

export function handleLiquidityRemoved(event: LiquidityRemovedEvent): void {
  let pool = getOrCreatePool(event.address);
  pool.reserveA = pool.reserveA.minus(event.params.amountA);
  pool.reserveB = pool.reserveB.minus(event.params.amountB);
  pool.save();

  let liqEvent = new LiquidityEvent(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  liqEvent.pool = pool.id;
  liqEvent.provider = event.params.provider;
  liqEvent.amountA = event.params.amountA;
  liqEvent.amountB = event.params.amountB;
  liqEvent.lpTokens = event.params.lpTokens;
  liqEvent.eventType = "REMOVE";
  liqEvent.timestamp = event.block.timestamp;
  liqEvent.blockNumber = event.block.number;
  liqEvent.save();

  let stats = getOrCreateStats();
  stats.totalLiquidityEvents = stats.totalLiquidityEvents.plus(BigInt.fromI32(1));
  stats.updatedAt = event.block.timestamp;
  stats.save();
}