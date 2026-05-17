// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/ProtocolManagerV2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ProtocolManagerV2Test is Test {
    ProtocolManagerV2 public impl;
    ProtocolManagerV2 public proxy;
    address public owner = makeAddr("owner");
    address public feeRecipient = makeAddr("feeRecipient");

    function setUp() public {
        impl = new ProtocolManagerV2();

        bytes memory initData = abi.encodeWithSelector(ProtocolManagerV2.initializeV2.selector, feeRecipient, 30);
        ERC1967Proxy p = new ERC1967Proxy(address(impl), initData);
        proxy = ProtocolManagerV2(address(p));
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
        address proxyOwner = proxy.owner();
        vm.prank(proxyOwner);
        proxy.setProtocolFee(50);
        assertEq(proxy.protocolFee(), 50);
    }

    function test_v2_setProtocolFee_tooHigh_reverts() public {
        address proxyOwner = proxy.owner();
        vm.prank(proxyOwner);
        vm.expectRevert();
        proxy.setProtocolFee(1001);
    }

    function test_v2_emergencyPause() public {
        address proxyOwner = proxy.owner();
        vm.prank(proxyOwner);
        proxy.emergencyPause();
        assertTrue(proxy.emergencyPaused());
    }

    function test_v2_emergencyUnpause() public {
        address proxyOwner = proxy.owner();
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
        address proxyOwner = proxy.owner();
        vm.prank(proxyOwner);
        proxy.emergencyPause();
        vm.expectRevert();
        proxy.accrueFee(100);
    }

    function test_v2_setFeeRecipient_zeroAddress_reverts() public {
        address proxyOwner = proxy.owner();
        vm.prank(proxyOwner);
        vm.expectRevert();
        proxy.setFeeRecipient(address(0));
    }
}
