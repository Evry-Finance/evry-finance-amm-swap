// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "../interfaces/IEvryPair.sol";
import "../interfaces/IEvryFactory.sol";

import "./SafeMath.sol";

library EvryLibrary {
    using SafeMath for uint256;

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        require(tokenA != tokenB, "EvryLibrary: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "EvryLibrary: ZERO_ADDRESS");
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(
        address factory,
        address tokenA,
        address tokenB
    ) internal view returns (address pair) {
        pair = IEvryFactory(factory).getPair(tokenA, tokenB);
    }

    // fetches and sorts the reserves for a pair
    function getReserves(
        address factory,
        address tokenA,
        address tokenB
    ) internal view returns (uint256 reserveA, uint256 reserveB) {
        (address token0, ) = sortTokens(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1, ) =
            IEvryPair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
    }

    function calculatePlatformFee(address factory, uint256 amountIn)
        internal
        view
        returns (uint256 platformFeeAmount)
    {
        uint256 feePlatformBasis = IEvryFactory(factory).feePlatformBasis();
        uint256 denominator = amountIn.mul(feePlatformBasis);
        platformFeeAmount = denominator / 10000;
    }

    function getBasisTotalFee(address factory)
        internal
        view
        returns (uint256 totalFee)
    {
        uint256 platformFee = IEvryFactory(factory).feePlatformBasis();
        uint256 protocalFee = IEvryFactory(factory).feeLiquidityBasis();
        totalFee = platformFee.add(protocalFee);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) internal pure returns (uint256 amountB) {
        require(amountA > 0, "EvryLibrary: INSUFFICIENT_AMOUNT");
        require(
            reserveA > 0 && reserveB > 0,
            "EvryLibrary: INSUFFICIENT_LIQUIDITY"
        );
        amountB = amountA.mul(reserveB) / reserveA;
    }

     // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut, uint feeAmount) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'EvryLibrary: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'EvryLibrary: INSUFFICIENT_LIQUIDITY');
        uint256 feeMuiltiplier = 10000 - feeAmount;
        uint amountInWithFee = amountIn.mul(feeMuiltiplier);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(10000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut, uint feeAmount) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'EvryLibrary: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'EvryLibrary: INSUFFICIENT_LIQUIDITY');
        uint256 feeMuiltiplier = 10000 - feeAmount;
        uint numerator = reserveIn.mul(amountOut).mul(10000);
        uint denominator = reserveOut.sub(amountOut).mul(feeMuiltiplier);
        amountIn = (numerator / denominator).add(1);
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'EvryLibrary: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        uint feeAmount = getBasisTotalFee(factory);
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut, feeAmount);
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'EvryLibrary: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            uint feeAmount = getBasisTotalFee(factory);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut, feeAmount);
        }
    }
}
