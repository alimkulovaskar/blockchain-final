// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/Vault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract FuzzVault is Test {
    Vault public vault;
    MockERC20 public asset;
    address public owner = makeAddr("owner");
    address public feeRecip = makeAddr("feeRecip");
    address public alice = makeAddr("alice");

    function setUp() public {
        asset = new MockERC20("USDC", "USDC");
        vm.prank(owner);
        vault = new Vault(IERC20(address(asset)), "Vault", "vUSDC", owner, feeRecip, 0);
        asset.mint(alice, 1_000_000 ether);
        vm.prank(alice);
        asset.approve(address(vault), type(uint256).max);
    }

    /// @dev Fuzz: shares received always > 0 for any deposit
    function testFuzz_depositAlwaysGivesShares(uint256 amount) public {
        amount = bound(amount, 1, 1_000_000 ether);
        vm.prank(alice);
        uint256 shares = vault.deposit(amount, alice);
        assertGt(shares, 0);
    }

    /// @dev Fuzz: redeem after deposit returns close to original amount
    function testFuzz_depositRedeemRoundtrip(uint256 amount) public {
        amount = bound(amount, 1 ether, 500_000 ether);
        vm.startPrank(alice);
        uint256 shares = vault.deposit(amount, alice);
        uint256 assets = vault.redeem(shares, alice, alice);
        vm.stopPrank();
        assertApproxEqAbs(assets, amount, 1);
    }

    /// @dev Fuzz: totalAssets matches sum of deposits
    function testFuzz_totalAssetsAccounting(uint256 amount) public {
        amount = bound(amount, 1 ether, 500_000 ether);
        vm.prank(alice);
        vault.deposit(amount, alice);
        assertEq(vault.totalAssets(), amount);
    }

    /// @dev Fuzz: convertToShares and convertToAssets are inverse
    function testFuzz_conversionInverse(uint256 amount) public {
        amount = bound(amount, 1 ether, 100_000 ether);
        vm.prank(alice);
        vault.deposit(amount, alice);
        uint256 shares = vault.convertToShares(amount);
        uint256 back = vault.convertToAssets(shares);
        assertApproxEqAbs(back, amount, 1);
    }

    /// @dev Fuzz: maxDeposit always >= amount for normal user
    function testFuzz_maxDepositUnbounded(uint256 amount) public view {
        amount = bound(amount, 1, 1_000_000 ether);
        assertGe(vault.maxDeposit(alice), amount);
    }
}
