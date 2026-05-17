// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/core/AMM.sol";
import "../src/core/AMMFactory.sol";
import "../src/core/Vault.sol";
import "../src/core/ProtocolManager.sol";
import "../src/governance/GovToken.sol";
import "../src/governance/DeFiGovernor.sol";
import "../src/governance/DeFiTimelock.sol";
import "../src/oracle/PriceOracle.sol";
import "../src/tokens/GameItems.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        // 1. GovToken
        GovToken govToken = new GovToken(deployer);
        console.log("GovToken:        ", address(govToken));

        // 2. Timelock — 2 days delay
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = deployer;
        executors[0] = deployer;
        DeFiTimelock timelock = new DeFiTimelock(2 days, proposers, executors, deployer);
        console.log("DeFiTimelock:    ", address(timelock));

        // 3. Governor
        DeFiGovernor governor = new DeFiGovernor(govToken, timelock);
        console.log("DeFiGovernor:    ", address(governor));

        // 4. ProtocolManagerV1 via UUPS proxy
        ProtocolManagerV1 pmImpl = new ProtocolManagerV1();
        bytes memory pmInit = abi.encodeWithSelector(ProtocolManagerV1.initialize.selector, deployer);
        ERC1967Proxy pmProxy = new ERC1967Proxy(address(pmImpl), pmInit);
        ProtocolManagerV1 pm = ProtocolManagerV1(address(pmProxy));
        console.log("ProtocolManager: ", address(pmProxy));

        // 5. PriceOracle
        PriceOracle oracle = new PriceOracle(deployer);
        console.log("PriceOracle:     ", address(oracle));

        // 6. AMMFactory
        AMMFactory factory = new AMMFactory(deployer);
        console.log("AMMFactory:      ", address(factory));

        // 7. GameItems ERC-1155
        GameItems items = new GameItems(deployer);
        console.log("GameItems:       ", address(items));

        // 8. Vault ERC-4626 (GovToken as underlying, 0.1% fee)
        Vault vault = new Vault(IERC20(address(govToken)), "Protocol Vault", "pvTKN", deployer, deployer, 10);
        console.log("Vault:           ", address(vault));

        // 9. Register contracts in ProtocolManager
        pm.registerOracle(address(oracle));
        pm.registerVault(address(vault));
        pm.registerGovToken(address(govToken));

        // 10. Grant Governor roles on Timelock
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(governor));

        vm.stopBroadcast();

        // Save deployed addresses
        string memory out = string.concat(
            "GOVTOKEN=",
            vm.toString(address(govToken)),
            "\n",
            "TIMELOCK=",
            vm.toString(address(timelock)),
            "\n",
            "GOVERNOR=",
            vm.toString(address(governor)),
            "\n",
            "PROTOCOL_MANAGER=",
            vm.toString(address(pmProxy)),
            "\n",
            "ORACLE=",
            vm.toString(address(oracle)),
            "\n",
            "FACTORY=",
            vm.toString(address(factory)),
            "\n",
            "GAMEITEMS=",
            vm.toString(address(items)),
            "\n",
            "VAULT=",
            vm.toString(address(vault)),
            "\n"
        );
        vm.writeFile("deployed-addresses.txt", out);
        console.log("Addresses saved to deployed-addresses.txt");
    }
}
