// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/// @title ProtocolManagerV2 — upgraded version of ProtocolManagerV1
/// @notice Adds protocol fee, fee recipient, and emergency pause
/// @dev V1→V2 upgrade: new storage appended after V1 slots (no collision)
contract ProtocolManagerV2 is Initializable, OwnableUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    // ── V1 storage (must match V1 exactly, same order) ──────────────────
    address public amm;
    address public vault;
    address public oracle;
    address public govToken;
    uint256 public protocolVersion;
    mapping(address => bool) public whitelisted;

    // ── V2 storage (appended after V1) ──────────────────────────────────
    uint256 public protocolFee; // basis points, max 1000 = 10%
    address public feeRecipient;
    uint256 public totalFeesCollected;
    bool public emergencyPaused;

    // ── Events ──────────────────────────────────────────────────────────
    event ContractRegistered(string name, address indexed addr);
    event AddressWhitelisted(address indexed addr, bool status);
    event ProtocolFeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event EmergencyPaused(address indexed by);
    event EmergencyUnpaused(address indexed by);

    // ── Errors ──────────────────────────────────────────────────────────
    error ZeroAddress();
    error FeeTooHigh();
    error EmergencyStop();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice V2 initializer — called once after upgrade
    function initializeV2(address _feeRecipient, uint256 _protocolFee) external reinitializer(2) {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        if (_protocolFee > 1000) revert FeeTooHigh();
        feeRecipient = _feeRecipient;
        protocolFee = _protocolFee;
        protocolVersion = 2;
    }

    // ── V1 functions (kept identical) ───────────────────────────────────
    function registerAMM(address _amm) external onlyOwner {
        if (_amm == address(0)) revert ZeroAddress();
        amm = _amm;
        emit ContractRegistered("AMM", _amm);
    }

    function registerVault(address _vault) external onlyOwner {
        if (_vault == address(0)) revert ZeroAddress();
        vault = _vault;
        emit ContractRegistered("Vault", _vault);
    }

    function registerOracle(address _oracle) external onlyOwner {
        if (_oracle == address(0)) revert ZeroAddress();
        oracle = _oracle;
        emit ContractRegistered("Oracle", _oracle);
    }

    function registerGovToken(address _govToken) external onlyOwner {
        if (_govToken == address(0)) revert ZeroAddress();
        govToken = _govToken;
        emit ContractRegistered("GovToken", _govToken);
    }

    function setWhitelisted(address addr, bool status) external onlyOwner {
        whitelisted[addr] = status;
        emit AddressWhitelisted(addr, status);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // ── V2 new functions ─────────────────────────────────────────────────
    function setProtocolFee(uint256 newFee) external onlyOwner {
        if (newFee > 1000) revert FeeTooHigh();
        emit ProtocolFeeUpdated(protocolFee, newFee);
        protocolFee = newFee;
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientUpdated(feeRecipient, newRecipient);
        feeRecipient = newRecipient;
    }

    function emergencyPause() external onlyOwner {
        emergencyPaused = true;
        emit EmergencyPaused(msg.sender);
    }

    function emergencyUnpause() external onlyOwner {
        emergencyPaused = false;
        emit EmergencyUnpaused(msg.sender);
    }

    function accrueFee(uint256 amount) external {
        if (emergencyPaused) revert EmergencyStop();
        totalFeesCollected += amount;
    }

    function getVersion() external pure returns (string memory) {
        return "2.0.0";
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
