// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/governance/DeFiGovernor.sol";
import "../../src/governance/DeFiTimelock.sol";
import "../../src/governance/GovToken.sol";

contract GovernorTest is Test {
    DeFiGovernor governor;
    DeFiTimelock timelock;
    GovToken token;

    address owner = address(this);
    address voter = makeAddr("voter");
    address target = makeAddr("target");

    function setUp() public {
        token = new GovToken(owner);
        token.mint(owner, 900_000e18);
        token.mint(voter, 100_000e18);

        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = address(0);
        executors[0] = address(0);

        timelock = new DeFiTimelock(2 days, proposers, executors, owner);
        governor = new DeFiGovernor(IVotes(address(token)), timelock);

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(governor));

        token.delegate(owner);
        vm.prank(voter);
        token.delegate(voter);

        vm.roll(block.number + 1);
    }

    function test_governor_name() public view {
        assertEq(governor.name(), "DeFiGovernor");
    }

    function test_governor_votingDelay() public view {
        assertEq(governor.votingDelay(), 1 days);
    }

    function test_governor_votingPeriod() public view {
        assertEq(governor.votingPeriod(), 1 weeks);
    }

    function test_governor_quorum() public view {
        uint256 q = governor.quorum(block.number - 1);
        assertTrue(q > 0);
    }

    function test_governor_proposalThreshold() public view {
        uint256 threshold = governor.proposalThreshold();
        assertTrue(threshold > 0);
    }

    function test_governor_token() public view {
        assertEq(address(governor.token()), address(token));
    }

    function test_governor_timelock() public view {
        assertEq(address(governor.timelock()), address(timelock));
    }

    function test_propose_and_vote() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = target;
        values[0] = 0;
        calldatas[0] = "";

        uint256 proposalId = governor.propose(targets, values, calldatas, "Test proposal");
        assertTrue(proposalId > 0);

        vm.roll(block.number + 1 days + 1);
        vm.warp(block.timestamp + 1 days + 1);

        governor.castVote(proposalId, 1);
        assertTrue(governor.hasVoted(proposalId, owner));
    }

    function test_proposal_state_pending() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = target;

        uint256 proposalId = governor.propose(targets, values, calldatas, "Pending proposal");
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Pending));
    }

    function test_proposalNeedsQueuing() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = target;

        uint256 proposalId = governor.propose(targets, values, calldatas, "Queue test");
        assertTrue(governor.proposalNeedsQueuing(proposalId));
    }
}