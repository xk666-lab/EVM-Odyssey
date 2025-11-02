// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;


import "./interfaces/IUniswapV2Factory.sol";
import "./UniswapV2Pair.sol";
import "./interfaces/IUniswapV2Pair.sol";
contract UniswapV2Factory is IUniswapV2Factory{
 address public feeTo;
    address public feeToSetter;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }


function createPair(address tokenA,address tokenB)public  returns(address pair) {
  
require(tokenA!=tokenB, "UNISWAPV2 :IDENTICAL_ADDRESS");
//进行排序，保证每次生成的pair是一样的,总是保证大的地址在前
(address token0,address token1)=tokenA<tokenB?(tokenA,tokenB):(tokenB,tokenA);
/// 利用排序和这个设计,现在已经实现了两个地址的非零判断,因为0的长度是最小的，token0得到的地址是最大的,如果token0都为0地址，那么token也为0地址
require(token0!=address(0),"UNISWAPV2 : ZERO_ADDRESS");

require(getPair(token0,token1)==0, "PAIR_EXISTS");

///使用create2去进行创建,获取字节码
bytes memory bytecode=type(UniswapV2Pair).creationCode;
bytes32 salt=keccak256(abi.encodePacked(token0,token1));



// 2. 部署合约 (这就是新方式！)
// 不再需要汇编，不再需要手动处理 bytecode
address pair = address(new UniswapV2Pair{salt: salt}());
IUniswapV2Pair(pair).initialize(token0,token1);

getPair[token0][token1]=pair;
getPair[token1][token0]=pair;

allPairs.push(pair);

emit PairCreated(token0, token1, pair,all);

}
    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

}




