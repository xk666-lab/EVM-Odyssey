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

//// @dev为了保持后面流动性添加之后又变为0，导致计算有问题而出现的一个函数
function MINIMUM_LIQUIDITY() external pure returns (uint);



 /// @dev 该函数返回 合约工厂的地址

/// @dev 该函数返回token0的地址
/// @dev 该函数返回token1的地址
/// @dev 该函数返回pair池子中的token0和token1的储备，以及当前的时间戳
/// @dev 返回token0价格随时间累计的数值
/// @dev 返回token1价格随时间累计的数值

/// @dev 记录上一次mint或者burn时的k值 是为了给内部计算手续费增长


/// @dev 该函数实现了铸造lp代币功能

/// @dev 该函数实现了销毁lp代币的功能
/// @dev 交换代币

/// 功能： 移出池中“多余”的、未被 $k$ 值跟踪的代币。

/// 功能： 强制将记录的“储备量”与“实际余额”同步。


///  初始化这个 Pair 合约，告诉它应该管理哪两种代币。


}
