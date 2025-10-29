# 整数溢出漏洞 (Integer Overflow/Underflow)

> 💡 **核心要点**
> - 整数溢出是早期智能合约最常见的漏洞之一
> - Solidity 0.8.0 之前需要手动使用 SafeMath
> - Solidity 0.8.0+ 内置了溢出检查
> - 理解 `unchecked` 的使用场景可以优化 Gas

---

## 📚 目录

1. [整数溢出原理](#1-整数溢出原理)
2. [历史上的重大漏洞](#2-历史上的重大漏洞)
3. [SafeMath 的历史作用](#3-safemath-的历史作用)
4. [Solidity 0.8 的内置检查](#4-solidity-08-的内置检查)
5. [unchecked 的使用](#5-unchecked-的使用)
6. [实战演练](#6-实战演练)
7. [最佳实践](#7-最佳实践)
8. [深入思考](#8-深入思考)

---

## 1. 整数溢出原理

### 1.1 什么是整数溢出？

整数在计算机中以固定位数存储，当运算结果超出这个范围时，就会发生溢出（overflow）或下溢（underflow）。

#### 溢出示例

```solidity
// Solidity 0.7.x (无内置检查)
uint8 max = 255;
uint8 overflow = max + 1;  // 结果是 0，而不是 256！
```

**原因**：
- `uint8` 的范围是 0-255（2^8 - 1）
- `255 + 1 = 256` 超出范围
- 256 用二进制表示：`1 0000 0000`（9位）
- `uint8` 只能存储 8 位，最高位被截断
- 结果：`0000 0000` = 0

#### 下溢示例

```solidity
// Solidity 0.7.x (无内置检查)
uint8 min = 0;
uint8 underflow = min - 1;  // 结果是 255，而不是 -1！
```

**原因**：
- `0 - 1` 在无符号整数中会下溢
- 结果回绕到最大值 255

### 1.2 不同类型的范围

| 类型 | 最小值 | 最大值 | 常见用途 |
|------|--------|--------|----------|
| `uint8` | 0 | 255 | 百分比、小数字 |
| `uint16` | 0 | 65,535 | ID、计数器 |
| `uint32` | 0 | 4,294,967,295 | 时间戳、大计数器 |
| `uint64` | 0 | 2^64 - 1 | 非常大的数字 |
| `uint256` | 0 | 2^256 - 1 | 以太坊默认，货币金额 |
| `int256` | -2^255 | 2^255 - 1 | 有符号数 |

### 1.3 危险场景

#### ❌ 场景 1：余额下溢

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.7.6; // 故意使用旧版本演示

contract VulnerableBank {
    mapping(address => uint256) public balances;
    
    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }
    
    // ❌ 漏洞：没有溢出检查
    function withdraw(uint256 amount) public {
        balances[msg.sender] -= amount;  // 可能下溢！
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }
}
```

**攻击方法**：
```solidity
// 攻击者调用
balances[attacker] = 100;
withdraw(101);  // balances[attacker] 下溢变成 2^256 - 1
```

#### ❌ 场景 2：乘法溢出

```solidity
pragma solidity 0.7.6;

contract VulnerableToken {
    mapping(address => uint256) public balances;
    uint256 public price = 1 ether; // 1 token = 1 ETH
    
    // ❌ 漏洞：乘法可能溢出
    function buy(uint256 amount) public payable {
        uint256 cost = amount * price;  // 可能溢出！
        require(msg.value >= cost, "Insufficient payment");
        
        balances[msg.sender] += amount;
    }
}
```

**攻击方法**：
```solidity
// 如果 amount 非常大
uint256 hugeAmount = 2^256 / (1 ether) + 1;
buy(hugeAmount);  // cost 溢出变成很小的数，几乎免费购买！
```

---

## 2. 历史上的重大漏洞

### 2.1 BEC Token 事件（2018年4月）

**背景**：美链（BeautyChain）的 BEC 代币发生整数溢出攻击。

**漏洞代码**：

```solidity
function batchTransfer(address[] _receivers, uint256 _value) public {
    uint256 cnt = _receivers.length;
    
    // ❌ 漏洞：amount 可能溢出
    uint256 amount = uint256(cnt) * _value;
    
    require(cnt > 0 && cnt <= 20);
    require(_value > 0 && balances[msg.sender] >= amount);
    
    balances[msg.sender] = balances[msg.sender].sub(amount);
    for (uint256 i = 0; i < cnt; i++) {
        balances[_receivers[i]] = balances[_receivers[i]].add(_value);
    }
}
```

**攻击过程**：

```javascript
// 攻击参数
_receivers = [address1, address2]  // cnt = 2
_value = 2^255  // 非常大的数

// 计算
amount = 2 * (2^255) = 2^256 = 0  // 溢出！

// 结果
require(balances[msg.sender] >= 0)  // 通过！
// 攻击者从 0 余额中转出了巨额代币
```

**影响**：
- 攻击者凭空创造了天量的 BEC 代币
- BEC 价格暴跌，市值蒸发
- 多家交易所紧急暂停 BEC 交易

### 2.2 SMT Token 事件（2018年4月）

**类似的溢出漏洞**，同样导致代币被大量增发。

**教训**：
- 整数溢出是系统性风险
- 必须使用 SafeMath 或 Solidity 0.8+
- 代码审计至关重要

---

## 3. SafeMath 的历史作用

### 3.1 SafeMath 是什么？

SafeMath 是 OpenZeppelin 提供的库，用于在 Solidity 0.8 之前进行安全的数学运算。

### 3.2 SafeMath 实现原理

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

library SafeMath {
    /**
     * @dev 安全加法
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
    
    /**
     * @dev 安全减法
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction underflow");
        uint256 c = a - b;
        return c;
    }
    
    /**
     * @dev 安全乘法
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
    
    /**
     * @dev 安全除法
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        return c;
    }
}
```

### 3.3 SafeMath 使用示例

```solidity
pragma solidity 0.7.6;

import "./SafeMath.sol";

contract SafeBank {
    using SafeMath for uint256;  // 使用 SafeMath
    
    mapping(address => uint256) public balances;
    
    function deposit() public payable {
        // ✅ 使用 SafeMath 的 add
        balances[msg.sender] = balances[msg.sender].add(msg.value);
    }
    
    function withdraw(uint256 amount) public {
        // ✅ 使用 SafeMath 的 sub（会检查下溢）
        balances[msg.sender] = balances[msg.sender].sub(amount);
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }
}
```

### 3.4 SafeMath 的局限性

**缺点**：
1. **额外的 Gas 消耗**：每次运算都要执行检查逻辑
2. **代码冗长**：需要显式调用 `.add()`、`.sub()` 等
3. **容易遗忘**：开发者可能忘记使用 SafeMath

**例子**：

```solidity
// ❌ 容易混用
balances[msg.sender] = balances[msg.sender].add(100);  // 安全
total = total + 100;  // 不安全！忘记用 SafeMath
```

---

## 4. Solidity 0.8 的内置检查

### 4.1 革命性改进

**Solidity 0.8.0（2020年12月）** 引入了内置的溢出检查，彻底改变了智能合约开发。

### 4.2 自动检查机制

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract ModernBank {
    mapping(address => uint256) public balances;
    
    function deposit() public payable {
        // ✅ 自动检查溢出！
        balances[msg.sender] += msg.value;
    }
    
    function withdraw(uint256 amount) public {
        // ✅ 自动检查下溢！
        balances[msg.sender] -= amount;  // 如果不足，会 revert
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }
}
```

**如果发生溢出**：

```solidity
uint8 x = 255;
x++;  // ❌ Panic(0x11) - 算术溢出错误
```

### 4.3 错误类型

Solidity 0.8+ 抛出 `Panic(uint256)` 错误：

| 错误代码 | 含义 |
|---------|------|
| `Panic(0x01)` | assert 失败 |
| `Panic(0x11)` | 算术溢出或下溢 |
| `Panic(0x12)` | 除以零 |
| `Panic(0x21)` | 枚举转换错误 |
| `Panic(0x31)` | pop 空数组 |
| `Panic(0x32)` | 数组越界 |

### 4.4 对比 SafeMath

| 特性 | SafeMath (0.7) | Solidity 0.8+ |
|------|----------------|--------------|
| **语法** | `a.add(b)` | `a + b` |
| **Gas 消耗** | 较高（外部库调用） | 较低（内联检查） |
| **易用性** | 需要 import 和 using | 自动启用 |
| **安全性** | 依赖开发者记得使用 | 默认安全 |
| **性能** | 每次调用库函数 | 编译器优化 |

**结论**：✅ **强烈推荐使用 Solidity 0.8+**

---

## 5. unchecked 的使用

### 5.1 为什么需要 unchecked？

虽然内置检查很安全，但在某些场景下，我们**确定不会溢出**，可以使用 `unchecked` 来节省 Gas。

### 5.2 unchecked 语法

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract UncheckedExample {
    function safeIncrement(uint256 x) public pure returns (uint256) {
        // ✅ 默认检查溢出
        return x + 1;  // Gas: ~100
    }
    
    function unsafeIncrement(uint256 x) public pure returns (uint256) {
        // ⚠️ 不检查溢出（节省 Gas）
        unchecked {
            return x + 1;  // Gas: ~80
        }
    }
}
```

### 5.3 安全使用场景

#### ✅ 场景 1：循环计数器

```solidity
// ✅ 推荐：for 循环使用 unchecked
function sumArray(uint256[] memory arr) public pure returns (uint256) {
    uint256 total = 0;
    
    // i 不可能溢出（数组长度有限）
    for (uint256 i = 0; i < arr.length; ) {
        total += arr[i];
        
        unchecked {
            ++i;  // 节省 Gas
        }
    }
    
    return total;
}
```

**Gas 对比**：
- 有检查：每次循环 ~50 gas
- 无检查：每次循环 ~30 gas
- **100次循环节省 ~2000 gas**

#### ✅ 场景 2：已知范围的减法

```solidity
function calculateDiscount(uint256 price) public pure returns (uint256) {
    require(price >= 100, "Price too low");
    
    unchecked {
        // 已经确保 price >= 100，不会下溢
        return price - 100;
    }
}
```

#### ✅ 场景 3：递减到 0

```solidity
function countdown(uint256 n) public pure returns (uint256[] memory) {
    uint256[] memory result = new uint256[](n);
    
    for (uint256 i = n; i > 0; ) {
        unchecked {
            --i;  // i 从 n-1 递减到 0，不会下溢
        }
        result[i] = i;
    }
    
    return result;
}
```

### 5.4 危险使用场景

#### ❌ 场景 1：用户输入

```solidity
// ❌ 危险：用户可以输入任意值
function dangerousWithdraw(uint256 amount) public {
    unchecked {
        balances[msg.sender] -= amount;  // 可能下溢！
    }
}
```

#### ❌ 场景 2：外部数据

```solidity
// ❌ 危险：price 来自外部
function dangerousBuy(uint256 amount, uint256 price) public payable {
    unchecked {
        uint256 cost = amount * price;  // 可能溢出！
        require(msg.value >= cost);
    }
}
```

### 5.5 Gas 优化最佳实践

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract GasOptimized {
    uint256[] public items;
    
    // ✅ 优化版本
    function processItems() public {
        uint256 len = items.length;
        
        for (uint256 i = 0; i < len; ) {
            // 业务逻辑（可能溢出，保持检查）
            items[i] = items[i] + 100;
            
            unchecked {
                // 仅循环变量不检查
                ++i;
            }
        }
    }
    
    // ❌ 过度优化（危险）
    function dangerousProcess() public {
        unchecked {
            for (uint256 i = 0; i < items.length; ++i) {
                items[i] = items[i] + 100;  // 如果溢出，不会报错！
            }
        }
    }
}
```

---

## 6. 实战演练

### 6.1 Remix 练习：整数溢出攻击

#### 文件 1: `VulnerableToken.sol`（Solidity 0.7）

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

contract VulnerableToken {
    mapping(address => uint256) public balances;
    
    constructor() {
        balances[msg.sender] = 1000;
    }
    
    // ❌ 漏洞：没有溢出检查
    function transfer(address to, uint256 amount) public {
        balances[msg.sender] -= amount;  // 可能下溢
        balances[to] += amount;
    }
    
    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }
}
```

**攻击步骤**：

1. 部署 `VulnerableToken`
2. 查看余额：`balanceOf(deployer)` → 1000
3. 执行攻击：`transfer(attacker, 1001)`
4. 查看结果：
   - `balanceOf(deployer)` → 2^256 - 1（下溢！）
   - `balanceOf(attacker)` → 1001

#### 文件 2: `SafeToken.sol`（Solidity 0.8）

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract SafeToken {
    mapping(address => uint256) public balances;
    
    constructor() {
        balances[msg.sender] = 1000;
    }
    
    // ✅ 自动检查溢出
    function transfer(address to, uint256 amount) public {
        balances[msg.sender] -= amount;  // 不足会 revert
        balances[to] += amount;
    }
    
    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }
}
```

**尝试攻击**：

1. 部署 `SafeToken`
2. 执行 `transfer(attacker, 1001)`
3. ❌ 交易失败：`Panic(0x11)` - 算术下溢

### 6.2 练习题

#### 练习 1：找出漏洞

```solidity
pragma solidity 0.7.6;

contract Quiz1 {
    uint8 public level = 1;
    
    function increaseLevel(uint8 amount) public {
        level += amount;
    }
}
```

<details>
<summary>💡 点击查看答案</summary>

**漏洞**：`level` 是 `uint8`（0-255），如果 `level = 250` 时调用 `increaseLevel(10)`，会溢出变成 `4`。

**修复**：
```solidity
pragma solidity ^0.8.26;  // 使用 0.8+ 自动检查

contract Quiz1Fixed {
    uint8 public level = 1;
    
    function increaseLevel(uint8 amount) public {
        level += amount;  // 自动检查溢出
    }
}
```
</details>

#### 练习 2：优化 Gas

```solidity
pragma solidity ^0.8.26;

contract Quiz2 {
    uint256[] public data;
    
    function populateData(uint256 count) public {
        for (uint256 i = 0; i < count; i++) {
            data.push(i * 2);
        }
    }
}
```

<details>
<summary>💡 点击查看优化答案</summary>

```solidity
pragma solidity ^0.8.26;

contract Quiz2Optimized {
    uint256[] public data;
    
    function populateData(uint256 count) public {
        for (uint256 i = 0; i < count; ) {
            data.push(i * 2);
            
            unchecked {
                ++i;  // 循环变量不会溢出
            }
        }
    }
}
```

**Gas 节省**：每次循环节省 ~20 gas
</details>

---

## 7. 最佳实践

### 7.1 版本选择

```solidity
// ✅ 推荐：使用最新稳定版
pragma solidity ^0.8.26;

// ❌ 不推荐：旧版本需要 SafeMath
pragma solidity 0.7.6;
```

### 7.2 何时使用 unchecked

| 场景 | 是否使用 unchecked | 理由 |
|------|-------------------|------|
| 循环计数器 (`++i`) | ✅ 推荐 | 不会溢出，节省 Gas |
| 已验证的减法 | ✅ 可以 | 已确保不会下溢 |
| 用户输入的运算 | ❌ 禁止 | 无法保证安全 |
| 余额/金额计算 | ❌ 禁止 | 必须保持检查 |
| 外部数据运算 | ❌ 禁止 | 无法预测范围 |

### 7.3 代码检查清单

- [ ] 使用 Solidity 0.8+ 版本
- [ ] 避免在金额计算中使用 `unchecked`
- [ ] 循环计数器可以使用 `unchecked { ++i; }`
- [ ] 使用 Slither 进行静态分析
- [ ] 编写测试覆盖边界情况（`type(uint256).max`）

### 7.4 测试边界条件

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

contract OverflowTest is Test {
    SafeToken token;
    
    function setUp() public {
        token = new SafeToken();
    }
    
    function testTransferUnderflow() public {
        // 测试下溢保护
        vm.expectRevert();  // 期待 revert
        token.transfer(address(1), 1001);  // 余额只有 1000
    }
    
    function testMaxValue() public {
        // 测试最大值溢出
        token.balances(address(this)) = type(uint256).max;
        
        vm.expectRevert();
        token.transfer(address(1), 1);  // 会溢出
    }
}
```

---

## 8. 深入思考

### 8.1 为什么 Solidity 0.8 这么晚才加入内置检查？

**历史原因**：
1. **向后兼容性**：早期设计优先考虑与 EVM 的底层一致性
2. **Gas 成本**：早期 Gas 价格高，检查增加成本
3. **开发者习惯**：从 C/C++ 迁移来的开发者习惯手动检查
4. **SafeMath 普及**：社区已有成熟的解决方案

**转折点**：BEC、SMT 等重大事故暴露了系统性风险，推动了语言层面的改进。

### 8.2 unchecked 是好是坏？

**好的方面**：
- ✅ 允许有经验的开发者优化 Gas
- ✅ 在确定安全的场景下提高效率
- ✅ 保持了向后兼容（可以模拟 0.7 行为）

**坏的方面**：
- ❌ 可能被滥用，引入漏洞
- ❌ 降低了代码可读性
- ❌ 增加了审计负担

**建议**：
- 🎯 默认依赖自动检查
- 🎯 只在明确安全且有显著 Gas 优化时使用 `unchecked`
- 🎯 添加详细注释说明为什么安全

### 8.3 真实案例分析

**案例：Uniswap V3 的 unchecked 使用**

```solidity
// UniswapV3Pool.sol (简化版)
for (uint256 i = 0; i < data.length; ) {
    // 核心业务逻辑（保持检查）
    positions[i].tokensOwed += computeFees(i);
    
    unchecked {
        // 仅循环变量不检查
        ++i;
    }
}
```

**经验**：
- ✅ 只在循环变量上使用 `unchecked`
- ✅ 核心金融逻辑保持检查
- ✅ 经过充分审计

---

## 📚 学习资源

### 官方文档
- [Solidity 0.8 Release Notes](https://blog.soliditylang.org/2020/12/16/solidity-v0.8.0-release-announcement/)
- [Checked/Unchecked Arithmetic](https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic)

### 工具
- [Slither](https://github.com/crytic/slither) - 检测溢出漏洞
- [Mythril](https://github.com/ConsenSys/mythril) - 符号执行工具

### 真实案例
- [BEC Token 事件分析](https://medium.com/@peckshield/bec-overflow-incident-30bac6f2d3f7)
- [Rekt News - Integer Overflow](https://rekt.news/leaderboard/)

### 在线挑战
- [Ethernaut - Token](https://ethernaut.openzeppelin.com/level/5) - 整数溢出挑战
- [Capture the Ether - Token Sale](https://capturetheether.com/challenges/math/token-sale/)

---

## ✅ 学习检查清单

完成本章节后，确认你已经：

- [ ] 理解了整数溢出和下溢的原理
- [ ] 知道 `uint8` 到 `uint256` 的范围
- [ ] 了解 BEC Token 事件的历史教训
- [ ] 理解 SafeMath 的工作原理（0.7 时代）
- [ ] 掌握 Solidity 0.8 的自动检查机制
- [ ] 知道何时可以安全使用 `unchecked`
- [ ] 在 Remix 中复现了溢出攻击
- [ ] 编写了测试覆盖边界情况
- [ ] （可选）完成了 Ethernaut Token 挑战

---

## 🎯 下一步

1. ✅ 在 Remix 中实践上述示例
2. ✅ 完成 Ethernaut Level 5: Token
3. ✅ 继续学习下一个漏洞：**03-访问控制**
4. ✅ 更新你的 `PROGRESS.md`

---

**记住**：
- 🔐 **始终使用 Solidity 0.8+**
- ⚡ **仅在安全场景下使用 unchecked**
- 🧪 **编写测试覆盖边界值**

祝你学习顺利！🚀
