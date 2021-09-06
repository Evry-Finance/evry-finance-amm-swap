// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import './IEvryERC20.sol';

interface IEvryPair is IEvryERC20{
    
    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(
        uint[2] memory amountOut,
        address to, 
        address feeToPlatform, 
        uint feePlatformBasis, 
        uint feeLiquidityBasis,
        bytes calldata data ) 
    external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}
