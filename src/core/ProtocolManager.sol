// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/// @title ProtocolManager V1 — UUPS upgradeable protocol registry
contract ProtocolManagerV1 is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    address public amm;
    address public vault;
    address public oracle;
    address public govToken;
    uint256 public version;
    mapping(address => bool) public whitelisted;

    event ContractRegistered(string name, address indexed addr);
    event AddressWhitelisted(address indexed addr, bool status);

    error ZeroAddress();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { _disableInitializers(); }

    function initialize(address initialOwner) external initializer {
        __Ownable_init(initialOwner);
        __Pausable_init();
        version = 1;
    }

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

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}