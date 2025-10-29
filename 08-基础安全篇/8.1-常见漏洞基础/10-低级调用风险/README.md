# 低级调用风险 (Unchecked Low-Level Calls)

> 💡 **核心要点**
> - 低级调用失败不会自动 revert
> - 必须检查低级调用的返回值
> - 使用 call() 替代 send() 和 transfer()
> - 遵循 CEI 模式防止重入

---

## 📚 目录

1. [两种调用方式](#1-两种调用方式)
2. [未检查的低级调用](#2-未检查的低级调用)
3. [低级调用函数详解](#3-低级调用函数详解)
4. [攻击场景实例](#4-攻击场景实例)
5. [修复和防范](#5-修复和防范)
6. [实战演练](#6-实战演练)
7. [最佳实践](#7-最佳实践)

---

## 1. 两种调用方式

### 1.1 高级调用 vs. 低级调用

在智能合约中，与另一个合约交互主要有两种方式：

#### ✅ 高级调用 (High-Level Calls)

- 这是我们最常用、最推荐的方式
- 语法：`OtherContract(contractAddress).someFunction(arg1, arg2);`
- **关键特性**：这种调用方式是"全自动"和"安全的"
- 如果 `someFunction` 执行失败并 `revert`，这个 `revert` 会自动**传播 (propagate)** 回来
- 导致你当前函数的执行也立即失败并回滚
- 你不需要手动检查任何东西

#### ⚠️ 低级调用 (Low-Level Calls)

- 这些是更底层的、更接近 EVM 操作码的函数
- 提供了更大的灵活性，但同时也带来了更大的风险
- 主要包括：**`.call()`**, **`.delegatecall()`**, **`.staticcall()`**, 以及现在**不推荐使用**的 **`.send()`** 和 **`.transfer()`**
- **关键特性**：这是漏洞的核心
- 当一个低级调用执行失败时，它**不会自动 `revert`**！
- 相反，它会返回一个布尔值 `success` 来告诉你调用是否成功

### 1.2 核心矛盾

**高级调用失败时会"大声喊叫"（revert），而低级调用失败时只会"小声嘀咕"（返回 `false`）。**

如果你不去主动"听"这个结果，你的合约就会以为一切正常，并继续执行下去。

---

## 2. 未检查的低级调用

### 2.1 漏洞的根源

"未检查的低级调用"漏洞，就是指开发者使用了 `.call()`, `.send()` 等低级函数，但**没有检查它们返回的 `success` 布尔值**。

合约会天真地认为外部调用已经成功，并继续执行后续的逻辑（例如更新状态变量），但这与链上的实际情况完全不符，导致合约状态出现严重的不一致。

---

## 3. 低级调用函数详解

### 3.1 address.call()

```solidity
(bool success, bytes memory data) = address.call(bytes memory data);
```

**功能**：
- 最通用、最强大的低级调用
- 可以用来发送 ETH，也可以调用目标合约的任意函数

**风险**：
- 如果你不检查返回的 `success`，当调用失败时，你的合约会毫不知情地继续执行
- 这是最常见的漏洞来源

### 3.2 address.send() (不推荐)

```solidity
bool success = address.send(uint256 amount);
```

**功能**：
- 一个专门用来发送 ETH 的函数

**风险**：
1. **同样需要检查返回值**：`someAddress.send(1 ether);` 这样写是**极其危险的**
2. **固定 Gas 津贴**：`send` 只提供 2300 Gas 用于执行
3. 如果接收方是一个合约，并且其 `receive()` 或 `fallback()` 函数的逻辑稍微复杂一点（例如，写入一个存储变量），Gas 就会不够用，导致 `send` 失败
4. 这会使你的合约无法与某些合约交互

### 3.3 address.transfer() (不推荐)

```solidity
address.transfer(uint256 amount);
```

**功能**：
- 也是专门用来发送 ETH 的

**与 send 的区别**：
- `.transfer()` 在失败时会自动 `revert`
- 从这个角度看，它比 `send` 安全

**风险**：
- 它和 `send` 一样，也只有 2300 Gas 的津贴
- 同样存在与复杂合约交互失败的问题
- 随着未来 Gas 成本的变化，依赖固定 Gas 的函数都是脆弱的

### 3.4 现代最佳实践

**当需要发送 ETH 时，应该使用 `.call()`**：

```solidity
(bool success, ) = payable(recipientAddress).call{value: amount}("");
require(success, "Failed to send Ether");
```

这种方式会转发所有可用的 Gas，更加健壮和面向未来。

---

## 4. 攻击场景实例

### 4.1 漏洞合约

假设有一个多方参与的众筹合约，项目失败后，用户可以取回自己的投资。

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract UnsafeCrowdfund {
    mapping(address => uint256) public contributions;
    
    function contribute() public payable {
        contributions[msg.sender] += msg.value;
    }
    
    // ❌ 漏洞：未检查 send 的返回值
    function refund() public {
        uint256 amount = contributions[msg.sender];
        require(amount > 0, "No contribution to refund");
        
        // 漏洞点：使用了 .send() 但没有检查其返回值
        payable(msg.sender).send(amount);
        
        // 无论 send 是否成功，代码都会继续执行到这里
        contributions[msg.sender] = 0;
    }
    
    function getContribution(address user) public view returns (uint256) {
        return contributions[user];
    }
}
```

### 4.2 攻击合约

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IUnsafeCrowdfund {
    function contribute() external payable;
    function refund() external;
}

contract Attacker {
    IUnsafeCrowdfund public crowdfund;
    
    constructor(address _crowdfundAddress) {
        crowdfund = IUnsafeCrowdfund(_crowdfundAddress);
    }
    
    // 参与众筹
    function contribute() public payable {
        crowdfund.contribute{value: msg.value}();
    }
    
    // 尝试退款
    function triggerRefund() public {
        crowdfund.refund();
    }
    
    // 💣 拒绝接收 ETH（消耗大量 Gas）
    receive() external payable {
        // 写入存储，消耗超过 2300 Gas
        uint256 temp = 0;
        for (uint i = 0; i < 10; i++) {
            temp += i;
        }
        revert("I refuse to accept ETH!");
    }
}
```

### 4.3 攻击流程

1. 攻击者创建一个**恶意合约 (`Attacker.sol`)**，并确保其 `receive()` 函数会消耗超过 2300 Gas
2. 攻击者使用这个 `Attacker` 合约地址参与了 `UnsafeCrowdfund` 的众筹
3. 众筹失败后，攻击者调用 `refund()` 函数来取回资金
4. `UnsafeCrowdfund` 合约执行 `payable(msg.sender).send(amount);`
5. 由于 `Attacker` 合约的 `receive()` 函数需要大量 Gas，`send` 操作因为 Gas 不足而**失败**，返回 `false`
6. 然而，`UnsafeCrowdfund` 合约**没有检查这个返回值**，它错误地认为退款已经成功
7. 代码继续执行 `contributions[msg.sender] = 0;`
8. **后果**：攻击者的资金**从未被真正退还**，但他在众筹合约中的余额记录已经被清零

这笔钱被永久地锁在了 `UnsafeCrowdfund` 合约中。

---

## 5. 修复和防范

修复方法非常直接，并且是所有智能合约开发者必须遵守的黄金法则。

### ✅ 5.1 永远检查低级调用的返回值

```solidity
// ✅ 正确做法
bool success = payable(msg.sender).send(amount);
require(success, "Failed to send ETH!");
```

### ✅ 5.2 使用 call 来发送 ETH

放弃 `send` 和 `transfer`，拥抱更现代、更健壮的 `call` 方式。

```solidity
// ✅ 推荐：使用 call
(bool success, ) = payable(msg.sender).call{value: amount}("");
require(success, "Failed to send Ether");
```

### ✅ 5.3 遵循 CEI 模式

**Checks-Effects-Interactions（检查-生效-交互）**

这能同时防范此漏洞和重入攻击。先更新状态，再进行外部调用。

```solidity
// ✅ 安全的代码
contract SafeCrowdfund {
    mapping(address => uint256) public contributions;
    
    function refund() public {
        // 1. 检查 (Checks)
        uint256 amount = contributions[msg.sender];
        require(amount > 0, "No contribution to refund");
        
        // 2. 生效 (Effects) - 先更新状态
        contributions[msg.sender] = 0;
        
        // 3. 交互 (Interactions) - 最后进行外部调用，并严格检查返回值
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Failed to send Ether");
    }
}
```

### ✅ 5.4 使用 OpenZeppelin Address 库

```solidity
import "@openzeppelin/contracts/utils/Address.sol";

contract SafeContract {
    using Address for address payable;
    
    function sendETH(address payable recipient, uint256 amount) public {
        // Address 库已经封装了检查逻辑
        recipient.sendValue(amount);
    }
}
```

---

## 6. 实战演练

### 6.1 Remix 练习

**步骤 1：部署漏洞合约**
1. 部署 `UnsafeCrowdfund`
2. 用正常账户调用 `contribute()`，发送 1 ETH

**步骤 2：部署攻击合约**
1. 部署 `Attacker`，传入 `UnsafeCrowdfund` 地址
2. 调用 `Attacker.contribute()`，发送 1 ETH

**步骤 3：观察漏洞**
1. 查看 `Attacker` 的贡献：1 ETH
2. 调用 `Attacker.triggerRefund()`
3. 观察：交易成功，但 ETH 未退还
4. 查看 `Attacker` 的贡献：0 ETH（已清零）
5. ETH 被永久锁定在合约中

**步骤 4：修复并测试**
1. 修改 `refund()` 函数，使用 `call` 并检查返回值
2. 重新部署并测试

---

## 7. 最佳实践

### 7.1 低级调用对比

| 函数 | 推荐度 | 原因 |
|------|--------|------|
| `call()` | ✅ 推荐 | 灵活、Gas充足、需检查返回值 |
| `send()` | ❌ 不推荐 | 2300 Gas限制、需检查返回值 |
| `transfer()` | ❌ 不推荐 | 2300 Gas限制、破坏可组合性 |

### 7.2 代码检查清单

- [ ] 所有低级调用都检查了返回值
- [ ] 使用 `call()` 而非 `send()` 或 `transfer()`
- [ ] 遵循 CEI 模式
- [ ] 使用 OpenZeppelin 的 Address 库
- [ ] 添加了重入保护
- [ ] 测试了调用失败的场景

### 7.3 安全模式

```solidity
// ✅ 完整的安全模式
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract SecureCrowdfund is ReentrancyGuard {
    using Address for address payable;
    
    mapping(address => uint256) public contributions;
    
    function refund() public nonReentrant {
        uint256 amount = contributions[msg.sender];
        require(amount > 0, "No contribution");
        
        // CEI 模式
        contributions[msg.sender] = 0;
        
        // 使用 OpenZeppelin 的安全转账
        payable(msg.sender).sendValue(amount);
    }
}
```

---

## 📚 学习资源

### 官方文档
- [Solidity by Example - Sending Ether](https://solidity-by-example.org/sending-ether/)
- [OpenZeppelin Address Utility](https://docs.openzeppelin.com/contracts/utils#address)

### 工具
- [Slither](https://github.com/crytic/slither) - 检测未检查的低级调用
- [OpenZeppelin Address](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Address.sol)

---

## ✅ 学习检查清单

完成本章节后，确认你已经：

- [ ] 理解了高级调用 vs 低级调用的区别
- [ ] 知道为什么必须检查低级调用的返回值
- [ ] 掌握了 call、send、transfer 的区别
- [ ] 在 Remix 中复现了未检查调用的漏洞
- [ ] 知道如何正确使用 call() 发送 ETH
- [ ] 理解了 CEI 模式的重要性

---

## 🎯 下一步

1. ✅ 在 Remix 中实践低级调用漏洞
2. ✅ 使用 call() 重写所有 ETH 转账逻辑
3. ✅ 继续学习下一个漏洞：**11-貔貅代币**
4. ✅ 更新你的 `PROGRESS.md`

---

**记住**：
- ✅ **永远检查低级调用的返回值**
- 📞 **使用 call() 替代 send() 和 transfer()**
- 🔄 **遵循 CEI 模式**
- 🛡️ **使用 OpenZeppelin 库**

祝你学习顺利！🚀

