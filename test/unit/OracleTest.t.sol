// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/oracle/PriceOracle.sol";
import "../../src/oracle/MockAggregator.sol";

contract OracleTest is Test {
    PriceOracle public oracle;
    MockAggregator public feed;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public token = makeAddr("token");

    uint256 constant STALENESS = 3600; // 1 hour

    function setUp() public {
        vm.prank(owner);
        oracle = new PriceOracle(owner);
        feed = new MockAggregator(2000e8, 8); // $2000 price

        vm.prank(owner);
        oracle.registerFeed(token, address(feed), STALENESS);
    }

    function test_getPrice() public view {
        uint256 price = oracle.getPrice(token);
        assertEq(price, 2000e8);
    }

    function test_getPriceSafe() public view {
        (uint256 price, bool valid) = oracle.getPriceSafe(token);
        assertEq(price, 2000e8);
        assertTrue(valid);
    }

    function test_priceUpdates() public {
        feed.setPrice(3000e8);
        uint256 price = oracle.getPrice(token);
        assertEq(price, 3000e8);
    }

    function test_revert_stalePrice() public {
        vm.warp(block.timestamp + STALENESS + 1);
        vm.expectRevert();
        oracle.getPrice(token);
    }

    function test_getPriceSafeReturnsFalseWhenStale() public {
        vm.warp(block.timestamp + STALENESS + 1);
        (, bool valid) = oracle.getPriceSafe(token);
        assertFalse(valid);
    }

    function test_revert_feedNotFound() public {
        vm.expectRevert();
        oracle.getPrice(makeAddr("unknown"));
    }

    function test_revert_registerFeedNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        oracle.registerFeed(token, address(feed), STALENESS);
    }

    function test_revert_invalidPrice() public {
        feed.setPrice(-1);
        vm.expectRevert();
        oracle.getPrice(token);
    }

    function test_deactivateFeed() public {
        vm.prank(owner);
        oracle.deactivateFeed(token);
        vm.expectRevert();
        oracle.getPrice(token);
    }

    function test_getRegisteredTokens() public view {
        address[] memory tokens = oracle.getRegisteredTokens();
        assertEq(tokens.length, 1);
        assertEq(tokens[0], token);
    }

    function test_registerMultipleFeeds() public {
        address token2 = makeAddr("token2");
        MockAggregator feed2 = new MockAggregator(1e8, 8);
        vm.prank(owner);
        oracle.registerFeed(token2, address(feed2), STALENESS);

        address[] memory tokens = oracle.getRegisteredTokens();
        assertEq(tokens.length, 2);
    }
}
