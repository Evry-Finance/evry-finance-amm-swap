// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

interface IEvryFactory {
    function feeToPlatform() external view returns (address);

    function feePlatformBasis() external view returns (uint256);

    function feeLiquidityBasis() external view returns (uint256);

    function getFeeConfiguration() external view returns (address _feeToPlatform, uint256 _feePlatformBasis, uint256 _feeLiquidityBasis);

    function admin() external view returns (address);

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);

    function setFeeToPlatform(address) external;

    function transferAdmin(address newAdmin) external;

    function setPlatformFee(uint256) external;

    function setLiquidityFee(uint256) external;
}
