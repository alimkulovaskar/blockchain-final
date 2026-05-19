// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../../src/core/ProtocolManager.sol";

contract ProtocolManagerV1Test is Test {
    ProtocolManagerV1 impl;
    ProtocolManagerV1 pm;
    address owner = address(this);
    address dummy = address(0x1234);

    function setUp() public {
        impl = new ProtocolManagerV1();
        bytes memory data = abi.encodeCall(ProtocolManagerV1.initialize, (owner));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), data);
        pm = ProtocolManagerV1(address(proxy));
    }

    function test_initialize() public view {
        assertEq(pm.version(), 1);
        assertEq(pm.owner(), owner);
    }

    function test_registerAMM() public {
        pm.registerAMM(dummy);
        assertEq(pm.amm(), dummy);
    }

    function test_registerVault() public {
        pm.registerVault(dummy);
        assertEq(pm.vault(), dummy);
    }

    function test_registerOracle() public {
        pm.registerOracle(dummy);
        assertEq(pm.oracle(), dummy);
    }

    function test_registerGovToken() public {
        pm.registerGovToken(dummy);
        assertEq(pm.govToken(), dummy);
    }

    function test_setWhitelisted() public {
        pm.setWhitelisted(dummy, true);
        assertTrue(pm.whitelisted(dummy));
        pm.setWhitelisted(dummy, false);
        assertFalse(pm.whitelisted(dummy));
    }

    function test_pause_unpause() public {
        pm.pause();
        assertTrue(pm.paused());
        pm.unpause();
        assertFalse(pm.paused());
    }

    function test_revert_registerAMM_zero() public {
        vm.expectRevert(ProtocolManagerV1.ZeroAddress.selector);
        pm.registerAMM(address(0));
    }

    function test_revert_registerVault_zero() public {
        vm.expectRevert(ProtocolManagerV1.ZeroAddress.selector);
        pm.registerVault(address(0));
    }

    function test_revert_registerOracle_zero() public {
        vm.expectRevert(ProtocolManagerV1.ZeroAddress.selector);
        pm.registerOracle(address(0));
    }

    function test_revert_registerGovToken_zero() public {
        vm.expectRevert(ProtocolManagerV1.ZeroAddress.selector);
        pm.registerGovToken(address(0));
    }

    function test_revert_notOwner() public {
        vm.prank(address(0xBEEF));
        vm.expectRevert();
        pm.registerAMM(dummy);
    }
}
