# UniswapV2Pair 核心源码深度解析

> 📖 **逐行解读Uniswap V2最核心的合约**
> 
> 理解Pair合约是理解整个V2的关键
> 
> ⏱️ 预计学习时间：4-6小时

---

## 📚 目录

1. [合约概述](#1-合约概述)
2. [继承关系](#2-继承关系)
3. [状态变量详解](#3-状态变量详解)
4. [核心函数：swap](#4-核心函数swap)
5. [核心函数：mint](#5-核心函数mint)
6. [核心函数：burn](#6-核心函数burn)
7. [辅助函数](#7-辅助函数)
8. [安全机制](#8-安全机制)
9. [完整源码注释版](#9-完整源码注释版)

---

## 1. 合约概述

### 1.1 Pair合约的职责

```
UniswapV2Pair是V2的核心合约：

核心职责：
1. 💰 存储两种代币的储备量
2. 🔄 实现swap交易逻辑
3. ➕ 实现mint添加流动性
4. ➖ 实现burn移除流动性
5. 📊 维护TWAP价格数据
6. ⚡ 支持Flash Swaps
7. 🪙 管理LP代币（继承ERC20）

它是：
- 状态存储者（reserves, prices）
- 逻辑执行者（swap, mint, burn）
- 不变式守护者（x·y≥k）
```

### 1.2 文件结构

```
UniswapV2Pair.sol
├── 继承
│   ├── UniswapV2ERC20 (LP代币功能)
│   └── Math (数学库)
├── 状态变量
│   ├── reserves (储备量)
│   ├── prices (累积价格)
│   └── kLast (协议费计算)
├── 核心函数
│   ├── swap() (交易)
│   ├── mint() (添加流动性)
│   └── burn() (移除流动性)
├── 辅助函数
│   ├── _update() (更新状态)
│   ├── _mintFee() (协议费)
│   ├── sync() (同步)
│   └── skim() (提取)
└── 安全机制
    ├── lock (重入锁)
    └── SafeMath (溢出保护)
```

---

## 2. 继承关系

### 2.1 继承图

```mermaid
graph TD
    IUniswapV2Pair[IUniswapV2Pair<br/>接口定义] -.实现.-> Pair
    UniswapV2ERC20[UniswapV2ERC20<br/>LP代币功能] --> Pair[UniswapV2Pair<br/>核心逻辑]
    Math[Math<br/>数学库] --> Pair
    UQ112x112[UQ112x112<br/>定点数库] --> Pair
    
    IERC20[IERC20<br/>ERC20接口] -.实现.-> UniswapV2ERC20
    
    style Pair fill:#339af0,stroke:#1971c2,stroke-width:3px
    style UniswapV2ERC20 fill:#4dabf7
    style Math fill:#74c0fc
    style UQ112x112 fill:#74c0fc
```

### 2.2 各部分职责

**UniswapV2ERC20：**
```solidity
// LP代币的ERC20功能
- name, symbol, decimals
- totalSupply, balanceOf
- transfer, approve, transferFrom
- permit (EIP-2612签名授权)
```

**Math库：**
```solidity
// 数学工具函数
function min(uint x, uint y) returns (uint z) {
    z = x < y ? x : y;
}

function sqrt(uint y) returns (uint z) {
    // 平方根计算（牛顿法）
}
```

**UQ112x112库：二进制定点数（Binary Fixed Point Number）**

这个库实现了 **`UQ112.112`** 定点数格式，用于TWAP价格累积计算。

**什么是UQ112.112？**

```
Q = Q number format（定点数格式）
U = Unsigned（无符号，只支持正数）
112.112 = 用uint224存储，前112位存整数部分，后112位存小数部分

格式：|← 112 bits 整数 →|← 112 bits 小数 →|
      |__________________|__________________|
                  uint224 (224 bits)
```

**核心常数：Q112**

```solidity
uint224 constant Q112 = 2**112;  // 缩放因子
```

所有数字都会乘以 2^112 来存储：
- **1.0** 存储为：`1 × 2^112`
- **2.0** 存储为：`2 × 2^112`
- **0.5** 存储为：`0.5 × 2^112 = 2^111`
- **5.0** 存储为：`5 × 2^112`

**函数1：encode() - 整数编码为定点数**

```solidity
function encode(uint112 y) internal pure returns (uint224 z) {
    z = uint224(y) * Q112;  // never overflows
}
```

作用：将整数转换为UQ112.112格式

例子：
```
输入：y = 5
计算：z = 5 × 2^112
结果：z 代表定点数 5.0
```

为什么永远不溢出？
```
最大输入：uint112最大值 = 2^112 - 1
最大结果：(2^112 - 1) × 2^112 = 2^224 - 2^112
uint224最大值：2^224 - 1

因为 (2^224 - 2^112) < (2^224 - 1)
所以永远不会溢出 ✅
```

**函数2：uqdiv() - 定点数除法**

```solidity
function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
    z = x / uint224(y);
}
```

作用：用定点数除以整数，结果仍是定点数

例子：
```
计算：10.0 ÷ 4 = ?

输入 x：10.0 在UQ112.112中 = 10 × 2^112
输入 y：4（整数）

计算：z = (10 × 2^112) / 4 = 2.5 × 2^112

结果：z 代表定点数 2.5 ✅
```

**在TWAP中的应用：**

```solidity
// 计算价格（reserve1 / reserve0）并编码
price0Cumulative += UQ112x112.encode(reserve1).uqdiv(reserve0) × timeElapsed;

步骤拆解：
1. encode(reserve1)     → reserve1 × 2^112
2. uqdiv(reserve0)      → (reserve1 × 2^112) / reserve0
                        = price × 2^112  (定点数格式的价格)
3. × timeElapsed        → 累积价格增量
```

**为什么使用定点数？**

```
问题：Solidity不支持浮点数
例如：价格 = 2000.5678 USDC/ETH

传统方案A：只存整数 = 2000 ❌ 精度损失
传统方案B：乘以10^18 ✅ 但是会溢出

UQ112.112方案：
✅ 高精度：112位小数 ≈ 77位十进制小数
✅ 足够大：112位整数可以存任何代币数量
✅ 不溢出：精心设计的位数分配
✅ 高效：只用整数运算，Gas便宜

完美方案！⭐⭐⭐⭐⭐
```

---

## 3. 状态变量详解

### 3.1 完整状态变量列表

```solidity
contract UniswapV2Pair is UniswapV2ERC20 {
    using SafeMath  for uint;
    using UQ112x112 for uint224;

    // ===== 常量 =====
    uint public constant MINIMUM_LIQUIDITY = 10**3;
    
    // ===== 不可变变量 =====
    address public factory;
    address public token0;
    address public token1;
    
    // ===== 储备量（紧凑存储）=====
    uint112 private reserve0;           // 32字节slot的前112位
    uint112 private reserve1;           // 32字节slot的中间112位
    uint32  private blockTimestampLast; // 32字节slot的最后32位
    
    // ===== TWAP价格 =====
    uint public price0CumulativeLast;   // token0的累积价格
    uint public price1CumulativeLast;   // token1的累积价格
    
    // ===== 协议费计算 =====
    uint public kLast;                  // 上次mint/burn时的k值
    
    // ===== 重入锁 =====
    uint private unlocked = 1;
}
```

### 3.2 紧凑存储设计

**为什么这样设计？**

```
传统方式（96字节，3个slot）：
slot 1: uint256 reserve0        (32字节)
slot 2: uint256 reserve1        (32字节)
slot 3: uint256 blockTimestamp  (32字节)

V2方式（32字节，1个slot）：
slot 1: |reserve0 (14字节)|reserve1 (14字节)|timestamp (4字节)|
        |112 bits        |112 bits        |32 bits         |

节省：64字节 = 2个storage slot
Gas节省：约 40,000 Gas！
```

**uint112够用吗？**

```
uint112最大值：
2^112 = 5,192,296,858,534,827,628,530,496,329,220,096
      ≈ 5.19 × 10^33

实际对比：
ETH总量：120,000,000 (1.2 × 10^8)
USDC总量：40,000,000,000 (4 × 10^10)

完全够用！甚至溢出可能性为0
```

**uint32时间戳够用吗？**

```
uint32最大值：2^32 = 4,294,967,296秒
            ≈ 136年

从2020年到2156年
完全够用！

而且使用 block.timestamp % 2^32
循环使用，永远不会溢出
```

### 3.3 MINIMUM_LIQUIDITY的作用

```solidity
uint public constant MINIMUM_LIQUIDITY = 10**3;

// 为什么需要？
问题：如果第一个LP移除所有流动性
会导致：totalSupply = 0
风险：第二个LP添加时除以0

解决方案：
首次mint时：
1. 计算 liquidity = sqrt(amount0 * amount1)
2. 铸造 liquidity - MINIMUM_LIQUIDITY 给LP
3. 永久锁定 MINIMUM_LIQUIDITY 到 address(0)

效果：
✅ totalSupply永远 >= 1000
✅ 避免除以0
✅ 防止价格操纵攻击
```

---

## 4. 核心函数：swap

### 4.1 函数签名

```solidity
function swap(
    uint amount0Out,        // 输出token0的数量
    uint amount1Out,        // 输出token1的数量
    address to,             // 接收地址
    bytes calldata data     // 回调数据（Flash Swap）
) external lock;
```

### 4.2 完整实现（带详细注释）

```solidity
function swap(
    uint amount0Out, 
    uint amount1Out, 
    address to, 
    bytes calldata data
) external lock {
    // ===== 步骤1：输入验证 =====
    require(
        amount0Out > 0 || amount1Out > 0, 
        'UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT'
    );
    
    // 获取当前储备量（从storage读取）
    (uint112 _reserve0, uint112 _reserve1,) = getReserves();
    
    // 验证输出量不超过储备量
    require(
        amount0Out < _reserve0 && amount1Out < _reserve1, 
        'UniswapV2: INSUFFICIENT_LIQUIDITY'
    );

    // ===== 步骤2：防止价格操纵 =====
    uint balance0;
    uint balance1;
    {
        // 使用作用域避免stack too deep错误
        address _token0 = token0;
        address _token1 = token1;
        
        // 防止将代币转给代币合约自己（会导致锁死）
        require(to != _token0 && to != _token1, 'UniswapV2: INVALID_TO');
        
        // ===== 步骤3：乐观转账（Flash Swap关键！）=====
        if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
        if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);
        
        // ===== 步骤4：回调（如果有data）=====
        if (data.length > 0) {
            IUniswapV2Callee(to).uniswapV2Call(
                msg.sender, 
                amount0Out, 
                amount1Out, 
                data
            );
        }
        
        // ===== 步骤5：读取当前余额 =====
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
    }
    
    // ===== 步骤6：计算实际输入量 =====
    uint amount0In = balance0 > _reserve0 - amount0Out 
        ? balance0 - (_reserve0 - amount0Out) 
        : 0;
    uint amount1In = balance1 > _reserve1 - amount1Out 
        ? balance1 - (_reserve1 - amount1Out) 
        : 0;
    
    // 必须有输入（要么是普通swap，要么是flash swap还款）
    require(
        amount0In > 0 || amount1In > 0, 
        'UniswapV2: INSUFFICIENT_INPUT_AMOUNT'
    );
    
    // ===== 步骤7：验证k值（含手续费）=====
    {
        // 计算扣除手续费后的余额
        // 手续费 = 0.3% = 3/1000
        // 所以保留 = 1000/1000 - 3/1000 = 997/1000
        uint balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
        uint balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));
        
        // 验证：新的k >= 旧的k
        // balance0Adjusted * balance1Adjusted >= reserve0 * reserve1 * 1000^2
        require(
            balance0Adjusted.mul(balance1Adjusted) >= 
            uint(_reserve0).mul(_reserve1).mul(1000**2), 
            'UniswapV2: K'
        );
    }
    
    // ===== 步骤8：更新储备量和TWAP =====
    _update(balance0, balance1, _reserve0, _reserve1);
    
    // ===== 步骤9：触发事件 =====
    emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
}
```

### 4.3 Swap关键设计解析

**设计1：乐观转账（Optimistic Transfer）**

```
传统方式：
1. 用户先转入
2. 合约计算输出
3. 合约转出

V2方式（支持Flash Swap）：
1. 合约先转出 ⚡
2. 回调用户合约
3. 验证余额和k值

优势：
✅ 支持闪电贷
✅ 支持即时套利
✅ 提升资本效率
```

**设计2：k值验证（含手续费）**

```solidity
// 验证公式：
balance0Adjusted * balance1Adjusted >= reserve0 * reserve1 * 1000^2

// 为什么乘1000^2？
因为：
balance0Adjusted = balance0 * 1000 - amount0In * 3
balance1Adjusted = balance1 * 1000 - amount1In * 3

所以右边也要乘1000^2保持平衡

// 为什么是 >=  而不是 == ？
因为：
1. 手续费会让k增长
2. 有人可能直接转入代币（捐赠）
3. 所以k只会增长，不会减少
```

**设计3：作用域限制（避免Stack Too Deep）**

```solidity
{
    address _token0 = token0;
    address _token1 = token1;
    // ... 使用 _token0, _token1
}
// 出了作用域，_token0和_token1被释放

原因：
Solidity有最多16个局部变量的限制
使用{}限制作用域可以复用stack空间
```

---

## 5. 核心函数：mint

### 5.1 函数签名

```solidity
function mint(address to) 
    external 
    lock 
    returns (uint liquidity);
```

### 5.2 完整实现（带详细注释）

```solidity
function mint(address to) external lock returns (uint liquidity) {
    // ===== 步骤1：获取当前状态 =====
    (uint112 _reserve0, uint112 _reserve1,) = getReserves();
    
    // 读取当前余额（用户已经转入代币）
    uint balance0 = IERC20(token0).balanceOf(address(this));
    uint balance1 = IERC20(token1).balanceOf(address(this));
    
    // 计算用户转入的数量
    uint amount0 = balance0.sub(_reserve0);
    uint amount1 = balance1.sub(_reserve1);

    // ===== 步骤2：计算并铸造协议费 =====
    bool feeOn = _mintFee(_reserve0, _reserve1);
    
    // ===== 步骤3：计算LP代币数量 =====
    uint _totalSupply = totalSupply; // 节省gas
    
    if (_totalSupply == 0) {
        // 首次添加流动性
        liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
        
        // 永久锁定最小流动性到地址0
        _mint(address(0), MINIMUM_LIQUIDITY);
        
    } else {
        // 后续添加流动性
        // 按比例计算LP代币
        liquidity = Math.min(
            amount0.mul(_totalSupply) / _reserve0,
            amount1.mul(_totalSupply) / _reserve1
        );
    }
    
    // ===== 步骤4：铸造LP代币 =====
    require(liquidity > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED');
    _mint(to, liquidity);

    // ===== 步骤5：更新储备量 =====
    _update(balance0, balance1, _reserve0, _reserve1);
    
    // ===== 步骤6：更新kLast（如果开启协议费）=====
    if (feeOn) kLast = uint(reserve0).mul(reserve1);
    
    // ===== 步骤7：触发事件 =====
    emit Mint(msg.sender, amount0, amount1);
}
```

### 5.3 Mint关键设计解析

**设计1：首次流动性计算**

```
首次添加流动性：
liquidity = √(amount0 × amount1) - MINIMUM_LIQUIDITY

为什么用几何平均数？
1. 不依赖价格
   - 如果用 amount0 + amount1，价格影响太大
   - √(amount0 × amount1) 对两个代币一视同仁

2. 对称性
   - √(x × y) = √(y × x)
   - 无论哪个是token0都一样

3. 数学性质好
   - 平滑增长
   - 与k值的平方根一致

例子：
添加 100 USDC + 0.05 ETH
liquidity = √(100 × 0.05) = √5 ≈ 2.236 LP代币
```

**设计2：后续流动性计算**

```solidity
liquidity = min(
    amount0 * totalSupply / reserve0,
    amount1 * totalSupply / reserve1
);

为什么用min？
保证不改变池子价格！

例子：
池子：1000 USDC + 0.5 ETH，100 LP代币
价格：1 ETH = 2000 USDC

用户想添加：200 USDC + 0.1 ETH

按USDC计算：200/1000 * 100 = 20 LP
按ETH计算：0.1/0.5 * 100 = 20 LP

✅ 完全匹配！获得20 LP

如果用户添加：200 USDC + 0.05 ETH（比例不对）

按USDC计算：200/1000 * 100 = 20 LP
按ETH计算：0.05/0.5 * 100 = 10 LP

取min = 10 LP ✅

多余的USDC会留在池子
相当于"捐赠"给其他LP
所以要保证比例正确！
```

**设计3：协议费计算**

```solidity
function _mintFee(uint112 _reserve0, uint112 _reserve1) 
    private 
    returns (bool feeOn) 
{
    address feeTo = IUniswapV2Factory(factory).feeTo();
    feeOn = feeTo != address(0);
    
    uint _kLast = kLast;
    if (feeOn) {
        if (_kLast != 0) {
            // 计算k的增长
            uint rootK = Math.sqrt(uint(_reserve0).mul(_reserve1));
            uint rootKLast = Math.sqrt(_kLast);
            
            if (rootK > rootKLast) {
                // k增长了（因为交易手续费）
                uint numerator = totalSupply.mul(rootK.sub(rootKLast));
                uint denominator = rootK.mul(5).add(rootKLast);
                uint liquidity = numerator / denominator;
                
                // 铸造协议费给feeTo
                if (liquidity > 0) _mint(feeTo, liquidity);
            }
        }
    } else if (_kLast != 0) {
        kLast = 0;
    }
}

协议费公式推导：
如果k从k0增长到k1
增长部分的1/6归协议

为什么是1/6？
因为0.3%手续费，协议分1/6 = 0.05%
LP获得5/6 = 0.25%
```

---

## 6. 核心函数：burn

### 6.1 函数签名

```solidity
function burn(address to) 
    external 
    lock 
    returns (uint amount0, uint amount1);
```

### 6.2 完整实现（带详细注释）

```solidity
function burn(address to) 
    external 
    lock 
    returns (uint amount0, uint amount1) 
{
    // ===== 步骤1：获取当前状态 =====
    (uint112 _reserve0, uint112 _reserve1,) = getReserves();
    address _token0 = token0;
    address _token1 = token1;
    
    // 读取当前余额
    uint balance0 = IERC20(_token0).balanceOf(address(this));
    uint balance1 = IERC20(_token1).balanceOf(address(this));
    
    // 读取要燃烧的LP代币数量（Router已转入）
    uint liquidity = balanceOf[address(this)];

    // ===== 步骤2：计算并铸造协议费 =====
    bool feeOn = _mintFee(_reserve0, _reserve1);
    
    // ===== 步骤3：计算返还代币数量 =====
    uint _totalSupply = totalSupply;
    
    // 按比例计算
    amount0 = liquidity.mul(balance0) / _totalSupply;
    amount1 = liquidity.mul(balance1) / _totalSupply;
    
    require(
        amount0 > 0 && amount1 > 0, 
        'UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED'
    );
    
    // ===== 步骤4：燃烧LP代币 =====
    _burn(address(this), liquidity);
    
    // ===== 步骤5：转出代币 =====
    _safeTransfer(_token0, to, amount0);
    _safeTransfer(_token1, to, amount1);
    
    // ===== 步骤6：更新余额 =====
    balance0 = IERC20(_token0).balanceOf(address(this));
    balance1 = IERC20(_token1).balanceOf(address(this));

    // ===== 步骤7：更新储备量 =====
    _update(balance0, balance1, _reserve0, _reserve1);
    
    // ===== 步骤8：更新kLast =====
    if (feeOn) kLast = uint(reserve0).mul(reserve1);
    
    // ===== 步骤9：触发事件 =====
    emit Burn(msg.sender, amount0, amount1, to);
}
```

### 6.3 Burn关键设计解析

**设计1：按比例返还**

```
公式：
amount0 = liquidity × balance0 / totalSupply
amount1 = liquidity × balance1 / totalSupply

例子：
池子：1000 USDC + 0.5 ETH
总LP：100个
用户持有：10个LP（10%）

移除流动性：
amount0 = 10 × 1000 / 100 = 100 USDC
amount1 = 10 × 0.5 / 100 = 0.05 ETH

✅ 获得池子的10%
```

**设计2：为什么读取balance而不是reserve？**

```
因为可能有人直接转入代币（捐赠）

情况1：正常池子
balance = reserve
正常返还

情况2：有捐赠
balance > reserve
LP获得额外收益！

这是一个feature，不是bug
鼓励"捐赠"给LP
```

---

## 7. 辅助函数

### 7.1 _update函数

```solidity
function _update(
    uint balance0, 
    uint balance1, 
    uint112 _reserve0, 
    uint112 _reserve1
) private {
    // ===== 步骤1：防止溢出 =====
    require(
        balance0 <= uint112(-1) && balance1 <= uint112(-1), 
        'UniswapV2: OVERFLOW'
    );
    
    // ===== 步骤2：计算时间差 =====
    uint32 blockTimestamp = uint32(block.timestamp % 2**32);
    uint32 timeElapsed = blockTimestamp - blockTimestampLast;
    
    // ===== 步骤3：更新TWAP（如果时间过了）=====
    if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
        // 使用UQ112x112编码价格
        // price0 = reserve1 / reserve0
        // price1 = reserve0 / reserve1
        price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
        price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
    }
    
    // ===== 步骤4：更新储备量 =====
    reserve0 = uint112(balance0);
    reserve1 = uint112(balance1);
    blockTimestampLast = blockTimestamp;
    
    // ===== 步骤5：触发事件 =====
    emit Sync(reserve0, reserve1);
}
```

**TWAP更新详解：**

```
TWAP公式：
price_cumulative += price × time_elapsed

例子：
时刻t0: price = $2000, cumulative = 1,000,000
等待1小时（3600秒）...
时刻t1: price = $2100, cumulative = ?

更新：
cumulative = 1,000,000 + 2000 × 3600
           = 1,000,000 + 7,200,000
           = 8,200,000

外部协议计算TWAP：
TWAP = (cumulative_t1 - cumulative_t0) / (t1 - t0)
     = (8,200,000 - 1,000,000) / 3600
     = 7,200,000 / 3600
     = 2000

注意：这里简化了，实际要用UQ112x112解码
```

### 7.2 sync和skim函数

```solidity
// 强制储备量与余额同步
function sync() external lock {
    _update(
        IERC20(token0).balanceOf(address(this)),
        IERC20(token1).balanceOf(address(this)),
        reserve0,
        reserve1
    );
}

// 提取多余代币
function skim(address to) external lock {
    address _token0 = token0;
    address _token1 = token1;
    
    _safeTransfer(
        _token0, 
        to, 
        IERC20(_token0).balanceOf(address(this)).sub(reserve0)
    );
    _safeTransfer(
        _token1, 
        to, 
        IERC20(_token1).balanceOf(address(this)).sub(reserve1)
    );
}
```

**使用场景：**

```
sync() - 强制同步：
用于：代币合约有bug，余额异常时
例如：deflationary token (转账扣费)
效果：强制reserve = balance

skim() - 提取多余：
用于：有人不小心转入代币
例如：有人误转了100 USDC
效果：提取 (balance - reserve)，保持reserve不变

这两个函数是"救急"函数
正常情况不需要调用
```

---

## 8. 安全机制

### 8.1 重入锁

```solidity
uint private unlocked = 1;

modifier lock() {
    require(unlocked == 1, 'UniswapV2: LOCKED');
    unlocked = 0;
    _;
    unlocked = 1;
}

// 所有状态改变函数都加lock
function swap(...) external lock { }
function mint(...) external lock { }
function burn(...) external lock { }
```

**为什么需要重入锁？**

```
重入攻击场景：
1. 攻击者调用swap
2. 在uniswapV2Call回调中
3. 再次调用swap
4. 状态混乱，可能盗取资金

重入锁防护：
1. 第一次调用：unlocked = 1 → 0
2. 重入调用：unlocked = 0 → require失败 ❌
3. 函数结束：unlocked = 0 → 1

✅ 彻底阻止重入
```

### 8.2 溢出保护

```solidity
// V2使用Solidity 0.5
// 需要手动使用SafeMath

using SafeMath for uint;

amount.add(value);    // 替代 amount + value
amount.sub(value);    // 替代 amount - value
amount.mul(value);    // 替代 amount * value
amount.div(value);    // 替代 amount / value

// Solidity 0.8+ 自动检查溢出
// V2如果用0.8+可以去掉SafeMath
```

### 8.3 k值验证

```solidity
// 每次swap都验证k值
require(
    balance0Adjusted * balance1Adjusted >= 
    reserve0 * reserve1 * 1000^2, 
    'UniswapV2: K'
);

// 防止：
1. ❌ 用户不付款就取代币
2. ❌ 手续费被绕过
3. ❌ k值被恶意降低

// 保证：
✅ x·y ≥ k 永远成立
✅ 资金数学安全
```

---

## 9. 完整源码注释版

### 9.1 完整Pair合约

```solidity
// SPDX-License-Identifier: MIT
pragma solidity =0.5.16;

import './interfaces/IUniswapV2Pair.sol';
import './UniswapV2ERC20.sol';
import './libraries/Math.sol';
import './libraries/UQ112x112.sol';
import './interfaces/IERC20.sol';
import './interfaces/IUniswapV2Factory.sol';
import './interfaces/IUniswapV2Callee.sol';

/**
 * @title UniswapV2Pair
 * @notice Uniswap V2核心交易对合约
 * @dev 负责：
 *      1. 存储储备量和TWAP数据
 *      2. 实现swap/mint/burn核心逻辑
 *      3. 维护x·y=k不变式
 *      4. 支持Flash Swaps
 */
contract UniswapV2Pair is IUniswapV2Pair, UniswapV2ERC20 {
    using SafeMath  for uint;
    using UQ112x112 for uint224;

    // ==================== 常量 ====================
    
    /// @notice 最小流动性，永久锁定到address(0)
    /// @dev 防止totalSupply为0，避免除以0和价格操纵
    uint public constant MINIMUM_LIQUIDITY = 10**3;
    
    /// @dev transfer函数选择器（用于_safeTransfer）
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    // ==================== 状态变量 ====================
    
    /// @notice Factory合约地址
    address public factory;
    
    /// @notice 代币0地址（地址较小的）
    address public token0;
    
    /// @notice 代币1地址（地址较大的）
    address public token1;

    /// @notice 代币0储备量（紧凑存储）
    uint112 private reserve0;
    
    /// @notice 代币1储备量（紧凑存储）
    uint112 private reserve1;
    
    /// @notice 最后更新时间戳（紧凑存储）
    uint32  private blockTimestampLast;

    /// @notice 代币0累积价格（TWAP用）
    /// @dev price0 = reserve1 / reserve0
    uint public price0CumulativeLast;
    
    /// @notice 代币1累积价格（TWAP用）
    /// @dev price1 = reserve0 / reserve1
    uint public price1CumulativeLast;
    
    /// @notice 上次mint/burn时的k值（协议费计算用）
    uint public kLast;

    /// @dev 重入锁标志
    uint private unlocked = 1;
    
    // ==================== 修饰器 ====================
    
    /// @notice 重入锁
    modifier lock() {
        require(unlocked == 1, 'UniswapV2: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    // ==================== 查询函数 ====================
    
    /// @notice 获取储备量
    /// @return _reserve0 代币0储备量
    /// @return _reserve1 代币1储备量
    /// @return _blockTimestampLast 最后更新时间
    function getReserves() public view returns (
        uint112 _reserve0, 
        uint112 _reserve1, 
        uint32 _blockTimestampLast
    ) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    /// @dev 安全转账（处理非标准ERC20）
    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(SELECTOR, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))), 
            'UniswapV2: TRANSFER_FAILED'
        );
    }

    // ==================== 初始化 ====================
    
    /// @notice 初始化交易对
    /// @dev 只能由Factory调用一次
    constructor() public {
        factory = msg.sender;
    }

    /// @notice 设置代币地址
    /// @dev 只能由Factory在创建时调用
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, 'UniswapV2: FORBIDDEN');
        token0 = _token0;
        token1 = _token1;
    }

    // ==================== 核心函数 ====================

    /// @notice 交换代币
    /// @param amount0Out 输出代币0数量
    /// @param amount1Out 输出代币1数量  
    /// @param to 接收地址
    /// @param data 回调数据（Flash Swap）
    function swap(
        uint amount0Out, 
        uint amount1Out, 
        address to, 
        bytes calldata data
    ) external lock {
        // 1. 验证输出量
        require(
            amount0Out > 0 || amount1Out > 0, 
            'UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT'
        );
        
        // 2. 获取储备量
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        require(
            amount0Out < _reserve0 && amount1Out < _reserve1, 
            'UniswapV2: INSUFFICIENT_LIQUIDITY'
        );

        uint balance0;
        uint balance1;
        {
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, 'UniswapV2: INVALID_TO');
            
            // 3. 乐观转账
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);
            
            // 4. Flash Swap回调
            if (data.length > 0) {
                IUniswapV2Callee(to).uniswapV2Call(
                    msg.sender, 
                    amount0Out, 
                    amount1Out, 
                    data
                );
            }
            
            // 5. 获取余额
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }
        
        // 6. 计算输入量
        uint amount0In = balance0 > _reserve0 - amount0Out 
            ? balance0 - (_reserve0 - amount0Out) 
            : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out 
            ? balance1 - (_reserve1 - amount1Out) 
            : 0;
        require(
            amount0In > 0 || amount1In > 0, 
            'UniswapV2: INSUFFICIENT_INPUT_AMOUNT'
        );
        
        // 7. 验证k值（含手续费）
        {
            uint balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
            uint balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));
            require(
                balance0Adjusted.mul(balance1Adjusted) >= 
                uint(_reserve0).mul(_reserve1).mul(1000**2), 
                'UniswapV2: K'
            );
        }

        // 8. 更新储备和TWAP
        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    /// @notice 添加流动性（铸造LP代币）
    /// @dev 需要先将代币转入合约
    /// @param to LP代币接收地址
    /// @return liquidity 铸造的LP代币数量
    function mint(address to) external lock returns (uint liquidity) {
        // 1. 获取状态
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0.sub(_reserve0);
        uint amount1 = balance1.sub(_reserve1);

        // 2. 协议费
        bool feeOn = _mintFee(_reserve0, _reserve1);
        
        // 3. 计算LP代币
        uint _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            // 首次添加
            liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            // 后续添加
            liquidity = Math.min(
                amount0.mul(_totalSupply) / _reserve0,
                amount1.mul(_totalSupply) / _reserve1
            );
        }
        require(liquidity > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED');
        
        // 4. 铸造LP代币
        _mint(to, liquidity);

        // 5. 更新状态
        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1);
        
        emit Mint(msg.sender, amount0, amount1);
    }

    /// @notice 移除流动性（燃烧LP代币）
    /// @dev 需要先将LP代币转入合约
    /// @param to 代币接收地址
    /// @return amount0 返还代币0数量
    /// @return amount1 返还代币1数量
    function burn(address to) external lock returns (uint amount0, uint amount1) {
        // 1. 获取状态
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        address _token0 = token0;
        address _token1 = token1;
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        uint liquidity = balanceOf[address(this)];

        // 2. 协议费
        bool feeOn = _mintFee(_reserve0, _reserve1);
        
        // 3. 计算返还量
        uint _totalSupply = totalSupply;
        amount0 = liquidity.mul(balance0) / _totalSupply;
        amount1 = liquidity.mul(balance1) / _totalSupply;
        require(
            amount0 > 0 && amount1 > 0, 
            'UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED'
        );
        
        // 4. 燃烧LP代币
        _burn(address(this), liquidity);
        
        // 5. 转出代币
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        
        // 6. 更新状态
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1);
        
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // ==================== 辅助函数 ====================

    /// @dev 更新储备量和TWAP
    function _update(
        uint balance0, 
        uint balance1, 
        uint112 _reserve0, 
        uint112 _reserve1
    ) private {
        require(
            balance0 <= uint112(-1) && balance1 <= uint112(-1), 
            'UniswapV2: OVERFLOW'
        );
        
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;
        
        // 更新TWAP
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            price0CumulativeLast += 
                uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += 
                uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }
        
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    /// @dev 计算并铸造协议费
    function _mintFee(uint112 _reserve0, uint112 _reserve1) 
        private 
        returns (bool feeOn) 
    {
        address feeTo = IUniswapV2Factory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint _kLast = kLast;
        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = Math.sqrt(uint(_reserve0).mul(_reserve1));
                uint rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint numerator = totalSupply.mul(rootK.sub(rootKLast));
                    uint denominator = rootK.mul(5).add(rootKLast);
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    /// @notice 强制储备量与余额同步
    /// @dev 用于处理异常情况（如deflationary token）
    function sync() external lock {
        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this)),
            reserve0,
            reserve1
        );
    }

    /// @notice 提取多余代币
    /// @dev 用于提取误转入的代币
    /// @param to 接收地址
    function skim(address to) external lock {
        address _token0 = token0;
        address _token1 = token1;
        _safeTransfer(
            _token0, 
            to, 
            IERC20(_token0).balanceOf(address(this)).sub(reserve0)
        );
        _safeTransfer(
            _token1, 
            to, 
            IERC20(_token1).balanceOf(address(this)).sub(reserve1)
        );
    }
}
```

---

## ✅ 学习检查清单

### Level 1：基础理解
- [ ] 理解Pair合约的职责
- [ ] 知道继承关系
- [ ] 理解状态变量的作用
- [ ] 知道swap/mint/burn的流程
- [ ] 理解紧凑存储的设计

### Level 2：深入掌握
- [ ] 能解释乐观转账机制
- [ ] 理解k值验证公式
- [ ] 掌握LP代币计算
- [ ] 理解TWAP更新机制
- [ ] 知道协议费如何计算

### Level 3：融会贯通
- [ ] 能独立实现简化版Pair
- [ ] 能发现潜在的安全问题
- [ ] 理解每个设计决策的原因
- [ ] 能优化Gas消耗
- [ ] 能解释所有边界情况

---

## 🎓 总结

UniswapV2Pair是V2的核心：

```
核心特性：
✅ 极简设计（<500行代码）
✅ 极致优化（紧凑存储节省40K gas）
✅ 功能强大（swap/mint/burn/TWAP/Flash）
✅ 安全可靠（重入锁/k值验证/溢出检查）

设计亮点：
✅ 乐观转账（支持Flash Swaps）
✅ 紧凑存储（3个变量1个slot）
✅ TWAP预言机（防操纵）
✅ 协议费预留（可持续发展）

这是教科书级的智能合约！⭐⭐⭐⭐⭐
```

**下一步** → `02-UniswapV2Factory源码/`

在那里你将学习Factory如何创建和管理所有Pair！💪🚀

---

## 📚 扩展阅读

- [Uniswap V2 Whitepaper](https://uniswap.org/whitepaper.pdf)
- [Uniswap V2 Core Source Code](https://github.com/Uniswap/v2-core)
- [Smart Contract Programmer - Uniswap V2](https://www.youtube.com/watch?v=Eh3faq2OcoI)
