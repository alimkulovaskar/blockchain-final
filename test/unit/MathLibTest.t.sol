// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/MathLib.sol";

contract MathLibTest is Test {
    MathLib math;

    function setUp() public {
        math = new MathLib();
    }

    function test_sqrtAssembly_zero() public view {
        assertEq(math.sqrtAssembly(0), 0);
    }

    function test_sqrtAssembly_one() public view {
        assertEq(math.sqrtAssembly(1), 1);
    }

    function test_sqrtAssembly_four() public view {
        assertEq(math.sqrtAssembly(4), 2);
    }

    function test_sqrtAssembly_large() public view {
        assertEq(math.sqrtAssembly(100), 10);
    }

    function test_sqrtMatchesSolidity(uint128 x) public view {
    vm.assume(x == 0 || x >= 4);
    assertEq(math.sqrtAssembly(x), math.sqrtSolidity(x));
}

    function test_minAssembly() public view {
        assertEq(math.minAssembly(3, 5), 3);
        assertEq(math.minAssembly(5, 3), 3);
        assertEq(math.minAssembly(4, 4), 4);
    }

    function test_minMatchesSolidity(uint128 a, uint128 b) public view {
        assertEq(math.minAssembly(a, b), math.minSolidity(a, b));
    }

    function test_maxAssembly() public view {
        assertEq(math.maxAssembly(3, 5), 5);
        assertEq(math.maxAssembly(5, 3), 5);
        assertEq(math.maxAssembly(4, 4), 4);
    }

    function test_maxMatchesSolidity(uint128 a, uint128 b) public view {
        assertEq(math.maxAssembly(a, b), math.maxSolidity(a, b));
    }

    function test_mulDivAssembly() public view {
        assertEq(math.mulDivAssembly(10, 5, 2), 25);
        assertEq(math.mulDivAssembly(100, 3, 10), 30);
    }

    function test_mulDivMatchesSolidity(uint64 a, uint64 b, uint64 c) public view {
        vm.assume(c > 0);
        assertEq(math.mulDivAssembly(a, b, c), math.mulDivSolidity(a, b, c));
    }

    function test_revert_mulDivAssembly_divByZero() public {
        vm.expectRevert();
        math.mulDivAssembly(1, 1, 0);
    }
}