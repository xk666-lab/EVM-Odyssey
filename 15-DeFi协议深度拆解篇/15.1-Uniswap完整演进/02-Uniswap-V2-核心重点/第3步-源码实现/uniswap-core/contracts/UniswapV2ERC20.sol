// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./interfaces/IUniswapV2ERC20.sol";

contract UniswapV2ERC20  is IUniswapV2ERC20 {
    /// 基本的ERC20合约标准

    string public constant _name = "UNISWAP V2";
    string public constant _symbol = "UNI-V2";

    uint8 public constant _decimals = 18;
    uint256 public _totalSupply;

    // 记录账户的余额
    mapping(address => uint256) public _balanceOf;

    /// 授权的额度
    mapping(address => mapping(address => uint256)) public _allowance;

  
    /// EIP-2612状态变量

    /// 分隔符,区分不同的地方，其实也是为了防止重放
    bytes32 _DOMAIN_SEPARATOR;

    /// 方法的哈希
    ///  keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    bytes32 public constant _PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    /// 防止重放
    mapping(address => uint256) public _nonces;

    constructor() {
        uint256 chainId = block.chainid;

        //// 这是一个标准格式，防止重放的标准格式。是基于eip712的一个格式,这里设置了链，版本，以及地址，名字
         _DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(_name)),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
    }

    function approve(address spender, uint value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function _approve(address owner, address spender, uint value) private {
        _allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

function DOMAIN_SEPARATOR() external view returns (bytes32){

    return _DOMAIN_SEPARATOR;
}
    function PERMIT_TYPEHASH() external pure returns (bytes32){

        return _PERMIT_TYPEHASH;
    }
    function nonces(address owner) external view returns (uint){
        return _nonces[owner];
    }


 function name() external pure returns (string memory){
    return _name;
 }
    function symbol() external pure returns (string memory){
        return _symbol;
    }
    function decimals() external pure returns (uint8){
        return _decimals;
    }
    function totalSupply() external view returns (uint){
        return _totalSupply;
    }
    function balanceOf(address owner) external view returns (uint){
        _balanceOf[owner];
    }
    function allowance(address owner, address spender) external view returns (uint){

        return _allowance[owner][spender];
    }

  function transfer(address to, uint value) external returns (bool){
_transfer(to, value);
return true;
  }


    function transferFrom(
        address from,
        address to,
        uint value
    ) external virtual   returns (bool){
        
        _allowance[from][msg.sender]-=value;
       _transfer(to, value);
       return true;
    }
    function _mint(address to, uint value) internal {
        _totalSupply = _totalSupply+(value);
        _balanceOf[to] = _balanceOf[to]+(value);
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint value) internal {
        _balanceOf[from] = _balanceOf[from]+(value);
        _totalSupply = _totalSupply+(value);
        emit Transfer(from, address(0), value);
    }



function _transfer(address to, uint value)internal {
    _balanceOf[msg.sender]-=value;
    _balanceOf[to]+=value;

    emit Transfer(msg.sender,to,value);
}



    function permit(
        address owner,
        address spender,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        /// 标准的满足eip721的一个格式，消息摘要
        bytes32 digset = keccak256(
            abi.encode(
                "x19/x01",
                _DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        _PERMIT_TYPEHASH,
                        owner,
                        spender,
                        value,
                        _nonces[owner]++,
                        deadline
                    )
                )
            )
        );

        address recoveredAddress = ecrecover(digset, v, r, s); // 这里的ecrecover是一个全局函数，

        (
            recoveredAddress != address(0) && recoveredAddress == owner,
            "UniswapV2: INVALID_SIGNATURE"
        );
        _approve(owner, spender, value);
    }
}
