// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;


import './interfaces/IUniswapV2Pair.sol';

import './UniswapV2ERC20.sol';
import './libraries/UQ112x112.sol';
// import './interfaces/IERC20.sol';
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import './interfaces/IUniswapV2Factory.sol';
import './interfaces/IUniswapV2Callee.sol';

contract UniswapV2Pair {
    
// 为其使用这个库，使得方便去进行小数位的计算
    using UQ112X112 for uint224;

//为了方便去计算，会默认其中会有一些流动性。
uint256 public constant MINIMUM_LIQUIDITY=10**3;

///
bytes4 private constant SELECTOR=bytes4(keccak256("transfer(address,uint)"));


}