// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/AMMFactory.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract AMMFactoryTest is Test {
    AMMFactory factory;
    MockERC20 tokenA;
    MockERC20 tokenB;
    MockERC20 tokenC;
    address owner = address(this);

    function setUp() public {
        factory = new AMMFactory(owner);
        tokenA = new MockERC20("TokenA", "TKA");
        tokenB = new MockERC20("TokenB", "TKB");
        tokenC = new MockERC20("TokenC", "TKC");
    }

    function test_createPair() public {
        address pair = factory.createPair(address(tokenA), address(tokenB));
        assertTrue(pair != address(0));
        assertEq(factory.allPairsLength(), 1);
    }

    function test_createPair_storesMapping() public {
        address pair = factory.createPair(address(tokenA), address(tokenB));
        (address t0, address t1) =
            address(tokenA) < address(tokenB) ? (address(tokenA), address(tokenB)) : (address(tokenB), address(tokenA));
        assertEq(factory.getPair(t0, t1), pair);
        assertEq(factory.getPair(t1, t0), pair);
    }

    function test_createPair_reverseOrder() public {
        address pair1 = factory.createPair(address(tokenA), address(tokenB));
        assertEq(factory.allPairsLength(), 1);
        assertTrue(pair1 != address(0));
    }

    function test_revert_createPair_identical() public {
        vm.expectRevert(AMMFactory.IdenticalTokens.selector);
        factory.createPair(address(tokenA), address(tokenA));
    }

    function test_revert_createPair_zeroAddress() public {
        vm.expectRevert(AMMFactory.ZeroAddress.selector);
        factory.createPair(address(0), address(tokenA));
    }

    function test_revert_createPair_pairExists() public {
        factory.createPair(address(tokenA), address(tokenB));
        vm.expectRevert(AMMFactory.PairExists.selector);
        factory.createPair(address(tokenA), address(tokenB));
    }

    function test_revert_createPair_notOwner() public {
        vm.prank(address(0xBEEF));
        vm.expectRevert();
        factory.createPair(address(tokenA), address(tokenB));
    }

    function test_createPairDeterministic() public {
        bytes32 salt = keccak256("test-salt");
        address pair = factory.createPairDeterministic(address(tokenA), address(tokenB), salt);
        assertTrue(pair != address(0));
        assertEq(factory.allPairsLength(), 1);
    }

    function test_predictPairAddress() public {
        bytes32 salt = keccak256("test-salt");
        address predicted = factory.predictPairAddress(address(tokenA), address(tokenB), salt);
        address actual = factory.createPairDeterministic(address(tokenA), address(tokenB), salt);
        assertEq(predicted, actual);
    }

    function test_revert_deterministicPairExists() public {
        bytes32 salt = keccak256("salt");
        factory.createPairDeterministic(address(tokenA), address(tokenB), salt);
        vm.expectRevert(AMMFactory.PairExists.selector);
        factory.createPairDeterministic(address(tokenA), address(tokenB), salt);
    }

    function test_allPairsLength() public {
        assertEq(factory.allPairsLength(), 0);
        factory.createPair(address(tokenA), address(tokenB));
        assertEq(factory.allPairsLength(), 1);
        factory.createPair(address(tokenA), address(tokenC));
        assertEq(factory.allPairsLength(), 2);
    }
}
