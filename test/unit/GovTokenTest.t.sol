// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/governance/GovToken.sol";

contract GovTokenTest is Test {
    GovToken public token;
    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        vm.prank(owner);
        token = new GovToken(owner);
    }

    // ── Basic ERC-20 ──────────────────────────────────────
    function test_name() public view {
        assertEq(token.name(), "DeFi Gov Token");
    }

    function test_symbol() public view {
        assertEq(token.symbol(), "DGT");
    }

    function test_initialSupply() public view {
        assertEq(token.totalSupply(), 100_000 ether);
        assertEq(token.balanceOf(owner), 100_000 ether);
    }

    function test_maxSupply() public view {
        assertEq(token.MAX_SUPPLY(), 1_000_000 ether);
    }

    function test_transfer() public {
        vm.prank(owner);
        token.transfer(alice, 1000 ether);
        assertEq(token.balanceOf(alice), 1000 ether);
        assertEq(token.balanceOf(owner), 99_000 ether);
    }

    function test_transferFrom() public {
        vm.prank(owner);
        token.approve(alice, 500 ether);

        vm.prank(alice);
        token.transferFrom(owner, bob, 500 ether);

        assertEq(token.balanceOf(bob), 500 ether);
    }

    // ── Minting ───────────────────────────────────────────
    function test_mint() public {
        vm.prank(owner);
        token.mint(alice, 1000 ether);
        assertEq(token.balanceOf(alice), 1000 ether);
        assertEq(token.totalSupply(), 101_000 ether);
    }

    function test_revert_mintExceedsMaxSupply() public {
        vm.prank(owner);
        vm.expectRevert("Exceeds max supply");
        token.mint(alice, 1_000_000 ether); // would exceed max
    }

    function test_revert_mintNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        token.mint(alice, 1000 ether);
    }

    // ── ERC20Votes ────────────────────────────────────────
    function test_delegateAndVotingPower() public {
        vm.prank(owner);
        token.delegate(owner);
        assertEq(token.getVotes(owner), 100_000 ether);
    }

    function test_votingPowerAfterTransfer() public {
        vm.startPrank(owner);
        token.delegate(owner);
        token.transfer(alice, 10_000 ether);
        vm.stopPrank();

        assertEq(token.getVotes(owner), 90_000 ether);
    }

    function test_delegateTo() public {
        vm.prank(owner);
        token.delegate(alice);
        assertEq(token.getVotes(alice), 100_000 ether);
        assertEq(token.getVotes(owner), 0);
    }

    function test_getPastVotes() public {
        vm.prank(owner);
        token.delegate(owner);

        uint256 blockBefore = block.number;
        vm.roll(block.number + 1);

        assertEq(token.getPastVotes(owner, blockBefore), 100_000 ether);
    }

    // ── ERC20Permit ───────────────────────────────────────
    function test_permit() public {
        uint256 privateKey = 0xA11CE;
        address signer = vm.addr(privateKey);

        vm.prank(owner);
        token.transfer(signer, 1000 ether);

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        signer,
                        bob,
                        500 ether,
                        token.nonces(signer),
                        deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        token.permit(signer, bob, 500 ether, deadline, v, r, s);

        assertEq(token.allowance(signer, bob), 500 ether);
    }

    function test_revert_expiredPermit() public {
        uint256 deadline = block.timestamp - 1;
        vm.expectRevert();
        token.permit(owner, alice, 100 ether, deadline, 0, bytes32(0), bytes32(0));
    }

    // ── Ownership ─────────────────────────────────────────
    function test_ownerIsSet() public view {
        assertEq(token.owner(), owner);
    }

    function test_transferOwnership() public {
        vm.prank(owner);
        token.transferOwnership(alice);
        assertEq(token.owner(), alice);
    }

    function test_revert_transferOwnershipNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        token.transferOwnership(bob);
    }
}
