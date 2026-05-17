// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./AMM.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title AMMFactory — deploys AMM pairs using CREATE and CREATE2
contract AMMFactory is Ownable {
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(address indexed tokenA, address indexed tokenB, address pair, uint256 index);

    error PairExists();
    error IdenticalTokens();
    error ZeroAddress();

    constructor(address initialOwner) Ownable(initialOwner) {}

    /// @notice Deploy AMM pair using CREATE (address not predictable)
    function createPair(address tokenA, address tokenB) external onlyOwner returns (address pair) {
        if (tokenA == tokenB) revert IdenticalTokens();
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();

        // Sort tokens for consistent mapping
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        if (getPair[token0][token1] != address(0)) revert PairExists();

        // CREATE — standard deployment
        AMM amm = new AMM(token0, token1, msg.sender);
        pair = address(amm);

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    /// @notice Deploy AMM pair using CREATE2 (deterministic address)
    function createPairDeterministic(address tokenA, address tokenB, bytes32 salt)
        external
        onlyOwner
        returns (address pair)
    {
        if (tokenA == tokenB) revert IdenticalTokens();
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        if (getPair[token0][token1] != address(0)) revert PairExists();

        // CREATE2 — deterministic address based on salt
        bytes memory bytecode = abi.encodePacked(type(AMM).creationCode, abi.encode(token0, token1, msg.sender));

        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        require(pair != address(0), "CREATE2 failed");

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    /// @notice Predict CREATE2 address before deployment
    function predictPairAddress(address tokenA, address tokenB, bytes32 salt)
        external
        view
        returns (address predicted)
    {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        bytes memory bytecode = abi.encodePacked(type(AMM).creationCode, abi.encode(token0, token1, msg.sender));

        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode)));

        predicted = address(uint160(uint256(hash)));
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }
}
