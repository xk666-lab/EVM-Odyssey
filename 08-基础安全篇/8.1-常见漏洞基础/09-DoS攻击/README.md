# DoS 攻击 (Denial of Service)

> 💡 **核心要点**
> - DoS 攻击使合约无法正常提供服务
> - 外部调用失败不应阻塞重要功能
> - 使用 Pull 模式而非 Push 模式分发资金
> - 避免无限循环和不确定的 Gas 消耗

---

## 📚 目录

1. [DoS 攻击概述](#1-dos-攻击概述)
2. [经典案例：Akutar 事件](#2-经典案例akutar-事件)
3. [常见的 DoS 攻击向量](#3-常见的-dos-攻击向量)
4. [漏洞示例](#4-漏洞示例)
5. [预防方法](#5-预防方法)
6. [实战演练](#6-实战演练)
7. [最佳实践](#7-最佳实践)

---

## 1. DoS 攻击概述

### 1.1 什么是 DoS 攻击？

在 Web2 中，拒绝服务攻击（DoS）是指通过向服务器发送大量垃圾信息或干扰信息的方式，导致服务器无法向正常用户提供服务的现象。

而在 Web3 中，**DoS 攻击指的是利用漏洞使得智能合约无法正常提供服务**。

### 1.2 区块链中的 DoS 特点

与传统 DoS 攻击不同，智能合约中的 DoS 攻击通常是通过：
- ❌ 使某个关键函数永远无法执行
- ❌ 让合约进入死锁状态
- ❌ 消耗过多 Gas 导致交易失败
- ❌ 阻止其他用户正常交互

---

## 2. 经典案例：Akutar 事件

### 2.1 事件背景

在 2022 年 4 月，一个很火的 NFT 项目名为 **Akutar**，他们使用荷兰拍卖进行公开发行，筹集了 **11,539.5 ETH**，非常成功。

之前持有他们社区 Pass 的参与者会得到 0.5 ETH 的退款，但是他们处理退款的时候，发现智能合约不能正常运行，**全部资金被永远锁在了合约里**。

### 2.2 事件原因

他们的智能合约有拒绝服务漏洞：
- 合约使用循环批量退款
- 如果任何一个地址拒绝接收 ETH，整个退款流程会失败
- 由于无法跳过失败的地址，所有资金被永久锁定

### 2.3 影响

- 💸 **11,539.5 ETH** 永久锁定
- 💔 用户无法获得退款
- 📉 项目信誉严重受损

---

## 3. 常见的 DoS 攻击向量

### 3.1 外部调用失败导致的 DoS

```solidity
// ❌ 危险：单个失败会阻塞所有操作
function distributeRewards(address[] memory recipients) public {
    for (uint i = 0; i < recipients.length; i++) {
        (bool success, ) = recipients[i].call{value: 1 ether}("");
        require(success, "Transfer failed"); // 任何一个失败，整个函数回滚
    }
}
```

**攻击方法**：
- 攻击者创建一个拒绝接收 ETH 的合约
- 当合约地址在 recipients 列表中时
- 整个分发流程失败，阻塞所有用户

### 3.2 无限循环或不可预测的 Gas 消耗

```solidity
// ❌ 危险：循环次数不可控
contract VulnerableAuction {
    address[] public bidders;
    
    function refundAll() public {
        // 如果 bidders 太多，Gas 会超出区块限制
        for (uint i = 0; i < bidders.length; i++) {
            payable(bidders[i]).transfer(bids[bidders[i]]);
        }
    }
}
```

### 3.3 Owner 缺席导致的 DoS

```solidity
// ❌ 危险：依赖 owner 的操作
function completeAuction() public {
    require(msg.sender == owner, "Only owner");
    // 如果 owner 私钥丢失，拍卖永远无法完成
    // ...
}
```

### 3.4 意外的合约自毁

```solidity
// ❌ 危险：合约可能被自毁
function destroyContract() public {
    require(msg.sender == owner);
    selfdestruct(payable(owner)); // 合约被销毁，所有功能失效
}
```

---

## 4. 漏洞示例

### 4.1 DoSGame 合约

下面是一个简化的合约，模拟 Akutar 的漏洞：

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract DoSGame {
    mapping(address => uint256) public balances;
    address[] public players;
    
    // 存款
    function deposit() public payable {
        require(msg.value > 0, "Must deposit something");
        
        if (balances[msg.sender] == 0) {
            players.push(msg.sender);
        }
        
        balances[msg.sender] += msg.value;
    }
    
    // ❌ 漏洞：批量退款
    function refund() public {
        for (uint i = 0; i < players.length; i++) {
            address player = players[i];
            uint256 amount = balances[player];
            
            if (amount > 0) {
                balances[player] = 0;
                
                // ❌ 如果这个调用失败，整个函数回滚
                (bool success, ) = player.call{value: amount}("");
                require(success, "Refund failed!");
            }
        }
    }
    
    function getPlayerCount() public view returns (uint256) {
        return players.length;
    }
}
```

### 4.2 攻击合约

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IDoSGame {
    function deposit() external payable;
    function refund() external;
}

contract DoSAttacker {
    IDoSGame public game;
    
    constructor(address _gameAddress) {
        game = IDoSGame(_gameAddress);
    }
    
    // 参与游戏
    function attack() public payable {
        game.deposit{value: msg.value}();
    }
    
    // 💣 拒绝接收 ETH
    receive() external payable {
        revert("I refuse to accept ETH!");
    }
}
```

### 4.3 攻击流程

1. 多个正常用户调用 `deposit()` 存款
2. 攻击者部署 `DoSAttacker` 合约
3. 攻击者调用 `attack()` 参与游戏
4. 管理员尝试调用 `refund()` 退款
5. 当循环到攻击者的合约时，`receive()` 函数 revert
6. 整个 `refund()` 函数失败
7. **所有用户的资金被永久锁定！**

---

## 5. 预防方法

很多逻辑错误都可能导致智能合约拒绝服务，所以开发者在写智能合约时要万分谨慎。

### ✅ 5.1 使用 Pull 而非 Push 模式

**错误的 Push 模式**：
```solidity
// ❌ 批量推送资金给用户
function refundAll() public {
    for (uint i = 0; i < users.length; i++) {
        users[i].transfer(amounts[i]); // Push
    }
}
```

**正确的 Pull 模式**：
```solidity
// ✅ 让用户自己提取资金
mapping(address => uint256) public withdrawable;

function markWithdrawable() public {
    for (uint i = 0; i < users.length; i++) {
        withdrawable[users[i]] = amounts[i];
    }
}

function withdraw() public {
    uint256 amount = withdrawable[msg.sender];
    require(amount > 0, "Nothing to withdraw");
    
    withdrawable[msg.sender] = 0;
    
    (bool success, ) = msg.sender.call{value: amount}("");
    require(success, "Withdraw failed");
}
```

### ✅ 5.2 不让外部调用失败阻塞流程

```solidity
// ✅ 即使单个转账失败，也继续执行
function safeRefund() public {
    for (uint i = 0; i < players.length; i++) {
        address player = players[i];
        uint256 amount = balances[player];
        
        if (amount > 0) {
            balances[player] = 0;
            
            // 去掉 require，单个失败不影响整体
            (bool success, ) = player.call{value: amount}("");
            
            if (!success) {
                // 记录失败，或者将金额加回去
                balances[player] = amount;
                emit RefundFailed(player, amount);
            }
        }
    }
}
```

### ✅ 5.3 避免无限循环

```solidity
// ✅ 分批处理，避免 Gas 超限
uint256 public lastProcessedIndex;

function refundBatch(uint256 batchSize) public {
    uint256 endIndex = lastProcessedIndex + batchSize;
    if (endIndex > players.length) {
        endIndex = players.length;
    }
    
    for (uint i = lastProcessedIndex; i < endIndex; i++) {
        // 处理退款
    }
    
    lastProcessedIndex = endIndex;
}
```

### ✅ 5.4 关键功能不依赖特定地址

```solidity
// ✅ 使用多签或时间锁
contract SafeAuction {
    address public owner;
    uint256 public endTime;
    
    // 即使 owner 缺席，拍卖也能在时间到期后自动完成
    function completeAuction() public {
        require(
            msg.sender == owner || block.timestamp > endTime + 7 days,
            "Not authorized or too early"
        );
        // ...
    }
}
```

### ✅ 5.5 其他注意事项

1. **外部调用失败不卡死**：将 `require(success)` 去掉，单个地址失败时仍能继续
2. **防止合约自毁**：谨慎使用 `selfdestruct`，或完全移除
3. **避免无限循环**：确保循环有明确的上限
4. **参数设定正确**：`require` 和 `assert` 的条件要准确
5. **使用 Pull 模式**：让用户主动领取，而非批量发送
6. **回调函数安全**：确保回调不会影响正常合约运行
7. **关键参与者缺席**：即使 `owner` 永远缺席，合约主要业务仍能运行

---

## 6. 实战演练

### 6.1 Remix 练习

**步骤 1：部署漏洞合约**
1. 部署 `DoSGame` 合约
2. 用几个账户调用 `deposit()`，每次发送 1 ETH

**步骤 2：部署攻击合约**
1. 部署 `DoSAttacker`，传入 `DoSGame` 地址
2. 调用 `attack()`，发送 1 ETH

**步骤 3：观察 DoS**
1. 尝试调用 `DoSGame.refund()`
2. 观察交易失败：`Refund failed!`
3. 所有资金被锁定

**步骤 4：修复并测试**
1. 修改 `refund()` 函数，去掉 `require(success)`
2. 重新部署并测试
3. 观察退款成功，攻击者的钱留在合约中

---

## 7. 最佳实践

### 7.1 设计原则

| 原则 | 说明 | 示例 |
|------|------|------|
| **Pull over Push** | 让用户主动提取资金 | 提款函数 vs 批量转账 |
| **失败隔离** | 单个操作失败不影响整体 | 记录失败而非 revert |
| **Gas 限制** | 避免不可预测的 Gas 消耗 | 分批处理 |
| **去中心化** | 不依赖单一地址 | 时间锁 + 多签 |

### 7.2 代码检查清单

- [ ] 外部调用失败时有备选方案
- [ ] 循环有明确的上限或分批处理
- [ ] 关键功能不依赖单一 owner
- [ ] 使用 Pull 模式分发资金
- [ ] 谨慎使用 `selfdestruct`
- [ ] 测试了所有可能的失败场景

### 7.3 OpenZeppelin 工具

```solidity
import "@openzeppelin/contracts/security/PullPayment.sol";

contract SafeContract is PullPayment {
    function distribute(address recipient, uint256 amount) public {
        // 使用 Pull 模式
        _asyncTransfer(recipient, amount);
    }
}
```

---

## 📚 学习资源

### 真实案例
- [Akutar 事件分析](https://www.paradigm.xyz/2022/08/akutar-dos)
- [GovernorBravo DoS](https://blog.openzeppelin.com/compound-alpha-governance-system-audit)

### 工具
- [OpenZeppelin PullPayment](https://docs.openzeppelin.com/contracts/security#payment)
- [Slither DoS 检测](https://github.com/crytic/slither)

---

## ✅ 学习检查清单

完成本章节后，确认你已经：

- [ ] 理解了 DoS 攻击的原理
- [ ] 知道 Akutar 事件的教训
- [ ] 掌握了 Pull vs Push 模式
- [ ] 在 Remix 中复现了 DoS 攻击
- [ ] 知道如何修复 DoS 漏洞
- [ ] 理解了分批处理的重要性

---

## 🎯 下一步

1. ✅ 在 Remix 中实践 DoS 攻击
2. ✅ 使用 Pull 模式重写退款逻辑
3. ✅ 继续学习下一个漏洞：**10-低级调用风险**
4. ✅ 更新你的 `PROGRESS.md`

---

**记住**：
- 🚫 **永远不要让外部调用失败阻塞整个流程**
- 📤 **使用 Pull 模式而非 Push 模式**
- ⛓️ **分批处理大量操作**
- 🔓 **关键功能不依赖单一地址**

祝你学习顺利！🚀

