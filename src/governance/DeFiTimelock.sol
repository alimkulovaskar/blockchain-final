// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title DeFiTimelock — 2-day delay timelock for DAO governance
contract DeFiTimelock is TimelockController {
    /// @param minDelay 2 days = 172800 seconds
    /// @param proposers list of addresses that can propose (Governor)
    /// @param executors list of addresses that can execute (address(0) = anyone)
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    )
        TimelockController(minDelay, proposers, executors, admin)
    {}
}