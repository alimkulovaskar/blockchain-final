import { BigInt } from "@graphprotocol/graph-sdk";
import { Deposit as DepositEvent } from "../generated/Vault/Vault";
import { VaultDeposit, ProtocolStats } from "../generated/schema";

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

export function handleDeposit(event: DepositEvent): void {
  let deposit = new VaultDeposit(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  deposit.sender = event.params.sender;
  deposit.owner = event.params.owner;
  deposit.assets = event.params.assets;
  deposit.shares = event.params.shares;
  deposit.timestamp = event.block.timestamp;
  deposit.blockNumber = event.block.number;
  deposit.save();

  let stats = getOrCreateStats();
  stats.totalVaultDeposits = stats.totalVaultDeposits.plus(BigInt.fromI32(1));
  stats.updatedAt = event.block.timestamp;
  stats.save();
}