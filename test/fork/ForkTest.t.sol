// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/governance/GovToken.sol";
import "../../src/core/Vault.sol";
import "../../src/oracle/PriceOracle.sol";
import "../../src/oracle/MockAggregator.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ForkTest is Test {
    // Deployed on Ethereum Sepolia
    address constant GOVTOKEN = 0xEEefFe6B263cEfA393c17956B5c7f858DfC5d8BF;
    address constant VAULT = 0xeAcE26701a6ee1DD2Efaf4e5A687c004B3c7d4C5;
    address constant ORACLE = 0x751da915beCFCF2Fa89d09c61f6a4e220Da7552b;
    address constant TIMELOCK = 0xAfFbc5496C53be9678Df73f773C3c9781b6D0e10;
    address constant GOVERNOR = 0x87A4FD656a5337014fFa31CeBC1Ef709FAD8D6C1;
    address constant DEPLOYER = 0xF0aAcf323267D465d1107f2ef055A13Af3Bd7acA;

    // Real Chainlink ETH/USD on Ethereum Sepolia
    address constant CHAINLINK_ETH_USD_SEPOLIA = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    uint256 sepoliaFork;

    function setUp() public {
        string memory rpc =
            vm.envOr("ETH_SEPOLIA_RPC_URL", string("https://eth-sepolia.g.alchemy.com/v2/iwDvR-bqVnt8x4WvHuT2b"));
        sepoliaFork = vm.createFork(rpc);
        vm.selectFork(sepoliaFork);
    }

    /// @dev Fork test 1: GovToken deployed and has correct supply
    function test_fork_govTokenDeployed() public view {
        GovToken token = GovToken(GOVTOKEN);
        assertEq(token.name(), "DeFi Gov Token");
        assertEq(token.symbol(), "DGT");
        assertGt(token.totalSupply(), 0);
        assertEq(token.balanceOf(DEPLOYER), 100_000 ether);
    }

    /// @dev Fork test 2: Vault deployed with correct asset
    function test_fork_vaultDeployed() public view {
        Vault vault = Vault(VAULT);
        assertEq(vault.asset(), GOVTOKEN);
        assertEq(vault.name(), "Protocol Vault");
        assertGe(vault.totalAssets(), 0);
    }

    /// @dev Fork test 3: Oracle deployed and owner is deployer
    function test_fork_oracleDeployed() public view {
        PriceOracle oracle = PriceOracle(ORACLE);
        assertEq(oracle.owner(), DEPLOYER);
    }

    /// @dev Fork test 4: Real Chainlink feed on Sepolia returns valid price
    function test_fork_chainlinkSepoliaFeed() public {
        PriceOracle oracle = PriceOracle(ORACLE);

        address weth = makeAddr("weth");
        vm.prank(DEPLOYER);
        oracle.registerFeed(weth, CHAINLINK_ETH_USD_SEPOLIA, 3600);

        uint256 price = oracle.getPrice(weth);
        assertGt(price, 100e8); // ETH > $100
        assertLt(price, 100_000e8); // ETH < $100,000
    }

    /// @dev Fork test 5: Deposit into deployed Vault works on fork
    function test_fork_depositIntoVault() public {
        GovToken token = GovToken(GOVTOKEN);
        Vault vault = Vault(VAULT);

        address user = makeAddr("forkUser");

        // Give user some tokens via deployer
        vm.prank(DEPLOYER);
        token.transfer(user, 1000 ether);

        vm.startPrank(user);
        token.approve(address(vault), 1000 ether);
        uint256 shares = vault.deposit(1000 ether, user);
        vm.stopPrank();

        assertGt(shares, 0);
        assertEq(vault.balanceOf(user), shares);
    }
}
