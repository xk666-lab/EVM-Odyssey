// SPDX-License-Identifier: MIT
pragma solidity ^ 0.8.26;


/// @notice uniswapPair接口
interface IUniswapV2Pair{






/// ERC20部分

//// 事件
 event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
/// AMM部分

// 事件

 event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);

 event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    /// 强制同步代币a和代币b在池中的数量
      event Sync(uint112 reserve0, uint112 reserve1);
      
/// @dev 该函数实现了铸造lp代币功能

/// @dev 该函数实现了销毁lp代币的功能









}
