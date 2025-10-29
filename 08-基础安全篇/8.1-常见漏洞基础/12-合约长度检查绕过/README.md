# 绕过合约长度检查 (Bypassing Contract Size Check)

> 💡 **核心要点**
> - `extcodesize` 在合约构造期间返回 0
> - 不能仅用代码长度判断 EOA
> - `tx.origin == msg.sender` 破坏可组合性
> - 推荐从应用层解决防机器人问题

---

## 📚 目录

1. [为什么要限制调用者类型](#1-为什么要限制调用者类型)
2. [常用检查方法的漏洞](#2-常用检查方法的漏洞)
3. [漏洞核心：合约的诞生瞬间](#3-漏洞核心合约的诞生瞬间)
4. [攻击方法](#4-攻击方法)
5. [更可靠的检查方法](#5-更可靠的检查方法)
6. [实战演练](#6-实战演练)
7. [最佳实践](#7-最佳实践)

---

## 1. 为什么要限制调用者类型？

### 1.1 常见需求

在深入漏洞之前，我们先要明白开发者为什么会有这种需求：

#### 防止机器人/脚本滥用

在一些公平启动的项目中，如 NFT 铸造 (Mint) 或代币空投，项目方希望限制每个"人"只能参与一次。

通过禁止合约调用，可以在一定程度上增加机器人批量操作的难度。

#### 避免复杂的合约交互

某些协议的设计可能没有考虑到被其他合约以复杂方式（如在一个交易中多次调用、结合闪电贷等）进行交互的情况。

为了避免不可预见的风险，开发者可能会简单地禁止所有来自合约的调用。

#### 确保某些操作的原子性

开发者可能假设调用者是 EOA，从而认为函数调用是原子的，不会有重入等风险（这是一个**危险的假设**）。

---

## 2. 常用检查方法的漏洞

### 2.1 EXTCODESIZE 检查

要判断一个地址是 EOA 还是合约账户，最常用、最直接的方法就是检查该地址上是否存在代码。

以太坊虚拟机（EVM）提供了一个操作码 `EXTCODESIZE` 来获取地址的代码长度。

| 账户类型 | extcodesize | 说明 |
|---------|-------------|------|
| **合约账户** | > 0 | 有合约代码 |
| **EOA 账户** | = 0 | 没有代码 |

### 2.2 看似安全的检查

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Target {
    string public message;
    
    // ❌ 有漏洞的检查修饰符
    modifier onlyEOA() {
        // 使用 assembly 获取调用者的代码长度
        uint32 size;
        address caller = msg.sender;
        assembly {
            size := extcodesize(caller)
        }
        require(size == 0, "Only EOAs can call this function");
        _;
    }
    
    function sensitiveAction() public onlyEOA {
        message = "Action completed by an EOA";
    }
    
    function getMessage() public view returns (string memory) {
        return message;
    }
}
```

这个 `onlyEOA` 修饰符看起来天衣无缝：检查调用者的代码长度，如果为0，就放行。

**那么，漏洞出在哪里呢？**

---

## 3. 漏洞核心：合约的诞生瞬间

### 3.1 关键事实

这个检查的漏洞源于一个关于合约生命周期的关键事实：

**一个智能合约的地址上出现代码，是在它的 `constructor` (构造函数) 执行完毕之后。**

换句话说：
- 当一个合约正在执行其 `constructor` 逻辑时
- 它的 `extcodesize` **仍然是 0**！
- 它就像一个正在"诞生"但还未完全成形的生命
- 在EVM的视角里，它此刻还没有"身体"（代码）

### 3.2 合约部署流程

```
1. 创建合约地址
   ↓
2. 执行 constructor（此时 extcodesize = 0）
   ↓
3. 将 runtime code 存储到地址（此时 extcodesize > 0）
   ↓
4. 部署完成
```

**关键点**：在步骤2，合约地址的 `extcodesize` 仍然是 0！

---

## 4. 攻击方法

### 4.1 攻击合约

攻击者可以利用这一点，编写一个**攻击合约**，将恶意的调用逻辑放在 `constructor` 里面。

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ITarget {
    function sensitiveAction() external;
}

contract Attacker {
    string public result;
    
    // 💣 构造函数：在部署本合约的瞬间被执行
    constructor(address targetAddress) {
        ITarget target = ITarget(targetAddress);
        
        // **关键攻击点**
        // 在 Attacker 合约的构造函数执行期间，
        // Attacker 地址的 extcodesize 仍然是 0。
        // 因此，对 Target.sensitiveAction() 的调用会成功绕过 onlyEOA 检查！
        target.sensitiveAction();
        
        result = "Attack successful!";
    }
}
```

### 4.2 攻击流程

1. `Target` 合约已经部署在链上
2. 攻击者部署 `Attacker` 合约，并将 `Target` 合约的地址作为参数传入 `Attacker` 的构造函数
3. 在部署 `Attacker` 合约的这笔交易中，`Attacker` 的构造函数被执行
4. 构造函数内部调用了 `Target.sensitiveAction()`
5. `Target` 合约的 `onlyEOA` 修饰符开始检查 `msg.sender`（也就是 `Attacker` 合约的地址）的代码长度
6. **由于 `Attacker` 合约还在构造过程中，`extcodesize(address(Attacker))` 返回 `0`！**
7. `require(size == 0)` 的检查通过，`sensitiveAction()` 被一个**合约账户**成功调用
8. 检查被完美绕过！

### 4.3 时序图

```
攻击者部署 Attacker(Target地址)
    ↓
Attacker.constructor 开始执行
    ↓
extcodesize(Attacker) = 0  ← 关键点！
    ↓
调用 Target.sensitiveAction()
    ↓
Target 检查 extcodesize(msg.sender)
    ↓
检查结果：0  ← 绕过成功！
    ↓
sensitiveAction() 执行
    ↓
Attacker.constructor 完成
    ↓
extcodesize(Attacker) > 0（现在才有代码）
```

---

## 5. 更可靠的检查方法

既然 `extcodesize` 不可靠，我们应该怎么办？

### 5.1 方法一：检查 tx.origin (有争议)

一个更严格的检查方式是判断**交易的发起者 (`tx.origin`)** 和 **直接调用者 (`msg.sender`)** 是否为同一个地址。

```solidity
modifier trulyOnlyEOA() {
    // 检查直接调用者和交易发起者是否是同一个地址
    require(msg.sender == tx.origin, "Only EOAs can call this function");
    _;
}
```

#### 原理

- `tx.origin`：永远是发起这笔交易的 EOA 账户
- `msg.sender`：是直接与本合约交互的地址

如果一个合约A调用另一个合约B，那么对于B来说：
- `msg.sender` 是合约A的地址
- `tx.origin` 是最初发起这笔交易的用户钱包地址

#### ✅ 优点

这个检查可以有效地阻止所有来自其他合约的调用（包括在构造函数中的调用）。

#### ❌ 巨大缺点（为什么不推荐）

1. **破坏了合约的可组合性**
   - 智能合约的魅力在于可以像乐高一样互相组合
   - 这个检查会阻止所有合法的合约间调用

2. **与智能合约钱包不兼容**
   - 像 Gnosis Safe, Argent 这样的多签钱包和账户抽象钱包，其本身就是智能合约
   - 使用这个检查，会导致这些高级钱包的用户完全无法与你的协议交互
   - 这在未来的以太坊生态中是**致命的**

### 5.2 方法二：改变设计思路（推荐）

与其试图在技术上区分 EOA 和合约，不如从应用逻辑和经济模型上解决根本问题。

#### 对于防机器人

不要依赖链上检查。采用：
- **白名单 (Whitelist)**
- **验证码 (Captcha)**
- **签名质询**
- 等链下或半链下方案来验证用户身份

或者设计更好的经济模型：
- **荷兰式拍卖**
- 让机器人没有套利空间

#### 对于防复杂交互

不要一刀切地禁止合约。应该假设你的合约一定会被其他合约调用，并为此做好准备：
- 使用**重入锁 (`ReentrancyGuard`)** 来防止重入攻击
- 仔细设计协议的逻辑以抵御闪电贷等

---

## 6. 实战演练

### 6.1 Remix 练习

**步骤 1：部署目标合约**
1. 部署 `Target` 合约
2. 用 EOA 调用 `sensitiveAction()` - 成功 ✅
3. 观察 `message` 被设置

**步骤 2：尝试合约调用（失败）**
1. 创建一个普通合约尝试调用 - 失败 ❌
2. 因为 `extcodesize` > 0

**步骤 3：绕过攻击**
1. 部署 `Attacker` 合约，传入 `Target` 地址
2. 观察 `Attacker` 部署成功
3. 检查 `Target.message` - 已被修改！
4. 攻击成功绕过了 `onlyEOA` 检查

---

## 7. 最佳实践

### 7.1 问题对比表

| 方面 | 描述 |
|------|------|
| **问题** | 如何限制函数只能被 EOA 调用，而不能被合约调用 |
| **有漏洞的检查** | `require(extcodesize(msg.sender) == 0)` |
| **绕过方法** | 攻击者在自己的合约的 `constructor` 中调用目标函数 |
| **有争议的修复** | `require(msg.sender == tx.origin)` - 有效，但破坏可组合性 |
| **推荐的解决方案** | 放弃在链上区分 EOA 和合约，采用应用层设计 |

### 7.2 推荐方案

#### ✅ 白名单 + 签名

```solidity
contract SecureNFTMint {
    mapping(address => bool) public hasMinted;
    address public signer;
    
    function mint(bytes calldata signature) public {
        require(!hasMinted[msg.sender], "Already minted");
        
        // 验证签名（链下签发）
        bytes32 message = keccak256(abi.encodePacked(msg.sender));
        bytes32 ethSignedMessage = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            message
        ));
        
        address recovered = recoverSigner(ethSignedMessage, signature);
        require(recovered == signer, "Invalid signature");
        
        hasMinted[msg.sender] = true;
        // mint NFT
    }
    
    function recoverSigner(bytes32 message, bytes memory sig) 
        internal pure returns (address) 
    {
        // ECDSA recovery logic
    }
}
```

#### ✅ 荷兰式拍卖

```solidity
contract DutchAuctionNFT {
    uint256 public startPrice = 10 ether;
    uint256 public startTime;
    
    function getCurrentPrice() public view returns (uint256) {
        uint256 elapsed = block.timestamp - startTime;
        uint256 discount = elapsed * 0.1 ether;
        
        if (discount >= startPrice) {
            return 0.1 ether;
        }
        
        return startPrice - discount;
    }
    
    function mint() public payable {
        uint256 price = getCurrentPrice();
        require(msg.value >= price, "Insufficient payment");
        
        // 机器人没有套利空间
        // mint NFT
    }
}
```

### 7.3 代码检查清单

- [ ] 不使用 `extcodesize` 检查 EOA
- [ ] 不使用 `tx.origin` 做权限验证
- [ ] 使用白名单 + 签名验证
- [ ] 或使用经济模型（荷兰拍卖等）
- [ ] 假设合约会被其他合约调用
- [ ] 使用 ReentrancyGuard 防重入

---

## 📚 学习资源

### 文章
- [EVM Deep Dives: The Path to Shadowy Super Coder](https://noxx.substack.com/p/evm-deep-dives-the-path-to-shadowy)
- [Contract Size Check Bypass](https://medium.com/coinmonks/ethernaut-lvl-14-gatekeeper-two-walkthrough-how-extcodesize-may-be-manipulated-14f1f1cfb45)

### 真实案例
- [OpenSea Contract Check Issues](https://github.com/ProjectOpenSea/seaport)

---

## ✅ 学习检查清单

完成本章节后，确认你已经：

- [ ] 理解了 `extcodesize` 的局限性
- [ ] 知道合约在构造期间代码长度为 0
- [ ] 在 Remix 中复现了绕过攻击
- [ ] 理解了 `tx.origin` 的缺点
- [ ] 知道推荐的防机器人方案
- [ ] 理解了合约可组合性的重要性

---

## 🎯 下一步

1. ✅ 在 Remix 中实践绕过攻击
2. ✅ 实现白名单 + 签名验证系统
3. ✅ 继续学习高级安全漏洞
4. ✅ 更新你的 `PROGRESS.md`

---

**记住**：
- ❌ **不要用 extcodesize 判断 EOA**
- ❌ **不要用 tx.origin 做权限验证**
- ✅ **从应用层解决防机器人问题**
- 🔗 **保持合约的可组合性**

祝你学习顺利！🚀

