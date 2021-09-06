// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
import "./interfaces/IEvryFactory.sol";
import "./EvryPair.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EvryFactory is IEvryFactory, Ownable {
    address public override feeToPlatform;
    address public override admin;
    uint256 public override feePlatformBasis;
    uint256 public override feeLiquidityBasis;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    modifier onlyAdmin() {
        require(admin == msg.sender, "Evry: FORBIDDEN");
        _;
    }

    constructor(
        address _admin,
        uint256 _feePlatformBasis,
        uint256 _feeLiquidityBasis
    ) {
        admin = _admin;
        feePlatformBasis = _feePlatformBasis;
        feeLiquidityBasis = _feeLiquidityBasis;
    }

    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB)
        external
        onlyAdmin
        override
        returns (address pair)
    {
        require(tokenA != tokenB, "Evry: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "Evry: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "Evry: PAIR_EXISTS"); // single check is sufficient
        bytes memory bytecode = type(EvryPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IEvryPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }
    
    function setFeeToPlatform(address _feeToPlatform) external onlyOwner override {
        feeToPlatform = _feeToPlatform;
    }

    function setPlatformFee(uint256 feeBasis) external onlyOwner override {
        feePlatformBasis = feeBasis;
    }

    function setLiquidityFee(uint256 feeBasis) external onlyOwner override {
        feeLiquidityBasis = feeBasis;
    }

    function transferAdmin(address newAdmin) external onlyAdmin override {
        admin = newAdmin;
    }

    function getFeeConfiguration() external override view returns (address _feeToPlatform, uint256 _feePlatformBasis, uint256 _feeLiquidityBasis)
    {
        _feeToPlatform = feeToPlatform;
        _feePlatformBasis = feePlatformBasis;
        _feeLiquidityBasis = feeLiquidityBasis;
    }
}
