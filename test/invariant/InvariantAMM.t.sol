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

contract AMMHandler is Test {
    AMM public amm;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    address public actor = makeAddr("actor");

    constructor(AMM _amm, MockERC20 _tokenA, MockERC20 _tokenB) {
        amm = _amm;
        tokenA = _tokenA;
        tokenB = _tokenB;
        tokenA.mint(actor, 1_000_000 ether);
        tokenB.mint(actor, 1_000_000 ether);
        vm.startPrank(actor);
        tokenA.approve(address(amm), type(uint256).max);
        tokenB.approve(address(amm), type(uint256).max);
        amm.approve(address(amm), type(uint256).max);
        vm.stopPrank();
    }

    function swap(uint256 amount, bool aToB) external {
        amount = bound(amount, 1 ether, 1000 ether);
        if (amm.reserveA() == 0 || amm.reserveB() == 0) return;
        address tokenIn = aToB ? address(tokenA) : address(tokenB);
        vm.prank(actor);
        try amm.swap(tokenIn, amount, 0) {} catch {}
    }

    function addLiquidity(uint256 amount) external {
        amount = bound(amount, 1 ether, 10_000 ether);
        vm.prank(actor);
        try amm.addLiquidity(amount, amount, 0, 0) {} catch {}
    }

    function removeLiquidity(uint256 lpAmount) external {
        uint256 bal = amm.balanceOf(actor);
        if (bal == 0) return;
        lpAmount = bound(lpAmount, 1, bal);
        vm.prank(actor);
        try amm.removeLiquidity(lpAmount, 0, 0) {} catch {}
    }
}

contract InvariantAMM is Test {
    AMM public amm;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    AMMHandler public handler;
    address public owner = makeAddr("owner");
    address public lp = makeAddr("lp");

    uint256 public kInitial;

    function setUp() public {
        tokenA = new MockERC20("Token A", "TKA");
        tokenB = new MockERC20("Token B", "TKB");
        amm = new AMM(address(tokenA), address(tokenB), owner);
        handler = new AMMHandler(amm, tokenA, tokenB);

        tokenA.mint(lp, 1_000_000 ether);
        tokenB.mint(lp, 1_000_000 ether);
        vm.startPrank(lp);
        tokenA.approve(address(amm), type(uint256).max);
        tokenB.approve(address(amm), type(uint256).max);
        amm.addLiquidity(100_000 ether, 100_000 ether, 0, 0);
        vm.stopPrank();

        kInitial = amm.reserveA() * amm.reserveB();

        targetContract(address(handler));
    }

    /// @dev Invariant: k never decreases after swaps
    function invariant_kNeverDecreases() public view {
        if (amm.reserveA() == 0 || amm.reserveB() == 0) return;
        uint256 kCurrent = amm.reserveA() * amm.reserveB();
        assertGe(kCurrent, kInitial);
    }

    /// @dev Invariant: reserves match actual token balances
    function invariant_reservesMatchBalances() public view {
        assertEq(tokenA.balanceOf(address(amm)), amm.reserveA());
        assertEq(tokenB.balanceOf(address(amm)), amm.reserveB());
    }

    /// @dev Invariant: total LP supply > 0 when reserves > 0
    function invariant_lpSupplyConsistent() public view {
        if (amm.reserveA() > 0 && amm.reserveB() > 0) {
            assertGt(amm.totalSupply(), 0);
        }
    }
}
