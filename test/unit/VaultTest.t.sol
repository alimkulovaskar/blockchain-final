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

    function test_totalAssets_zero_initially() public view {
        assertEq(vault.totalAssets(), 0);
    }

    function test_withdraw() public {
        vm.startPrank(alice);
        vault.deposit(1000 ether, alice);
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

    function test_maxDeposit_unbounded() public view {
        assertEq(vault.maxDeposit(alice), type(uint256).max);
    }

    function test_maxMint_unbounded() public view {
        assertEq(vault.maxMint(alice), type(uint256).max);
    }

    function test_maxWithdraw_equals_balance() public {
        vm.prank(alice);
        vault.deposit(1000 ether, alice);
        uint256 maxW = vault.maxWithdraw(alice);
        assertEq(maxW, 1000 ether);
    }

    function test_maxRedeem_equals_shares() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(1000 ether, alice);
        assertEq(vault.maxRedeem(alice), shares);
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

    function test_setFee_to_zero() public {
        vm.prank(owner);
        vault.setFeeBps(0);
        assertEq(vault.feeBps(), 0);
    }

    function test_setFee_to_max() public {
        vm.prank(owner);
        vault.setFeeBps(1000);
        assertEq(vault.feeBps(), 1000);
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

    function test_revert_setFeeNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        vault.setFeeBps(50);
    }

    function test_revert_setFeeRecipientNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        vault.setFeeRecipient(bob);
    }

    // ── collectFee ────────────────────────────────────────

    function test_revert_collectFeeNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        vault.collectFee(100 ether);
    }

    function test_revert_collectFee_notEnough() public {
        // totalFeeCollected = 0
        vm.prank(owner);
        vm.expectRevert("Not enough fees");
        vault.collectFee(1 ether);
    }

    function test_collectFee_success() public {
        vm.prank(alice);
        vault.deposit(1000 ether, alice);

        // Находим слот totalFeeCollected перебором
        bytes32 value = bytes32(uint256(500 ether));
        for (uint256 i = 0; i < 20; i++) {
            bytes32 current = vm.load(address(vault), bytes32(i));
            if (current == bytes32(0)) {
                // пробуем записать и проверить
                vm.store(address(vault), bytes32(i), value);
                if (vault.totalFeeCollected() == 500 ether) break;
                // не тот слот — откатываем
                vm.store(address(vault), bytes32(i), bytes32(0));
            }
        }

        uint256 feeRecipBefore = asset.balanceOf(feeRecip);
        vm.prank(owner);
        vault.collectFee(500 ether);
        assertGt(asset.balanceOf(feeRecip), feeRecipBefore);
    }

    // ── Constructor reverts ───────────────────────────────

    function test_revert_constructor_zeroFeeRecipient() public {
        vm.expectRevert(Vault.ZeroAddress.selector);
        new Vault(IERC20(address(asset)), "Test", "TST", owner, address(0), 100);
    }

    function test_revert_constructor_feeTooHigh() public {
        vm.expectRevert(Vault.FeeTooHigh.selector);
        new Vault(IERC20(address(asset)), "Test", "TST", owner, feeRecip, 1001);
    }

    // ── Fuzz ─────────────────────────────────────────────

    function testFuzz_depositRedeemRoundtrip(uint256 amount) public {
        amount = bound(amount, 1e6, INITIAL);
        vm.startPrank(alice);
        uint256 shares = vault.deposit(amount, alice);
        uint256 assets = vault.redeem(shares, alice, alice);
        vm.stopPrank();
        assertApproxEqAbs(assets, amount, 1);
    }

    function testFuzz_depositAlwaysGivesShares(uint256 amount) public {
        amount = bound(amount, 1e6, INITIAL);
        vm.prank(alice);
        uint256 shares = vault.deposit(amount, alice);
        assertGt(shares, 0);
    }

    function testFuzz_totalAssetsAccounting(uint256 amount) public {
        amount = bound(amount, 1e6, INITIAL);
        vm.prank(alice);
        vault.deposit(amount, alice);
        assertEq(vault.totalAssets(), amount);
    }

    function testFuzz_conversionInverse(uint256 shares) public {
        vm.prank(alice);
        vault.deposit(5000 ether, alice);
        shares = bound(shares, 1, vault.totalSupply());
        uint256 assets = vault.convertToAssets(shares);
        uint256 sharesBack = vault.convertToShares(assets);
        assertApproxEqAbs(sharesBack, shares, 1);
    }

    function testFuzz_maxDepositUnbounded(uint256) public view {
        assertEq(vault.maxDeposit(alice), type(uint256).max);
    }

    function testFuzz_depositWithdrawSymmetry(uint256 amount) public {
        amount = bound(amount, 1e6, INITIAL);
        vm.startPrank(alice);
        vault.deposit(amount, alice);
        vault.withdraw(amount, alice, alice);
        vm.stopPrank();
        assertApproxEqAbs(asset.balanceOf(alice), INITIAL, 1);
    }
}
