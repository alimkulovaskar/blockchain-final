// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/oracle/PriceOracle.sol";
import "../../src/oracle/MockAggregator.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev Fork tests — run against real Arbitrum mainnet / Ethereum mainnet state
/// Set ARB_RPC_URL and ETH_RPC_URL in .env to run these
contract ForkTest is Test {
    // Real Chainlink ETH/USD feed on Arbitrum mainnet
    address constant CHAINLINK_ETH_USD = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;
    // Real USDC on Arbitrum mainnet
    address constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    // Uniswap V2 Router on Ethereum mainnet
    address constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    // WETH mainnet
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    PriceOracle public oracle;
    address public owner = makeAddr("owner");

    uint256 arbitrumFork;
    uint256 mainnetFork;

    function setUp() public {
        string memory arbitrumRpc =
            vm.envOr("ARB_RPC_URL", string("https://arb-mainnet.g.alchemy.com/v2/iwDvR-bqVnt8x4WvHuT2b"));
        string memory mainnetRpc =
            vm.envOr("ETH_RPC_URL", string("https://eth-mainnet.g.alchemy.com/v2/iwDvR-bqVnt8x4WvHuT2b"));
        arbitrumFork = vm.createFork(arbitrumRpc);
        mainnetFork = vm.createFork(mainnetRpc);
    }

    /// @dev Fork test 1: Real Chainlink ETH/USD feed returns valid price
    function test_fork_chainlinkRealFeed() public {
        vm.selectFork(arbitrumFork);

        vm.prank(owner);
        oracle = new PriceOracle(owner);

        vm.prank(owner);
        oracle.registerFeed(WETH, CHAINLINK_ETH_USD, 3600);

        uint256 price = oracle.getPrice(WETH);
        // ETH price should be between $100 and $100,000
        assertGt(price, 100e8);
        assertLt(price, 100_000e8);
    }

    /// @dev Fork test 2: USDC exists and has supply > 0 on Arbitrum
    function test_fork_usdcOnArbitrum() public {
        vm.selectFork(arbitrumFork);

        IERC20 usdc = IERC20(USDC);
        assertGt(usdc.totalSupply(), 0);
    }

    /// @dev Fork test 3: Chainlink feed staleness check works with real feed
    function test_fork_chainlinkStalenessCheck() public {
        vm.selectFork(arbitrumFork);

        vm.prank(owner);
        oracle = new PriceOracle(owner);

        // Register with very short staleness (1 second)
        vm.prank(owner);
        oracle.registerFeed(WETH, CHAINLINK_ETH_USD, 1);

        // Warp forward — price becomes stale
        vm.warp(block.timestamp + 2);
        vm.expectRevert();
        oracle.getPrice(WETH);
    }

    /// @dev Fork test 4: Mock aggregator works as drop-in for real feed
    function test_fork_mockAggregatorDropIn() public {
        vm.selectFork(arbitrumFork);

        MockAggregator mock = new MockAggregator(2000e8, 8);

        vm.prank(owner);
        oracle = new PriceOracle(owner);
        vm.prank(owner);
        oracle.registerFeed(WETH, address(mock), 3600);

        uint256 price = oracle.getPrice(WETH);
        assertEq(price, 2000e8);
    }

    /// @dev Fork test 5: WETH balance readable on Ethereum mainnet
    function test_fork_mainnetWethBalance() public {
        vm.selectFork(mainnetFork);
        IERC20 weth = IERC20(WETH);
        uint256 bal = weth.balanceOf(UNISWAP_V2_ROUTER);
        assertGe(bal, 0);
    }
}
