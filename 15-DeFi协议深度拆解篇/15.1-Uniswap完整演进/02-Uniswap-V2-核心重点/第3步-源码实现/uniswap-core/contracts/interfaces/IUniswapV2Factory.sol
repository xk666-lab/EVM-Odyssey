// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;


/// @title 工厂合约接口
/// @dev 创建这个合约工厂的接口，定义规范
interface  IUniswapV2Factory{
    

/// @dev 创建交易对触发的事件

event  PairCreated(
    address indexed  token1,
    address indexed  token2,
    address indexed pair,
    uint);

/// @dev 该函数返回手续费接收者地址

function feeTo()external view returns (address);


/// @dev  该函数返回手续费设置者地址
function feeToSetter()external view returns (address);

/// @dev 该函数返回tokenA 和tokenB所对应的交易对地址：
function getPair(address tokenA,address tokenB)external view  returns (address pair);

/// @dev 该函数返回 index 所对应的pair地址
function allPair(uint256 )external returns(address pair);

/// @dev 该函数返回 pair对的数量
function pairLength()external  returns (uint256);

/// @notice 创建交易对
function createPair(address tokenA,address tokenB)external ;

/// @dev 该函数设置手续费接收者地址
function setFeeTo(address _feeTo)external;

/// @dev 该函数设置设置手续费设置者地址
function setFeeToSetter(address _feeToSetter)external ;




}
