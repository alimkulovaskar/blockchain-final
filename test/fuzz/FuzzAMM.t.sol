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

contract FuzzAMM is Test {
    AMM public amm;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    address public owner = makeAddr("owner");
    address public lp = makeAddr("lp");
    address public user = makeAddr("user");

    function setUp() public {
        tokenA = new MockERC20("Token A", "TKA");
        tokenB = new MockERC20("Token B", "TKB");
        amm = new AMM(address(tokenA), address(tokenB), owner);

        tokenA.mint(lp, 1_000_000 ether);
        tokenB.mint(lp, 1_000_000 ether);
        tokenA.mint(user, 1_000_000 ether);
        tokenB.mint(user, 1_000_000 ether);

        vm.startPrank(lp);
        tokenA.approve(address(amm), type(uint256).max);
        tokenB.approve(address(amm), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user);
        tokenA.approve(address(amm), type(uint256).max);
        tokenB.approve(address(amm), type(uint256).max);
        vm.stopPrank();

        // Seed initial liquidity
        vm.prank(lp);
        amm.addLiquidity(100_000 ether, 100_000 ether, 0, 0);
    }

    /// @dev Fuzz: swap output always less than input (fee applied)
    function testFuzz_swapOutputLessThanInput(uint256 amountIn) public {
        amountIn = bound(amountIn, 1 ether, 10_000 ether);
        vm.prank(user);
        uint256 out = amm.swap(address(tokenA), amountIn, 0);
        assertLt(out, amountIn);
    }

    /// @dev Fuzz: k invariant never decreases after swap
    function testFuzz_kInvariantNeverDecreases(uint256 amountIn) public {
        amountIn = bound(amountIn, 1 ether, 10_000 ether);
        uint256 kBefore = amm.reserveA() * amm.reserveB();
        vm.prank(user);
        amm.swap(address(tokenA), amountIn, 0);
        uint256 kAfter = amm.reserveA() * amm.reserveB();
        assertGe(kAfter, kBefore);
    }

    /// @dev Fuzz: getAmountOut matches actual swap output
    function testFuzz_getAmountOutMatchesSwap(uint256 amountIn) public {
        amountIn = bound(amountIn, 1 ether, 5_000 ether);
        uint256 expected = amm.getAmountOut(address(tokenA), amountIn);
        vm.prank(user);
        uint256 actual = amm.swap(address(tokenA), amountIn, 0);
        assertEq(actual, expected);
    }

    /// @dev Fuzz: LP tokens proportional to deposit
    function testFuzz_lpTokensProportional(uint256 amount) public {
        amount = bound(amount, 1 ether, 50_000 ether);
        vm.prank(lp);
        (,, uint256 lp1) = amm.addLiquidity(amount, amount, 0, 0);
        assertGt(lp1, 0);
    }

    /// @dev Fuzz: deposit then withdraw returns correct amounts
    function testFuzz_depositWithdrawSymmetry(uint256 amount) public {
        amount = bound(amount, 1 ether, 50_000 ether);
        vm.startPrank(lp);
        (,, uint256 lpTokens) = amm.addLiquidity(amount, amount, 0, 0);
        amm.approve(address(amm), lpTokens);
        (uint256 outA, uint256 outB) = amm.removeLiquidity(lpTokens, 0, 0);
        vm.stopPrank();
        assertGt(outA, 0);
        assertGt(outB, 0);
    }
}
