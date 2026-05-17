// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/ProtocolManagerV2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ProtocolManagerV2Test is Test {
    ProtocolManagerV2 public impl;
    ProtocolManagerV2 public proxy;
    address public proxyOwner;
    address public feeRecipient = makeAddr("feeRecipient");

    function setUp() public {
        impl = new ProtocolManagerV2();
        bytes memory initData = abi.encodeWithSelector(
            ProtocolManagerV2.initializeV2.selector, feeRecipient, 30
        );
        ERC1967Proxy p = new ERC1967Proxy(address(impl), initData);
        proxy = ProtocolManagerV2(address(p));
        proxyOwner = proxy.owner();
    }

    function test_v2_version() public view {
        assertEq(proxy.getVersion(), "2.0.0");
    }

    function test_v2_protocolFee() public view {
        assertEq(proxy.protocolFee(), 30);
    }

    function test_v2_feeRecipient() public view {
        assertEq(proxy.feeRecipient(), feeRecipient);
    }

    function test_v2_setProtocolFee() public {
        vm.prank(proxyOwner);
        proxy.setProtocolFee(50);
        assertEq(proxy.protocolFee(), 50);
    }

    function test_v2_setProtocolFee_tooHigh_reverts() public {
        vm.prank(proxyOwner);
        vm.expectRevert();
        proxy.setProtocolFee(1001);
    }

    function test_v2_emergencyPause() public {
        vm.prank(proxyOwner);
        proxy.emergencyPause();
        assertTrue(proxy.emergencyPaused());
    }

    function test_v2_emergencyUnpause() public {
        vm.prank(proxyOwner);
        proxy.emergencyPause();
        vm.prank(proxyOwner);
        proxy.emergencyUnpause();
        assertFalse(proxy.emergencyPaused());
    }

    function test_v2_accrueFee() public {
        proxy.accrueFee(100);
        assertEq(proxy.totalFeesCollected(), 100);
    }

    function test_v2_accrueFee_blockedWhenPaused() public {
        vm.prank(proxyOwner);
        proxy.emergencyPause();
        vm.expectRevert();
        proxy.accrueFee(100);
    }

    function test_v2_setFeeRecipient_zeroAddress_reverts() public {
        vm.prank(proxyOwner);
        vm.expectRevert();
        proxy.setFeeRecipient(address(0));
    }

    function test_v2_registerAMM() public {
        vm.prank(proxyOwner);
        proxy.registerAMM(address(0x1));
        assertEq(proxy.amm(), address(0x1));
    }

    function test_v2_registerVault() public {
        vm.prank(proxyOwner);
        proxy.registerVault(address(0x1));
        assertEq(proxy.vault(), address(0x1));
    }

    function test_v2_registerOracle() public {
        vm.prank(proxyOwner);
        proxy.registerOracle(address(0x1));
        assertEq(proxy.oracle(), address(0x1));
    }

    function test_v2_registerGovToken() public {
        vm.prank(proxyOwner);
        proxy.registerGovToken(address(0x1));
        assertEq(proxy.govToken(), address(0x1));
    }

    function test_v2_setWhitelisted() public {
        vm.prank(proxyOwner);
        proxy.setWhitelisted(address(0x1), true);
        assertTrue(proxy.whitelisted(address(0x1)));
    }

    function test_v2_pause_unpause() public {
        vm.prank(proxyOwner);
        proxy.pause();
        assertTrue(proxy.paused());
        vm.prank(proxyOwner);
        proxy.unpause();
        assertFalse(proxy.paused());
    }

    function test_v2_revert_registerAMM_zero() public {
        vm.prank(proxyOwner);
        vm.expectRevert(ProtocolManagerV2.ZeroAddress.selector);
        proxy.registerAMM(address(0));
    }

    function test_v2_accrueFee_whenEmergencyPaused_reverts() public {
        vm.prank(proxyOwner);
        proxy.emergencyPause();
        vm.expectRevert(ProtocolManagerV2.EmergencyStop.selector);
        proxy.accrueFee(100);
    }

    function test_v2_setFeeRecipient() public {
        address newRecipient = makeAddr("newRecipient");
        vm.prank(proxyOwner);
        proxy.setFeeRecipient(newRecipient);
        assertEq(proxy.feeRecipient(), newRecipient);
    }
}