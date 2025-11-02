// SPDX-License-Identifier: MIT
pragma solidity ^ 0.8.26;

import './interfaces/IUniswapV2ERC20.sol';

contract UniswapV2ERC20 {
    
/// 基本的ERC20合约标准

string public  constant  name="UNISWAP V2";
string public  constant symbo="UNI-V2";

uint256 public  constant decemals=18;
uint256 public  totalSupply;

// 记录账户的余额
mapping (address=>uint256 )public  balanceOf;

/// 授权的额度
mapping (address=>mapping (address=>uint256)) public  allowance;


   event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

/// EIP-2612状态变量

/// 分隔符,区分不同的地方，其实也是为了防止重放
bytes32 DOMAIN_SEPARATOR;

/// 方法的哈希
///  keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

bytes32 public  constant PERMIT_TYPEHASH= 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

/// 防止重放
mapping (address=>uint256) public nonces;


constructor() {
uint256 chainId=block.chainid;

/// 使用汇编语言去获得chainId
   
DOMAIN_SEPARATOR=keccak256(
    abi.encode(
keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
keccak256(bytes(name)),
keccak256(bytes("1")),
chainId,
address(this)
    )
);
}



}