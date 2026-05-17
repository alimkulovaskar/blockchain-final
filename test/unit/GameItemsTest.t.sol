// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/tokens/GameItems.sol";

contract GameItemsTest is Test {
    GameItems public items;
    address public admin = makeAddr("admin");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 constant GOLD = 0;
    uint256 constant SILVER = 1;
    uint256 constant VAULT_RECEIPT = 2;
    uint256 constant GOV_BADGE = 3;

    function setUp() public {
        vm.prank(admin);
        items = new GameItems(admin);
    }

    function test_mint_gold() public {
        vm.prank(admin);
        items.mint(alice, GOLD, 1000, "");
        assertEq(items.balanceOf(alice, GOLD), 1000);
    }

    function test_mint_silver() public {
        vm.prank(admin);
        items.mint(alice, SILVER, 500, "");
        assertEq(items.balanceOf(alice, SILVER), 500);
    }

    function test_mintBatch() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = GOLD;
        ids[1] = SILVER;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        vm.prank(admin);
        items.mintBatch(alice, ids, amounts, "");

        assertEq(items.balanceOf(alice, GOLD), 100);
        assertEq(items.balanceOf(alice, SILVER), 200);
    }

    function test_burn() public {
        vm.prank(admin);
        items.mint(alice, GOLD, 1000, "");

        vm.prank(alice);
        items.burn(alice, GOLD, 400);

        assertEq(items.balanceOf(alice, GOLD), 600);
    }

    function test_mint_revert_notMinter() public {
        vm.prank(alice);
        vm.expectRevert();
        items.mint(bob, GOLD, 100, "");
    }

    function test_pause_blocksMint() public {
        vm.prank(admin);
        items.pause();

        vm.prank(admin);
        vm.expectRevert();
        items.mint(alice, GOLD, 100, "");
    }

    function test_unpause_allowsMint() public {
        vm.prank(admin);
        items.pause();

        vm.prank(admin);
        items.unpause();

        vm.prank(admin);
        items.mint(alice, GOLD, 100, "");
        assertEq(items.balanceOf(alice, GOLD), 100);
    }

    function test_supportsInterface_ERC1155() public view {
        assertTrue(items.supportsInterface(0xd9b67a26));
    }

    function test_totalSupply_tracked() public {
        vm.prank(admin);
        items.mint(alice, VAULT_RECEIPT, 50, "");
        assertEq(items.totalSupply(VAULT_RECEIPT), 50);
    }

    function test_burn_revert_notAuthorized() public {
        vm.prank(admin);
        items.mint(alice, GOLD, 100, "");

        vm.prank(bob);
        vm.expectRevert();
        items.burn(alice, GOLD, 50);
    }
}
