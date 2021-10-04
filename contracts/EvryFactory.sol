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

    event feeToPlatformAddressUpdated(
        address sender,
        address newFeeToPlatform
    );

    event adminUpdated(
        address sender,
        address newAdmin
    );

    event platformFeeUpdated(
        address sender,
        uint256 newPlatformFee
    );

    event liquidityFeeUpdated(
        address sender,
        uint256 newliquidityFee
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
        require(feeToPlatform != address(0), "Evry: INVALID_TREASURY_ADDRESS");
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
        require(_feeToPlatform != address(0), "Evry: INVALID_TREASURY_ADDRESS");
        feeToPlatform = _feeToPlatform;
        emit feeToPlatformAddressUpdated(msg.sender, _feeToPlatform);
    }

    function setPlatformFee(uint256 feeBasis) external onlyOwner override {
        require(feeBasis <= 10000, "Evry: INVALID_RANGE_OF_FEE");
        feePlatformBasis = feeBasis;
        emit platformFeeUpdated(msg.sender, feeBasis);
    }

    function setLiquidityFee(uint256 feeBasis) external onlyOwner override {
        require(feeBasis <= 10000, "Evry: INVALID_RANGE_OF_FEE");
        feeLiquidityBasis = feeBasis;
        emit liquidityFeeUpdated(msg.sender, feeBasis);
    }

    function transferAdmin(address newAdmin) external onlyAdmin override {
        admin = newAdmin;
        emit adminUpdated(msg.sender, newAdmin);
    }

    function getFeeConfiguration() external override view returns (address _feeToPlatform, uint256 _feePlatformBasis, uint256 _feeLiquidityBasis)
    {
        _feeToPlatform = feeToPlatform;
        _feePlatformBasis = feePlatformBasis;
        _feeLiquidityBasis = feeLiquidityBasis;
    }
}
