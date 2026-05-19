import { BigInt } from "@graphprotocol/graph-sdk";
import {
  ProposalCreated as ProposalCreatedEvent,
  VoteCast as VoteCastEvent,
} from "../generated/DeFiGovernor/DeFiGovernor";
import { Proposal, Vote, ProtocolStats } from "../generated/schema";

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

export function handleProposalCreated(event: ProposalCreatedEvent): void {
  let proposal = new Proposal(event.params.proposalId.toString());
  proposal.proposalId = event.params.proposalId;
  proposal.proposer = event.params.proposer;
  proposal.description = event.params.description;
  proposal.startBlock = event.params.voteStart;
  proposal.endBlock = event.params.voteEnd;
  proposal.state = "Pending";
  proposal.forVotes = BigInt.fromI32(0);
  proposal.againstVotes = BigInt.fromI32(0);
  proposal.abstainVotes = BigInt.fromI32(0);
  proposal.createdAt = event.block.timestamp;
  proposal.save();

  let stats = getOrCreateStats();
  stats.totalProposals = stats.totalProposals.plus(BigInt.fromI32(1));
  stats.updatedAt = event.block.timestamp;
  stats.save();
}

export function handleVoteCast(event: VoteCastEvent): void {
  let proposal = Proposal.load(event.params.proposalId.toString());
  if (!proposal) return;

  if (event.params.support == 1) {
    proposal.forVotes = proposal.forVotes.plus(event.params.weight);
  } else if (event.params.support == 0) {
    proposal.againstVotes = proposal.againstVotes.plus(event.params.weight);
  } else {
    proposal.abstainVotes = proposal.abstainVotes.plus(event.params.weight);
  }
  proposal.save();

  let vote = new Vote(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  vote.proposal = proposal.id;
  vote.voter = event.params.voter;
  vote.support = event.params.support;
  vote.weight = event.params.weight;
  vote.reason = event.params.reason;
  vote.timestamp = event.block.timestamp;
  vote.save();

  let stats = getOrCreateStats();
  stats.totalVotes = stats.totalVotes.plus(BigInt.fromI32(1));
  stats.updatedAt = event.block.timestamp;
  stats.save();
}