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

contract VaultTest is Test {
    Vault public vault;
    MockERC20 public asset;

    address public owner = makeAddr("owner");
    address public feeRecip = makeAddr("feeRecip");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 constant INITIAL = 10_000 ether;

    function setUp() public {
        asset = new MockERC20("USD Coin", "USDC");
        vm.prank(owner);
        vault = new Vault(
            IERC20(address(asset)),
            "DeFi Vault",
            "dVault",
            owner,
            feeRecip,
            100 // 1% fee
        );

        asset.mint(alice, INITIAL);
        asset.mint(bob, INITIAL);

        vm.prank(alice);
        asset.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        asset.approve(address(vault), type(uint256).max);
    }

    // ── Basic ERC-4626 ────────────────────────────────────
    function test_nameAndSymbol() public view {
        assertEq(vault.name(), "DeFi Vault");
        assertEq(vault.symbol(), "dVault");
    }

    function test_assetAddress() public view {
        assertEq(vault.asset(), address(asset));
    }

    function test_deposit() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(1000 ether, alice);
        assertGt(shares, 0);
        assertEq(vault.balanceOf(alice), shares);
    }

    function test_depositUpdatesAssets() public {
        vm.prank(alice);
        vault.deposit(1000 ether, alice);
        assertEq(vault.totalAssets(), 1000 ether);
    }

    function test_withdraw() public {
        vm.startPrank(alice);
        vault.deposit(1000 ether, alice);
        uint256 sharesBefore = vault.balanceOf(alice);
        assertGt(sharesBefore, 0);

        vault.withdraw(500 ether, alice, alice);
        vm.stopPrank();

        assertEq(asset.balanceOf(alice), INITIAL - 500 ether);
    }

    function test_redeem() public {
        vm.startPrank(alice);
        uint256 shares = vault.deposit(1000 ether, alice);
        uint256 assets = vault.redeem(shares, alice, alice);
        vm.stopPrank();

        assertGt(assets, 0);
        assertEq(vault.balanceOf(alice), 0);
    }

    function test_multipleDepositors() public {
        vm.prank(alice);
        vault.deposit(1000 ether, alice);
        vm.prank(bob);
        vault.deposit(1000 ether, bob);

        assertEq(vault.totalAssets(), 2000 ether);
        assertGt(vault.balanceOf(alice), 0);
        assertGt(vault.balanceOf(bob), 0);
    }

    // ── Shares/Assets conversion ──────────────────────────
    function test_convertToShares() public {
        vm.prank(alice);
        vault.deposit(1000 ether, alice);
        uint256 shares = vault.convertToShares(500 ether);
        assertGt(shares, 0);
    }

    function test_convertToAssets() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(1000 ether, alice);
        uint256 assets = vault.convertToAssets(shares);
        assertApproxEqAbs(assets, 1000 ether, 1);
    }

    function test_previewDeposit() public view {
        uint256 shares = vault.previewDeposit(1000 ether);
        assertGt(shares, 0);
    }

    function test_previewRedeem() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(1000 ether, alice);
        uint256 assets = vault.previewRedeem(shares);
        assertGt(assets, 0);
    }

    // ── Fee management ────────────────────────────────────
    function test_feeIsSet() public view {
        assertEq(vault.feeBps(), 100);
    }

    function test_setFee() public {
        vm.prank(owner);
        vault.setFeeBps(200);
        assertEq(vault.feeBps(), 200);
    }

    function test_revert_feeTooHigh() public {
        vm.prank(owner);
        vm.expectRevert(Vault.FeeTooHigh.selector);
        vault.setFeeBps(1001);
    }

    function test_setFeeRecipient() public {
        vm.prank(owner);
        vault.setFeeRecipient(alice);
        assertEq(vault.feeRecipient(), alice);
    }

    function test_revert_setFeeRecipientZero() public {
        vm.prank(owner);
        vm.expectRevert(Vault.ZeroAddress.selector);
        vault.setFeeRecipient(address(0));
    }

    function test_revert_collectFeeNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        vault.collectFee(100 ether);
    }

    // ── Access control ────────────────────────────────────
    function test_revert_setFeeNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        vault.setFeeBps(50);
    }
}
