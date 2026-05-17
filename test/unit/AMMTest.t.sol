// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/AMM.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract AMMTest is Test {
    AMM public amm;
    MockERC20 public tokenA;
    MockERC20 public tokenB;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 constant INITIAL = 100_000 ether;

    function setUp() public {
        tokenA = new MockERC20("Token A", "TKA");
        tokenB = new MockERC20("Token B", "TKB");
        amm = new AMM(address(tokenA), address(tokenB), owner);

        tokenA.mint(alice, INITIAL);
        tokenB.mint(alice, INITIAL);
        tokenA.mint(bob, INITIAL);
        tokenB.mint(bob, INITIAL);

        vm.startPrank(alice);
        tokenA.approve(address(amm), type(uint256).max);
        tokenB.approve(address(amm), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        tokenA.approve(address(amm), type(uint256).max);
        tokenB.approve(address(amm), type(uint256).max);
        vm.stopPrank();
    }

    // ── Add Liquidity ─────────────────────────────────────
    function test_addInitialLiquidity() public {
        vm.prank(alice);
        (uint256 a, uint256 b, uint256 lp) = amm.addLiquidity(1000 ether, 1000 ether, 0, 0);
        assertEq(a, 1000 ether);
        assertEq(b, 1000 ether);
        assertGt(lp, 0);
        assertEq(amm.reserveA(), 1000 ether);
        assertEq(amm.reserveB(), 1000 ether);
    }

    function test_addLiquidityMintCorrectLP() public {
        vm.prank(alice);
        (,, uint256 lp) = amm.addLiquidity(1000 ether, 1000 ether, 0, 0);
        assertEq(amm.balanceOf(alice), lp);
    }

    function test_addLiquiditySecondProvider() public {
        vm.prank(alice);
        amm.addLiquidity(1000 ether, 1000 ether, 0, 0);

        vm.prank(bob);
        (uint256 a, uint256 b, uint256 lp) = amm.addLiquidity(500 ether, 500 ether, 0, 0);
        assertEq(a, 500 ether);
        assertEq(b, 500 ether);
        assertGt(lp, 0);
    }

    function test_revert_addLiquidityZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(AMM.ZeroAmount.selector);
        amm.addLiquidity(0, 1000 ether, 0, 0);
    }

    function test_revert_addLiquiditySlippage() public {
        vm.prank(alice);
        amm.addLiquidity(1000 ether, 1000 ether, 0, 0);

        vm.prank(bob);
        vm.expectRevert(AMM.SlippageExceeded.selector);
        // amountBOptimal = 500, but amountBMin = 600 → revert
        amm.addLiquidity(500 ether, 1000 ether, 0, 600 ether);
    }

    // ── Remove Liquidity ──────────────────────────────────
    function test_removeLiquidity() public {
        vm.startPrank(alice);
        (,, uint256 lp) = amm.addLiquidity(1000 ether, 1000 ether, 0, 0);
        amm.approve(address(amm), lp);
        (uint256 a, uint256 b) = amm.removeLiquidity(lp, 0, 0);
        vm.stopPrank();

        assertGt(a, 0);
        assertGt(b, 0);
        assertEq(amm.balanceOf(alice), 0);
    }

    function test_revert_removeLiquidityZero() public {
        vm.prank(alice);
        vm.expectRevert(AMM.ZeroAmount.selector);
        amm.removeLiquidity(0, 0, 0);
    }

    function test_revert_removeLiquiditySlippage() public {
        vm.startPrank(alice);
        (,, uint256 lp) = amm.addLiquidity(1000 ether, 1000 ether, 0, 0);
        amm.approve(address(amm), lp);
        vm.expectRevert(AMM.SlippageExceeded.selector);
        // actual output ~999 ether (minus locked minimum), require 1000 → revert
        amm.removeLiquidity(lp, 1000 ether, 1000 ether);
        vm.stopPrank();
    }

    // ── Swap ──────────────────────────────────────────────
    function test_swapAtoB() public {
        vm.prank(alice);
        amm.addLiquidity(10_000 ether, 10_000 ether, 0, 0);

        uint256 balBefore = tokenB.balanceOf(bob);
        vm.prank(bob);
        uint256 out = amm.swap(address(tokenA), 100 ether, 0);

        assertGt(out, 0);
        assertEq(tokenB.balanceOf(bob), balBefore + out);
    }

    function test_swapBtoA() public {
        vm.prank(alice);
        amm.addLiquidity(10_000 ether, 10_000 ether, 0, 0);

        uint256 balBefore = tokenA.balanceOf(bob);
        vm.prank(bob);
        uint256 out = amm.swap(address(tokenB), 100 ether, 0);

        assertGt(out, 0);
        assertEq(tokenA.balanceOf(bob), balBefore + out);
    }

    function test_swapFeeApplied() public {
        vm.prank(alice);
        amm.addLiquidity(10_000 ether, 10_000 ether, 0, 0);

        // With fee, output must be less than input
        vm.prank(bob);
        uint256 out = amm.swap(address(tokenA), 100 ether, 0);
        assertLt(out, 100 ether);
    }

    function test_revert_swapInvalidToken() public {
        vm.prank(alice);
        amm.addLiquidity(1000 ether, 1000 ether, 0, 0);

        vm.prank(bob);
        vm.expectRevert(AMM.InvalidToken.selector);
        amm.swap(address(0xdead), 100 ether, 0);
    }

    function test_revert_swapSlippage() public {
        vm.prank(alice);
        amm.addLiquidity(10_000 ether, 10_000 ether, 0, 0);

        vm.prank(bob);
        vm.expectRevert(AMM.SlippageExceeded.selector);
        amm.swap(address(tokenA), 100 ether, 200 ether);
    }

    function test_revert_swapZeroAmount() public {
        vm.prank(alice);
        amm.addLiquidity(1000 ether, 1000 ether, 0, 0);

        vm.prank(bob);
        vm.expectRevert(AMM.ZeroAmount.selector);
        amm.swap(address(tokenA), 0, 0);
    }

    // ── getAmountOut ──────────────────────────────────────
    function test_getAmountOut() public {
        vm.prank(alice);
        amm.addLiquidity(10_000 ether, 10_000 ether, 0, 0);

        uint256 expected = amm.getAmountOut(address(tokenA), 100 ether);
        assertGt(expected, 0);
        assertLt(expected, 100 ether);
    }

    // ── K invariant check ─────────────────────────────────
    function test_kInvariantAfterSwap() public {
        vm.prank(alice);
        amm.addLiquidity(10_000 ether, 10_000 ether, 0, 0);

        uint256 kBefore = amm.reserveA() * amm.reserveB();

        vm.prank(bob);
        amm.swap(address(tokenA), 100 ether, 0);

        uint256 kAfter = amm.reserveA() * amm.reserveB();
        assertGe(kAfter, kBefore); // k must never decrease
    }
}
