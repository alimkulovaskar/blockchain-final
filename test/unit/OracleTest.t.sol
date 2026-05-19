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

    uint256 constant STALENESS = 3600;

    function setUp() public {
        vm.prank(owner);
        oracle = new PriceOracle(owner);
        feed = new MockAggregator(2000e8, 8);

        vm.prank(owner);
        oracle.registerFeed(token, address(feed), STALENESS);
    }

    // ── PriceOracle ───────────────────────────────────────

    function test_getPrice() public view {
        assertEq(oracle.getPrice(token), 2000e8);
    }

    function test_getPriceSafe() public view {
        (uint256 price, bool valid) = oracle.getPriceSafe(token);
        assertEq(price, 2000e8);
        assertTrue(valid);
    }

    function test_priceUpdates() public {
        feed.setPrice(3000e8);
        assertEq(oracle.getPrice(token), 3000e8);
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

    function test_revert_invalidPrice_zero() public {
        feed.setPrice(0);
        vm.expectRevert();
        oracle.getPrice(token);
    }

    function test_deactivateFeed() public {
        vm.prank(owner);
        oracle.deactivateFeed(token);
        vm.expectRevert();
        oracle.getPrice(token);
    }

    function test_deactivateFeed_getPriceSafe_returns_false() public {
        vm.prank(owner);
        oracle.deactivateFeed(token);
        (, bool valid) = oracle.getPriceSafe(token);
        assertFalse(valid);
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

    function test_registerFeed_overwrite_existing() public {
        MockAggregator feed2 = new MockAggregator(9999e8, 8);
        vm.prank(owner);
        oracle.registerFeed(token, address(feed2), STALENESS);
        assertEq(oracle.getPrice(token), 9999e8);
    }

    // ── MockAggregator ────────────────────────────────────

    function test_mockAggregator_decimals() public view {
        assertEq(feed.decimals(), 8);
    }

    function test_mockAggregator_description() public view {
        assertEq(feed.description(), "Mock");
    }

    function test_mockAggregator_version() public view {
        assertEq(feed.version(), 1);
    }

    function test_mockAggregator_latestRoundData_fields() public view {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
            = feed.latestRoundData();
        assertEq(answer, 2000e8);
        assertEq(roundId, answeredInRound);
        assertEq(startedAt, updatedAt);
        assertGt(roundId, 0);
    }

    function test_mockAggregator_getRoundData() public view {
        (uint80 roundId, int256 answer,,,) = feed.getRoundData(0);
        assertEq(answer, 2000e8);
        assertGt(roundId, 0);
    }

    function test_mockAggregator_setPrice_incrementsRound() public {
        (uint80 roundBefore,,,,) = feed.latestRoundData();
        feed.setPrice(5000e8);
        (uint80 roundAfter,,,,) = feed.latestRoundData();
        assertEq(roundAfter, roundBefore + 1);
    }

    function test_mockAggregator_setUpdatedAt_still_fresh() public {
        vm.warp(10_000);
        feed.setUpdatedAt(block.timestamp - 100);
        (, bool valid) = oracle.getPriceSafe(token);
        assertTrue(valid);
    }

    function test_mockAggregator_setUpdatedAt_makes_stale() public {
        vm.warp(10_000);
        feed.setUpdatedAt(block.timestamp - STALENESS - 1);
        (, bool valid) = oracle.getPriceSafe(token);
        assertFalse(valid);
    }

    function test_mockAggregator_constructor_sets_initial_price() public view {
        (,int256 answer,,,) = feed.latestRoundData();
        assertEq(answer, 2000e8);
    }

    function test_mockAggregator_initial_roundId_is_1() public view {
        (uint80 roundId,,,,) = feed.latestRoundData();
        assertEq(roundId, 1);
    }

    function test_revert_registerFeed_zeroToken() public {
        vm.prank(owner);
        vm.expectRevert(PriceOracle.ZeroAddress.selector);
        oracle.registerFeed(address(0), address(feed), STALENESS);
    }

    function test_revert_registerFeed_zeroFeed() public {
        vm.prank(owner);
        vm.expectRevert(PriceOracle.ZeroAddress.selector);
        oracle.registerFeed(makeAddr("newtoken"), address(0), STALENESS);
    }

    function test_getPriceSafe_catch_returns_false() public {
        // Деплоим сломанный feed который ревертит в latestRoundData
        BrokenFeed broken = new BrokenFeed();
        vm.prank(owner);
        oracle.registerFeed(makeAddr("broken"), address(broken), STALENESS);
        (, bool valid) = oracle.getPriceSafe(makeAddr("broken"));
        assertFalse(valid);
    }
}

contract BrokenFeed is AggregatorV3Interface {
    function latestRoundData() external pure override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        revert("broken");
    }
    function getRoundData(uint80) external pure override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        revert("broken");
    }
    function decimals() external pure override returns (uint8) { return 8; }
    function description() external pure override returns (string memory) { return "broken"; }
    function version() external pure override returns (uint256) { return 1; }
}