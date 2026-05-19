// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/governance/DeFiGovernor.sol";
import "../src/governance/DeFiTimelock.sol";
import "../src/governance/GovToken.sol";
import "../src/core/ProtocolManager.sol";

contract Verify is Script {
    address constant GOVTOKEN  = 0xEEefFe6B263cEfA393c17956B5c7f858DfC5d8BF;
    address constant TIMELOCK  = 0xAfFbc5496C53be9678Df73f773C3c9781b6D0e10;
    address constant GOVERNOR  = 0x87A4FD656a5337014fFa31CeBC1Ef709FAD8D6C1;
    address constant PM_PROXY  = 0x82E33108315B371D9b39778155236d8EF5d811d9;
    address constant DEPLOYER  = 0xF0aAcf323267D465d1107f2ef055A13Af3Bd7acA;

    function run() external view {
        DeFiGovernor gov      = DeFiGovernor(payable(GOVERNOR));
        DeFiTimelock timelock = DeFiTimelock(payable(TIMELOCK));
        GovToken token        = GovToken(GOVTOKEN);
        ProtocolManagerV1 pm  = ProtocolManagerV1(PM_PROXY);

        console.log("=== Post-Deployment Verification ===");

        // 1. Timelock delay = 2 days
        uint256 delay = timelock.getMinDelay();
        require(delay == 2 days, "FAIL: Timelock delay != 2 days");
        console.log("[OK] Timelock delay:", delay, "seconds (2 days)");

        // 2. Governor voting delay = 1 day
        uint256 vDelay = gov.votingDelay();
        require(vDelay == 1 days, "FAIL: Voting delay != 1 day");
        console.log("[OK] Voting delay:", vDelay, "seconds (1 day)");

        // 3. Governor voting period = 1 week
        uint256 vPeriod = gov.votingPeriod();
        require(vPeriod == 1 weeks, "FAIL: Voting period != 1 week");
        console.log("[OK] Voting period:", vPeriod, "seconds (1 week)");

        // 4. GovToken owner is deployer
        require(token.owner() == DEPLOYER, "FAIL: GovToken owner != deployer");
        console.log("[OK] GovToken owner:", token.owner());

        // 5. Governor has PROPOSER role on Timelock
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        require(timelock.hasRole(proposerRole, GOVERNOR), "FAIL: Governor missing PROPOSER role");
        console.log("[OK] Governor has PROPOSER role on Timelock");

        // 6. Governor has EXECUTOR role on Timelock
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        require(timelock.hasRole(executorRole, GOVERNOR), "FAIL: Governor missing EXECUTOR role");
        console.log("[OK] Governor has EXECUTOR role on Timelock");

        // 7. ProtocolManager version = 1
        require(pm.version() == 1, "FAIL: ProtocolManager version != 1");
        console.log("[OK] ProtocolManager version:", pm.version());

        // 8. GovToken max supply = 1M
        require(token.MAX_SUPPLY() == 1_000_000 ether, "FAIL: Wrong max supply");
        console.log("[OK] GovToken MAX_SUPPLY: 1,000,000 DGT");

        console.log("=== ALL CHECKS PASSED ===");
    }
}