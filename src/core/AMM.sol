// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title AMM — Constant Product Market Maker (x*y=k) with 0.3% fee
contract AMM is ERC20, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;

    uint256 public reserveA;
    uint256 public reserveB;

    uint256 public constant FEE_NUMERATOR = 997;
    uint256 public constant FEE_DENOMINATOR = 1000;
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpTokens);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpTokens);
    event Swap(address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut);

    error InsufficientLiquidity();
    error InsufficientOutputAmount();
    error InvalidToken();
    error SlippageExceeded();
    error ZeroAmount();

    constructor(address _tokenA, address _tokenB, address initialOwner)
        ERC20("AMM LP Token", "LP")
        Ownable(initialOwner)
    {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    /// @notice Add liquidity and receive LP tokens
    function addLiquidity(uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin)
        external
        nonReentrant
        returns (uint256 amountA, uint256 amountB, uint256 liquidity)
    {
        if (amountADesired == 0 || amountBDesired == 0) revert ZeroAmount();

        if (reserveA == 0 && reserveB == 0) {
            amountA = amountADesired;
            amountB = amountBDesired;
        } else {
            uint256 amountBOptimal = (amountADesired * reserveB) / reserveA;
            if (amountBOptimal <= amountBDesired) {
                if (amountBOptimal < amountBMin) revert SlippageExceeded();
                amountA = amountADesired;
                amountB = amountBOptimal;
            } else {
                uint256 amountAOptimal = (amountBDesired * reserveA) / reserveB;
                if (amountAOptimal < amountAMin) revert SlippageExceeded();
                amountA = amountAOptimal;
                amountB = amountBDesired;
            }
        }

        // Checks-Effects-Interactions
        uint256 totalSupply_ = totalSupply();
        if (totalSupply_ == 0) {
            liquidity = _sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
            _mint(address(0xdead), MINIMUM_LIQUIDITY); // lock minimum liquidity
        } else {
            liquidity = _min((amountA * totalSupply_) / reserveA, (amountB * totalSupply_) / reserveB);
        }

        if (liquidity == 0) revert InsufficientLiquidity();

        reserveA += amountA;
        reserveB += amountB;

        _mint(msg.sender, liquidity);

        tokenA.safeTransferFrom(msg.sender, address(this), amountA);
        tokenB.safeTransferFrom(msg.sender, address(this), amountB);

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }

    /// @notice Remove liquidity by burning LP tokens
    function removeLiquidity(uint256 lpAmount, uint256 amountAMin, uint256 amountBMin)
        external
        nonReentrant
        returns (uint256 amountA, uint256 amountB)
    {
        if (lpAmount == 0) revert ZeroAmount();

        uint256 totalSupply_ = totalSupply();
        amountA = (lpAmount * reserveA) / totalSupply_;
        amountB = (lpAmount * reserveB) / totalSupply_;

        if (amountA < amountAMin || amountB < amountBMin) revert SlippageExceeded();
        if (amountA == 0 || amountB == 0) revert InsufficientLiquidity();

        // Checks-Effects-Interactions
        reserveA -= amountA;
        reserveB -= amountB;

        _burn(msg.sender, lpAmount);

        tokenA.safeTransfer(msg.sender, amountA);
        tokenB.safeTransfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, lpAmount);
    }

    /// @notice Swap tokenA for tokenB or vice versa
    function swap(address tokenIn, uint256 amountIn, uint256 amountOutMin)
        external
        nonReentrant
        returns (uint256 amountOut)
    {
        if (tokenIn != address(tokenA) && tokenIn != address(tokenB)) revert InvalidToken();
        if (amountIn == 0) revert ZeroAmount();

        bool isTokenA = tokenIn == address(tokenA);

        uint256 reserveIn = isTokenA ? reserveA : reserveB;
        uint256 reserveOut = isTokenA ? reserveB : reserveA;

        // 0.3% fee applied
        uint256 amountInWithFee = amountIn * FEE_NUMERATOR;
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * FEE_DENOMINATOR + amountInWithFee);

        if (amountOut < amountOutMin) revert SlippageExceeded();
        if (amountOut == 0) revert InsufficientOutputAmount();

        // Checks-Effects-Interactions
        if (isTokenA) {
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        if (isTokenA) {
            tokenB.safeTransfer(msg.sender, amountOut);
        } else {
            tokenA.safeTransfer(msg.sender, amountOut);
        }

        emit Swap(msg.sender, tokenIn, amountIn, amountOut);
    }

    /// @notice Get expected output amount for a swap
    function getAmountOut(address tokenIn, uint256 amountIn) external view returns (uint256) {
        if (tokenIn != address(tokenA) && tokenIn != address(tokenB)) revert InvalidToken();
        bool isTokenA = tokenIn == address(tokenA);
        uint256 reserveIn = isTokenA ? reserveA : reserveB;
        uint256 reserveOut = isTokenA ? reserveB : reserveA;
        uint256 amountInWithFee = amountIn * FEE_NUMERATOR;
        return (amountInWithFee * reserveOut) / (reserveIn * FEE_DENOMINATOR + amountInWithFee);
    }

    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
