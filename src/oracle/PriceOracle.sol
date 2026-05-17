// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title PriceOracle — Chainlink price feed with staleness check
contract PriceOracle is Ownable {

    struct FeedConfig {
        AggregatorV3Interface feed;
        uint256 stalenessThreshold; // seconds
        bool active;
    }

    mapping(address => FeedConfig) public feeds;
    address[] public registeredTokens;

    event FeedRegistered(address indexed token, address indexed feed, uint256 stalenessThreshold);
    event FeedDeactivated(address indexed token);

    error StalePrice(address token, uint256 updatedAt, uint256 threshold);
    error FeedNotFound(address token);
    error InvalidPrice();
    error ZeroAddress();

    constructor(address initialOwner) Ownable(initialOwner) {}

    /// @notice Register a Chainlink price feed for a token
    function registerFeed(
        address token,
        address feed,
        uint256 stalenessThreshold
    ) external onlyOwner {
        if (token == address(0) || feed == address(0)) revert ZeroAddress();
        if (!feeds[token].active) {
            registeredTokens.push(token);
        }
        feeds[token] = FeedConfig({
            feed: AggregatorV3Interface(feed),
            stalenessThreshold: stalenessThreshold,
            active: true
        });
        emit FeedRegistered(token, feed, stalenessThreshold);
    }

    /// @notice Get latest price with staleness check
    /// @return price — price with 8 decimals (Chainlink standard)
    function getPrice(address token) external view returns (uint256 price) {
        FeedConfig memory config = feeds[token];
        if (!config.active) revert FeedNotFound(token);

        (
            ,
            int256 answer,
            ,
            uint256 updatedAt,
        ) = config.feed.latestRoundData();

        if (answer <= 0) revert InvalidPrice();

        // Staleness check — revert if price is too old
        if (block.timestamp - updatedAt > config.stalenessThreshold) {
            revert StalePrice(token, updatedAt, config.stalenessThreshold);
        }

        price = uint256(answer);
    }

    /// @notice Get price without reverting — returns 0 if stale or missing
    function getPriceSafe(address token) external view returns (uint256 price, bool valid) {
        FeedConfig memory config = feeds[token];
        if (!config.active) return (0, false);

        try config.feed.latestRoundData() returns (
            uint80, int256 answer, uint256, uint256 updatedAt, uint80
        ) {
            if (answer <= 0) return (0, false);
            if (block.timestamp - updatedAt > config.stalenessThreshold) return (0, false);
            return (uint256(answer), true);
        } catch {
            return (0, false);
        }
    }

    function deactivateFeed(address token) external onlyOwner {
        feeds[token].active = false;
        emit FeedDeactivated(token);
    }

    function getRegisteredTokens() external view returns (address[] memory) {
        return registeredTokens;
    }
}