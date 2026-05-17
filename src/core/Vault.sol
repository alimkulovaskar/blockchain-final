// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Vault — ERC-4626 tokenized yield vault
contract Vault is ERC4626, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_FEE_BPS = 1000; // 10% max
    uint256 public feeBps;
    address public feeRecipient;
    uint256 public totalFeeCollected;

    event FeeUpdated(uint256 newFeeBps);
    event FeeCollected(address indexed recipient, uint256 amount);

    error FeeTooHigh();
    error ZeroAddress();

    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        address initialOwner,
        address _feeRecipient,
        uint256 _feeBps
    ) ERC4626(asset_) ERC20(name_, symbol_) Ownable(initialOwner) {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        if (_feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        feeRecipient = _feeRecipient;
        feeBps = _feeBps;
    }

    /// @notice Deposit assets, receive vault shares
    function deposit(uint256 assets, address receiver) public override nonReentrant returns (uint256 shares) {
        shares = super.deposit(assets, receiver);
    }

    /// @notice Withdraw assets by burning shares
    function withdraw(uint256 assets, address receiver, address owner_)
        public
        override
        nonReentrant
        returns (uint256 shares)
    {
        shares = super.withdraw(assets, receiver, owner_);
    }

    /// @notice Redeem shares for assets
    function redeem(uint256 shares, address receiver, address owner_)
        public
        override
        nonReentrant
        returns (uint256 assets)
    {
        assets = super.redeem(shares, receiver, owner_);
    }

    /// @notice Owner can collect protocol fees
    function collectFee(uint256 amount) external onlyOwner {
        require(amount <= totalFeeCollected, "Not enough fees");
        totalFeeCollected -= amount;
        IERC20(asset()).safeTransfer(feeRecipient, amount);
        emit FeeCollected(feeRecipient, amount);
    }

    function setFeeBps(uint256 _feeBps) external onlyOwner {
        if (_feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        feeBps = _feeBps;
        emit FeeUpdated(_feeBps);
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        feeRecipient = _feeRecipient;
    }

    /// @notice ERC-4626 rounding: shares round DOWN on deposit (safe for users)
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view override returns (uint256) {
        return super._convertToShares(assets, rounding);
    }

    /// @notice ERC-4626 rounding: assets round DOWN on withdraw (safe for vault)
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view override returns (uint256) {
        return super._convertToAssets(shares, rounding);
    }
}
