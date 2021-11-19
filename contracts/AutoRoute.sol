
//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.6;
pragma abicoder v2;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "./interfaces/IEvryRouter2.sol";
import "./external/dmm/IDMMRouter02.sol";

contract AutoRoute is OwnableUpgradeable {

    address public ammRouterAddress;
    address public dmmRouterAddress;
    address public WBNB;
    uint256 constant MAXUINT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    event NativeReceived(address sender, uint amount);
    event RouterChanged(address sender, address router);
    event TokenApproved(address sender, address token, address router);

    function initialize(address _ammRouter, address _dmmRouter, address _wbnb) public initializer {
        __Ownable_init();
        ammRouterAddress = _ammRouter;
        dmmRouterAddress = _dmmRouter;
        WBNB = _wbnb;
    }

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'AutoRoute: EXPIRED');
        _;
    }

    function approveRouter(IERC20 _token, address _routerAddress) external onlyOwner {
        _token.approve(address(_routerAddress), MAXUINT);
        emit TokenApproved(msg.sender, address(_token), _routerAddress);
    }

    function setAmmRouterAddress(address _ammRouterAddress) external onlyOwner {
        ammRouterAddress = _ammRouterAddress;
        emit RouterChanged(msg.sender, _ammRouterAddress);
    }

    function setDmmRouterAddress(address _dmmRouterAddress) external onlyOwner {
        dmmRouterAddress = _dmmRouterAddress;
        emit RouterChanged(msg.sender, _dmmRouterAddress);
    }

    receive() external payable {
        emit NativeReceived(msg.sender, msg.value);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin, 
        address[] memory paths, 
        string[] memory poolType, 
        address[] memory dmmPoolAddresses,
        address to,
        uint256 deadline
    ) 
        external
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        uint256[] memory amountsOut = getAmountsOut(amountIn, paths, poolType, dmmPoolAddresses);
        require(amountsOut[amountsOut.length - 1] >= amountOutMin, 'AutoRoute: INSUFFICIENT_OUTPUT_AMOUNT');
        
        IERC20(paths[0]).transferFrom(msg.sender, address(this), amountIn);
        
        amounts = swapExactAnyForAny(
            amountIn,
            paths, 
            poolType, 
            dmmPoolAddresses
        );

        require(amounts[amounts.length - 1] >= amountOutMin, 'AutoRoute: INSUFFICIENT_OUTPUT_AMOUNT');
        IERC20(paths[paths.length - 1]).transfer(to, amounts[amounts.length - 1]);
        return amounts;
    }

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] memory paths, 
        string[] memory poolType, 
        address[] memory dmmPoolAddresses,
        address to,
        uint256 deadline
    ) 
        external
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        
        uint256[] memory amountsIn = getAmountsIn(amountOut, paths, poolType, dmmPoolAddresses);
        require(amountInMax >= amountsIn[0], "AutoRoute: EXCESSIVE_INPUT_AMOUNT");
        
        IERC20(paths[0]).transferFrom(msg.sender, address(this), amountsIn[0]);

        amounts = swapAnyForExactAny(
            amountsIn,
            amountInMax,
            paths,
            poolType,
            dmmPoolAddresses
        );

        IERC20(paths[paths.length - 1]).transfer(to, amounts[amounts.length - 1]);
        return amounts;
    }

    // ------------------------------------ NATIVE ------------------------------------------- //

    // 1 BNB > ? USDT
    function swapExactNativeForTokens(
        uint amountOutMin, 
        address[] memory paths, 
        string[] memory poolType, 
        address[] memory dmmPoolAddresses,
        address to, 
        uint deadline
    )
        external
        payable
        ensure(deadline)
        returns (uint[] memory amounts)  
    {
        require(paths[0] == WBNB, "AutoRoute: INVALID_PATH");
        uint256[] memory amountsOut = getAmountsOut(msg.value, paths, poolType, dmmPoolAddresses);
        require(amountsOut[amountsOut.length - 1] >= amountOutMin, 'AutoRoute: INSUFFICIENT_OUTPUT_AMOUNT');

        amounts = swapExactAnyForAny(
            msg.value,  
            paths, 
            poolType, 
            dmmPoolAddresses
        );

        require(amounts[amounts.length - 1] >= amountOutMin, 'AutoRoute: INSUFFICIENT_OUTPUT_AMOUNT');
        IERC20(paths[paths.length - 1]).transfer(to, amounts[amounts.length - 1]);
     
        return amounts;
    }

    // ? BNB > 1 USDT
    function swapNativeForExactTokens(
        uint amountOut, 
        address[] memory paths, 
        string[] memory poolType, 
        address[] memory dmmPoolAddresses,
        address to, 
        uint deadline
    )
        external
        payable
        ensure(deadline)
        returns (uint[] memory amounts)  
    {
        require(paths[0] == WBNB, "AutoRoute: INVALID_PATH");
        uint256[] memory amountsIn = getAmountsIn(amountOut, paths, poolType, dmmPoolAddresses);
        require(msg.value >= amountsIn[0], 'AutoRoute: EXCESSIVE_INPUT_AMOUNT');

        amounts = swapAnyForExactAny(
            amountsIn,
            msg.value,
            paths, 
            poolType, 
            dmmPoolAddresses
        );
        IERC20(paths[paths.length - 1]).transfer(to, amounts[amounts.length - 1]);
        if (msg.value > amountsIn[0]) {
            TransferHelper.safeTransferETH(to, msg.value - amountsIn[0]);
        } 
     
        return amounts;
    }

    // 1 USDT > ? BNB
    function swapExactTokensForNative(
        uint amountIn, 
        uint amountOutMin,
        address[] memory paths, 
        string[] memory poolType, 
        address[] memory dmmPoolAddresses,
        address to, 
        uint deadline
    )
        external
        ensure(deadline)
        returns (uint[] memory amounts)
    { 
        require(paths[paths.length - 1] == WBNB, "AutoRoute: INVALID_PATH");
        uint256[] memory amountsOut = getAmountsOut(amountIn, paths, poolType, dmmPoolAddresses);
        require(amountsOut[amountsOut.length - 1] >= amountOutMin, 'AutoRoute: INSUFFICIENT_OUTPUT_AMOUNT');
        
        IERC20(paths[0]).transferFrom(msg.sender, address(this), amountIn);
        
        amounts = swapExactAnyForAny(
            amountIn,  
            paths, 
            poolType, 
            dmmPoolAddresses
        );

        require(amounts[amounts.length - 1] >= amountOutMin, 'AutoRoute: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);

        return amounts;
    }

    // ? USDT > 1 BNB
    function swapTokensForExactNative(
        uint amountOut, 
        uint amountInMax, 
        address[] memory paths, 
        string[] memory poolType, 
        address[] memory dmmPoolAddresses,
        address to, 
        uint deadline
    )
        external
        ensure(deadline)
        returns (uint[] memory amounts)
    { 
        require(paths[paths.length - 1] == WBNB, "AutoRoute: INVALID_PATH");
        uint256[] memory amountsIn = getAmountsIn(amountOut, paths, poolType, dmmPoolAddresses);
        require(amountInMax >= amountsIn[0], 'AutoRoute: EXCESSIVE_INPUT_AMOUNT');
        
        IERC20(paths[0]).transferFrom(msg.sender, address(this), amountsIn[0]);
        
        amounts = swapAnyForExactAny(
            amountsIn,
            amountInMax, 
            paths, 
            poolType, 
            dmmPoolAddresses
        );
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);

        return amounts;
    }

    function getAmountsOut(
        uint256 amountIn, 
        address[] memory paths, 
        string[] memory poolType, 
        address[] memory dmmPoolAddresses
    )
        public
        view
        returns (uint256[] memory amounts)
    {
        amounts = new uint256[](paths.length);
        amounts[0] = amountIn;
        uint256 _amountIn = amountIn;
        uint256 dmmPoolIndex = 0;
        for (uint i = 0; i < paths.length - 1; i++) {
            uint256[] memory amountOuts;
            if (compareStrings(poolType[i], "AMM") 
                || (compareStrings(poolType[i], "BOTH") && compareStrings(poolType[i + 1], "AMM"))
                || (compareStrings(poolType[i], "BOTH") && compareStrings(poolType[i + 1], "BOTH"))) {
                
                address[] memory _paths = new address[](2);
                _paths[0] = paths[i];
                _paths[1] = paths[i + 1];    
                amountOuts = IEvryRouter2(ammRouterAddress)
                    .getAmountsOut(_amountIn, _paths);
            } else if (compareStrings(poolType[i], "DMM") 
                    || (compareStrings(poolType[i], "BOTH") && compareStrings(poolType[i + 1], "DMM"))) {
                
                IERC20[] memory _paths = new IERC20[](2);
                _paths[0] = IERC20(paths[i]);
                _paths[1] = IERC20(paths[i + 1]);
                address[] memory _poolAddress = new address[](1);
                _poolAddress[0] = dmmPoolAddresses[dmmPoolIndex++];  
                amountOuts = IDMMRouter02(dmmRouterAddress)
                    .getAmountsOut(_amountIn, _poolAddress, _paths);
            }
            amounts[i + 1] = amountOuts[1];
            _amountIn = amountOuts[1];
        }

        return amounts;
    }

    function getAmountsIn(
        uint256 amountOut,
        address[] memory paths,
        string[] memory poolType, 
        address[] memory dmmPoolAddresses
    )
        public
        view
        returns (uint256[] memory amounts)
    {   

        amounts = new uint256[](paths.length);
        amounts[paths.length - 1] = amountOut;
        uint256 _amountOut = amountOut;
        uint256 dmmPoolIndex = dmmPoolAddresses.length - 1;
        for (uint256 i = paths.length - 1; i > 0; i--) {
            uint256[] memory amountIns;
            if (compareStrings(poolType[i], "AMM") 
                || (compareStrings(poolType[i], "BOTH") && compareStrings(poolType[i - 1], "AMM"))
                || (compareStrings(poolType[i], "BOTH") && compareStrings(poolType[i - 1], "BOTH"))) {
                
                address[] memory _paths = new address[](2);
                _paths[1] = paths[i];
                _paths[0] = paths[i - 1];
                amountIns = IEvryRouter2(ammRouterAddress)
                    .getAmountsIn(_amountOut, _paths);
            } else if (compareStrings(poolType[i], "DMM") 
                    || (compareStrings(poolType[i], "BOTH") && compareStrings(poolType[i - 1], "DMM"))) {
                
                IERC20[] memory _paths = new IERC20[](2);
                _paths[1] = IERC20(paths[i]);
                _paths[0] = IERC20(paths[i - 1]);
                address[] memory _poolAddress = new address[](1);
                _poolAddress[0] = dmmPoolAddresses[dmmPoolIndex--];  
                amountIns = IDMMRouter02(dmmRouterAddress)
                    .getAmountsIn(_amountOut, _poolAddress, _paths);
            }
            amounts[i - 1] = amountIns[0];
            _amountOut = amountIns[0];
         
        }
        return amounts;
    }

    function compareStrings(string memory a, string memory b) private pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function swapExactAnyForAny(
        uint256 amountIn,
        address[] memory paths, 
        string[] memory poolType, 
        address[] memory dmmPoolAddresses
    ) 
        internal
        returns (uint256[] memory amounts)
    {
        uint256 _amountIn = amountIn;
        uint256 dmmPoolIndex = 0;
        uint256[] memory amountOut;
        amounts = new uint256[](paths.length);
        for (uint i = 0; i < paths.length - 1; i++) {
            if (compareStrings(poolType[i], "AMM") 
                || (compareStrings(poolType[i], "BOTH") && compareStrings(poolType[i + 1], "AMM"))
                || (compareStrings(poolType[i], "BOTH") && compareStrings(poolType[i + 1], "BOTH"))) {

                address[] memory swapPath = new address[](2);
                swapPath[0] = paths[i];
                swapPath[1] = paths[i + 1];
                if (swapPath[0] != WBNB && swapPath[1] != WBNB) {
                    amountOut = IEvryRouter2(ammRouterAddress).swapExactTokensForTokens(
                        _amountIn, 
                        0, 
                        swapPath, 
                        address(this), 
                        block.timestamp
                    );    
                } else if (swapPath[0] == WBNB) {
                    amountOut = IEvryRouter2(ammRouterAddress).swapExactETHForTokens{value: _amountIn}(
                        0, 
                        swapPath, 
                        address(this), 
                        block.timestamp
                    );
                } else if (swapPath[1] == WBNB) {
                    amountOut = IEvryRouter2(ammRouterAddress).swapExactTokensForETH(
                        _amountIn,
                        0, 
                        swapPath, 
                        address(this), 
                        block.timestamp
                    );
                }
            } else if (compareStrings(poolType[i], "DMM")
                || (compareStrings(poolType[i], "BOTH") && compareStrings(poolType[i + 1], "DMM"))) {
                    
                IERC20[] memory dmmSwapPath = new IERC20[](2);
                dmmSwapPath[0] = IERC20(paths[i]);
                dmmSwapPath[1] = IERC20(paths[i + 1]);
                address[] memory _poolAddress = new address[](1);
                _poolAddress[0] = dmmPoolAddresses[dmmPoolIndex++];
                amountOut = IDMMRouter02(dmmRouterAddress).swapExactTokensForTokens(
                    _amountIn, 
                    0, 
                    _poolAddress, 
                    dmmSwapPath, 
                    address(this), 
                    block.timestamp
                );
            }
            if (i == 0) {
                amounts[0] = amountOut[0];
            }
            amounts[i + 1] = amountOut[1];
            _amountIn = amountOut[1];
        }
        return amounts;
    }

    function swapAnyForExactAny(
        uint256[] memory amountsOut,
        uint256 amountInMax,
        address[] memory paths, 
        string[] memory poolType, 
        address[] memory dmmPoolAddresses
    ) 
        internal
        returns (uint256[] memory amounts)
    {
        uint256 _amountOut = amountsOut[1];
        uint256 _amountInMax = amountInMax;
        uint256 dmmPoolIndex = 0;
        uint256[] memory amountIn;
        amounts = new uint256[](paths.length);
        for (uint i = 0; i < paths.length - 1; i++) {
            if (compareStrings(poolType[i], "AMM") 
                || (compareStrings(poolType[i], "BOTH") && compareStrings(poolType[i + 1], "AMM"))
                || (compareStrings(poolType[i], "BOTH") && compareStrings(poolType[i + 1], "BOTH"))) {

                address[] memory swapPath = new address[](2);
                swapPath[0] = paths[i];
                swapPath[1] = paths[i + 1];
                if (swapPath[0] != WBNB && swapPath[1] != WBNB) {
                    amountIn = IEvryRouter2(ammRouterAddress).swapTokensForExactTokens(
                        _amountOut, 
                        _amountInMax, 
                        swapPath, 
                        address(this), 
                        block.timestamp
                    );    
                } else if (swapPath[0] == WBNB) {
                    amountIn = IEvryRouter2(ammRouterAddress).swapETHForExactTokens{value: _amountInMax}(
                        _amountOut, 
                        swapPath, 
                        address(this), 
                        block.timestamp
                    );
                } else if (swapPath[1] == WBNB) {
                    amountIn = IEvryRouter2(ammRouterAddress).swapTokensForExactETH(
                        _amountOut,
                        _amountInMax, 
                        swapPath, 
                        address(this), 
                        block.timestamp
                    );
                }
            } else if (compareStrings(poolType[i], "DMM")
                || (compareStrings(poolType[i], "BOTH") && compareStrings(poolType[i + 1], "DMM"))) {
                    
                IERC20[] memory dmmSwapPath = new IERC20[](2);
                dmmSwapPath[0] = IERC20(paths[i]);
                dmmSwapPath[1] = IERC20(paths[i + 1]);
                address[] memory _poolAddress = new address[](1);
                _poolAddress[0] = dmmPoolAddresses[dmmPoolIndex++];
                amountIn = IDMMRouter02(dmmRouterAddress).swapTokensForExactTokens(
                    _amountOut, 
                    _amountInMax, 
                    _poolAddress, 
                    dmmSwapPath, 
                    address(this), 
                    block.timestamp
                );
            }
            if (i == 0) {
                amounts[0] = amountIn[0];
            }
            amounts[i + 1] = amountIn[1];

            if (i < paths.length - 2) {
                _amountOut = amountsOut[i + 2];
                _amountInMax = amountIn[1];
            }
        }
        return amounts;
    }
}