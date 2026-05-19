// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/governance/DeFiGovernor.sol";
import "../../src/governance/DeFiTimelock.sol";
import "../../src/governance/GovToken.sol";

contract GovernorTest is Test {
    DeFiGovernor public governor;
    DeFiTimelock public timelock;
    GovToken public token;

    address public owner = address(this);
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string constant DESC = "Proposal #1: test proposal";

    function setUp() public {
        token = new GovToken(owner);
        // Constructor already mints 100_000e18 to owner
        // MAX_SUPPLY = 1_000_000e18, so 900_000e18 left
        token.mint(owner, 500_000e18);
        token.mint(alice, 200_000e18);
        token.mint(bob, 200_000e18);

        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = address(0);
        executors[0] = address(0);
        timelock = new DeFiTimelock(2 days, proposers, executors, owner);

        governor = new DeFiGovernor(IVotes(address(token)), timelock);

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(governor));
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), owner);

        token.delegate(owner);
        vm.prank(alice);
        token.delegate(alice);
        vm.prank(bob);
        token.delegate(bob);

        vm.roll(block.number + 1);

        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        targets[0] = address(token);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("name()");
    }

    // ---------- helpers ----------

    function _propose() internal returns (uint256) {
        return governor.propose(targets, values, calldatas, DESC);
    }

    function _makeActive(uint256 pid) internal {
        vm.roll(block.number + governor.votingDelay() + 1);
        vm.warp(block.timestamp + governor.votingDelay() + 1);
        assertEq(uint8(governor.state(pid)), uint8(IGovernor.ProposalState.Active));
    }

    function _voteAndSucceed(uint256 pid) internal {
        _makeActive(pid);
        governor.castVote(pid, 1);
        vm.prank(alice);
        governor.castVote(pid, 1);
        vm.roll(block.number + governor.votingPeriod() + 1);
        vm.warp(block.timestamp + governor.votingPeriod() + 1);
        assertEq(uint8(governor.state(pid)), uint8(IGovernor.ProposalState.Succeeded));
    }

    function _queue(uint256) internal {
        governor.queue(targets, values, calldatas, keccak256(bytes(DESC)));
    }

    function _fullExecute() internal returns (uint256 pid) {
        pid = _propose();
        _voteAndSucceed(pid);
        _queue(pid);
        vm.warp(block.timestamp + 2 days + 1);
        governor.execute(targets, values, calldatas, keccak256(bytes(DESC)));
    }

    // ---------- metadata ----------

    function test_governor_name() public view {
        assertEq(governor.name(), "DeFiGovernor");
    }

    function test_votingDelay_is_1day() public view {
        assertEq(governor.votingDelay(), 1 days);
    }

    function test_votingPeriod_is_1week() public view {
        assertEq(governor.votingPeriod(), 1 weeks);
    }

    function test_quorumNumerator_is_4() public view {
        assertEq(governor.quorumNumerator(), 4);
    }

    function test_quorum_gt_zero() public view {
        assertGt(governor.quorum(block.number - 1), 0);
    }

    function test_proposalThreshold_is_1pct() public view {
        uint256 supply = token.getPastTotalSupply(block.number - 1);
        assertEq(governor.proposalThreshold(), supply / 100);
    }

    function test_token_address() public view {
        assertEq(address(governor.token()), address(token));
    }

    function test_timelock_address() public view {
        assertEq(address(governor.timelock()), address(timelock));
    }

    function test_clock_returns_block_number() public view {
        assertEq(governor.clock(), block.number);
    }

    function test_hashProposal_deterministic() public view {
        bytes32 dh = keccak256(bytes(DESC));
        assertEq(
            governor.hashProposal(targets, values, calldatas, dh), governor.hashProposal(targets, values, calldatas, dh)
        );
    }

    // ---------- propose ----------

    function test_propose_returns_nonzero_id() public {
        assertGt(_propose(), 0);
    }

    function test_propose_state_is_pending() public {
        uint256 pid = _propose();
        assertEq(uint8(governor.state(pid)), uint8(IGovernor.ProposalState.Pending));
    }

    function test_proposalSnapshot_and_deadline_differ_by_1week() public {
        uint256 pid = _propose();
        assertEq(governor.proposalDeadline(pid) - governor.proposalSnapshot(pid), 1 weeks);
    }

    function test_proposalNeedsQueuing_true() public {
        assertTrue(governor.proposalNeedsQueuing(_propose()));
    }

    function test_revert_propose_duplicate() public {
        _propose();
        vm.expectRevert();
        _propose();
    }

    function test_revert_propose_no_tokens() public {
        vm.prank(charlie);
        vm.expectRevert();
        governor.propose(targets, values, calldatas, "charlie proposal");
    }

    // ---------- vote ----------

    function test_state_active_after_voting_delay() public {
        uint256 pid = _propose();
        _makeActive(pid);
    }

    function test_castVote_for_increments_forVotes() public {
        uint256 pid = _propose();
        _makeActive(pid);
        vm.prank(alice);
        governor.castVote(pid, 1);
        (, uint256 forVotes,) = governor.proposalVotes(pid);
        assertGt(forVotes, 0);
    }

    function test_castVote_against_increments_againstVotes() public {
        uint256 pid = _propose();
        _makeActive(pid);
        vm.prank(alice);
        governor.castVote(pid, 0);
        (uint256 against,,) = governor.proposalVotes(pid);
        assertGt(against, 0);
    }

    function test_castVote_abstain_increments_abstain() public {
        uint256 pid = _propose();
        _makeActive(pid);
        vm.prank(alice);
        governor.castVote(pid, 2);
        (,, uint256 abstain) = governor.proposalVotes(pid);
        assertGt(abstain, 0);
    }

    function test_hasVoted_true_after_vote() public {
        uint256 pid = _propose();
        _makeActive(pid);
        vm.prank(alice);
        governor.castVote(pid, 1);
        assertTrue(governor.hasVoted(pid, alice));
    }

    function test_hasVoted_false_before_vote() public {
        uint256 pid = _propose();
        _makeActive(pid);
        assertFalse(governor.hasVoted(pid, bob));
    }

    function test_revert_double_vote() public {
        uint256 pid = _propose();
        _makeActive(pid);
        vm.startPrank(alice);
        governor.castVote(pid, 1);
        vm.expectRevert();
        governor.castVote(pid, 1);
        vm.stopPrank();
    }

    function test_castVoteWithReason() public {
        uint256 pid = _propose();
        _makeActive(pid);
        vm.prank(alice);
        governor.castVoteWithReason(pid, 1, "I support this");
        assertTrue(governor.hasVoted(pid, alice));
    }

    function test_revert_vote_while_pending() public {
        uint256 pid = _propose();
        vm.expectRevert();
        vm.prank(alice);
        governor.castVote(pid, 1);
    }

    function test_getVotes_matches_delegated_balance() public view {
        assertEq(governor.getVotes(alice, block.number - 1), 200_000e18);
    }

    function test_getVotes_zero_for_nondelegator() public view {
        assertEq(governor.getVotes(charlie, block.number - 1), 0);
    }

    // ---------- succeeded / defeated ----------

    function test_state_succeeded() public {
        uint256 pid = _propose();
        _voteAndSucceed(pid);
    }

    function test_state_defeated_nobody_votes() public {
        uint256 pid = _propose();
        _makeActive(pid);
        vm.roll(block.number + governor.votingPeriod() + 1);
        vm.warp(block.timestamp + governor.votingPeriod() + 1);
        assertEq(uint8(governor.state(pid)), uint8(IGovernor.ProposalState.Defeated));
    }

    function test_state_defeated_only_against_votes() public {
        uint256 pid = _propose();
        _makeActive(pid);
        vm.prank(bob);
        governor.castVote(pid, 0);
        vm.roll(block.number + governor.votingPeriod() + 1);
        vm.warp(block.timestamp + governor.votingPeriod() + 1);
        assertEq(uint8(governor.state(pid)), uint8(IGovernor.ProposalState.Defeated));
    }

    // ---------- queue ----------

    function test_queue_after_success_changes_state() public {
        uint256 pid = _propose();
        _voteAndSucceed(pid);
        _queue(pid);
        assertEq(uint8(governor.state(pid)), uint8(IGovernor.ProposalState.Queued));
    }

    function test_revert_queue_while_pending() public {
        _propose();
        vm.expectRevert();
        governor.queue(targets, values, calldatas, keccak256(bytes(DESC)));
    }

    function test_revert_queue_while_active() public {
        uint256 pid = _propose();
        _makeActive(pid);
        vm.expectRevert();
        governor.queue(targets, values, calldatas, keccak256(bytes(DESC)));
    }

    // ---------- execute ----------

    function test_execute_after_timelock_delay() public {
        uint256 pid = _fullExecute();
        assertEq(uint8(governor.state(pid)), uint8(IGovernor.ProposalState.Executed));
    }

    function test_revert_execute_before_timelock_delay() public {
        uint256 pid = _propose();
        _voteAndSucceed(pid);
        _queue(pid);
        vm.expectRevert();
        governor.execute(targets, values, calldatas, keccak256(bytes(DESC)));
    }

    function test_revert_execute_twice() public {
        _fullExecute();
        vm.expectRevert();
        governor.execute(targets, values, calldatas, keccak256(bytes(DESC)));
    }

    // ---------- cancel ----------

    function test_cancel_pending_proposal() public {
        uint256 pid = _propose();
        governor.cancel(targets, values, calldatas, keccak256(bytes(DESC)));
        assertEq(uint8(governor.state(pid)), uint8(IGovernor.ProposalState.Canceled));
    }

    function test_revert_cancel_executed_proposal() public {
        _fullExecute();
        vm.expectRevert();
        governor.cancel(targets, values, calldatas, keccak256(bytes(DESC)));
    }

    // ---------- fuzz ----------

    function testFuzz_votingPower_neverExceedsSupply(address voter) public view {
        vm.assume(voter != address(0));
        uint256 votes = governor.getVotes(voter, block.number - 1);
        uint256 supply = token.getPastTotalSupply(block.number - 1);
        assertLe(votes, supply);
    }

    function testFuzz_proposalThreshold_always_1pct(uint256 blocksAhead) public {
        blocksAhead = bound(blocksAhead, 0, 100);
        vm.roll(block.number + blocksAhead);
        uint256 supply = token.getPastTotalSupply(block.number - 1);
        assertEq(governor.proposalThreshold(), supply / 100);
    }
}
