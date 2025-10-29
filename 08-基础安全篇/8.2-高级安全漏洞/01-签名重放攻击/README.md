# 签名重放攻击 (Signature Replay Attack)

> 💡 **核心要点**
> - 链下签名可被重复使用
> - 必须使用 Nonce 防止重放
> - EIP-712 是黄金标准
> - 包含 chainId 和合约地址防止跨链/跨合约重放

---

## 📚 目录

1. [为什么需要链下签名](#1-为什么需要链下签名)
2. [什么是签名重放攻击](#2-什么是签名重放攻击)
3. [防范方法](#3-防范方法)
4. [EIP-712 标准](#4-eip-712-标准)
5. [实战代码](#5-实战代码)

---

## 1. 为什么需要链下签名？

在理解攻击之前，我们先要明白为什么会有这种模式。主要原因是为了提升用户体验和实现特定功能：

### 1.1 应用场景

#### Gasless 交易

新用户钱包里没有 ETH 来支付 Gas 费。通过链下签名，他们可以授权一笔操作，由项目方的中继者 (Relayer) 来支付 Gas 将交易提交上链。

#### 状态通道/Layer 2

在支付通道或某些 L2 解决方案中，大量交易通过链下签名在参与方之间交换，只在最终结算时才上链，以提高效率。

#### 去中心化应用授权

例如，在 OpenSea 等 NFT 市场上架一个 NFT，你只需要签名一条消息授权挂单即可，无需支付 Gas。当有人购买时，市场会将你的授权签名和买家的交易一起打包上链。

### 1.2 工作流程

1. **用户 (Signer)**：在前端使用自己的私钥对一条包含操作意图的消息进行签名
2. **中继者 (Relayer)**：获取这条消息和用户的签名
3. **智能合约 (Contract)**：中继者调用智能合约的某个函数，并将消息和签名作为参数传入。合约内置的逻辑会使用 `ecrecover` 这个密码学函数来验证签名是否确实来自该用户，验证通过后，再执行消息中的操作

---

## 2. 什么是签名重放攻击？

### 2.1 核心概念

签名重放攻击的核心在于：**攻击者截获了一个用户合法、有效的签名消息，并在不同的上下文或时间点，将其"重播"给智能合约，导致合约在用户不知情或非本意的情况下，重复执行了该签名所授权的操作。**

由于签名本身是有效的（确实是该用户签的），如果合约的验证逻辑不够严谨，它就会把这次重播的攻击当作一次新的、合法的请求来处理。

### 2.2 攻击实例

假设有一个去中心化的交易所（DEX），它允许用户通过签名来授权"从我的账户中转出100个USDC给Bob"。

1. **正常交易**：Alice 想要给 Bob 转 100 USDC。她签署了一条消息 `{from: Alice, to: Bob, amount: 100}`，得到一个签名 `sig_A`。中继者将这条消息和签名提交给DEX合约，合约验证通过，成功将 100 USDC 从 Alice 转给 Bob
2. **攻击发生**：一个恶意的观察者 Eve 看到了这笔链上交易，她复制了消息 `{from: Alice, to: Bob, amount: 100}` 和签名 `sig_A`
3. **重放**：Eve 再次调用 DEX 合约的同一个函数，并传入**一模一样**的消息和签名
4. **合约漏洞**：如果 DEX 合约的验证逻辑仅仅是检查"这个签名是否来自 Alice"，那么验证依然会通过！因为 `sig_A` 确实是 Alice 的有效签名
5. **后果**：合约会**第二次**执行转账操作，又从 Alice 的账户里转了 100 USDC 给 Bob。Alice 凭空损失了 100 USDC

---

## 3. 防范方法

防范的核心思想是：**让每一个签名都成为一次性的、且与特定上下文绑定的"唯一凭证"。**

一个签名只能在一个正确的合约、正确的网络上，因为一个正确的理由，被使用一次，且仅能使用一次。

### 3.1 使用 Nonce (Number Used Once)

这是最基础也是最核心的防御手段，用于防止在**同一个合约内**的重放。

#### 原理

- 合约为每一个用户（地址）维护一个计数器，称为 `nonce`
- 这个 `nonce` 从0开始

#### 实现

1. 用户要签名时，必须从合约中读取自己当前的 `nonce` 值，并将其包含在待签名的消息中。例如，消息变成 `{from: Alice, to: Bob, amount: 100, nonce: 0}`
2. 合约在验证签名后，除了检查签名者身份，还必须检查消息中的 `nonce` 是否与合约中记录的该用户 `nonce` 相等
3. 如果 `nonce` 匹配，合约执行操作，并**立即将该用户的 `nonce` 加一** (`nonce++`)

#### 效果

当攻击者 Eve 尝试重放刚才那条包含 `nonce: 0` 的消息时，合约会发现 Alice 当前的 `nonce` 已经是 `1` 了，`nonce` 不匹配，交易失败。这就保证了每个签名只能被成功使用一次。

### 3.2 引入链ID (`chainId`)

这用于防范**跨链重放攻击 (Cross-chain Replay)**。

#### 风险场景

如果一个项目同时部署在以太坊主网 (Chain ID: 1) 和 Polygon (Chain ID: 137) 上，并且合约代码和签名逻辑完全相同。那么，一个在 Polygon 上授权的签名，可能会被攻击者拿到以太坊主网上重放，反之亦然。

#### 实现

- 在待签名的消息中，包含当前区块链的 `chain ID`
- 合约在验证时，会检查消息中的 `chain ID` 是否与当前链的 `chain ID` 相符

#### 效果

Polygon 上的签名在以太坊主网上会因为 `chain ID` 不匹配而失效，从而阻止了跨链重放。

### 3.3 绑定合约地址

这用于防范签名在**不同合约之间**的重放。

#### 风险场景

项目方可能部署了一个测试版合约和一个正式版合约。用户在测试版合约上的一个签名，可能会被攻击者拿到正式版合约上重放，造成实际资产损失。

#### 实现

- 在待签名的消息中，包含当前合约的地址
- 合约验证时，会检查消息中的地址是否等于 `address(this)`

#### 效果

确保签名只能被预期的目标合约所使用。

---

## 4. EIP-712 标准

### 4.1 简介

为了系统性地解决上述所有问题，并提升签名体验的安全性（让用户在钱包里能看懂自己签的是什么），以太坊社区提出了 **EIP-712: Typed structured data hashing and signing**。

EIP-712 是一种标准化的签名方案，它强制将所有防御机制都结构化地包含进来。

### 4.2 数据结构

一个 EIP-712 签名的数据包含两部分：

#### 1. Domain Separator (域分隔符)

这是一个哈希值，用于将签名"锚定"在特定的上下文中。它由以下部分组成：

- `name`: DApp 的名称 (e.g., "Uniswap V2")
- `version`: 应用或签名的版本 (e.g., "1")
- `chainId`: **链ID** (防止跨链重放)
- `verifyingContract`: **合约地址** (防止跨合约重放)
- `salt`: 一个额外的随机值，用于在特殊情况下区分域

#### 2. Message Hash (消息哈希)

这是对具体操作意图（如转账金额、收款人、**Nonce** 等）的哈希。

最终用户签名的内容是 `hash(domainSeparator, messageHash)`。

### 4.3 为什么安全

要操纵 EIP-712 的签名数据，攻击者几乎需要：
- 获得完全相同的域分隔符
- 使用完全相同的消息哈希
- 在正确的链上、正确的合约上执行

这在经济上和技术上都是极其困难的。

---

## 5. 实战代码

### 5.1 OpenZeppelin 实现

OpenZeppelin 在其合约库中提供了 EIP-712 的标准实现。

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// 继承 EIP712，并传入域名和版本
contract SecureMetaTx is EIP712 {
    using ECDSA for bytes32;
    
    // 用户的 nonce 映射
    mapping(address => uint256) public nonces;

    // 构造函数中初始化 EIP-712 的域名和版本
    constructor() EIP712("MyDApp", "1") {}

    struct TransferRequest {
        address from;
        address to;
        uint256 amount;
        uint256 nonce;
    }

    // EIP-712 类型哈希
    bytes32 private constant TRANSFER_TYPEHASH = keccak256(
        "TransferRequest(address from,address to,uint256 amount,uint256 nonce)"
    );

    function executeTransfer(
        address from,
        address to,
        uint256 amount,
        bytes calldata signature
    ) external {
        uint256 nonce = nonces[from];

        // 1. 构建需要验证的消息哈希
        bytes32 structHash = keccak256(abi.encode(
            TRANSFER_TYPEHASH,
            from,
            to,
            amount,
            nonce
        ));
        
        // 2. 使用 EIP712 的 _hashTypedDataV4 生成最终的摘要
        bytes32 digest = _hashTypedDataV4(structHash);

        // 3. 使用 ECDSA 恢复签名者地址
        address signer = digest.recover(signature);

        // 4. 验证签名者身份和 nonce
        require(signer == from, "Invalid signature");
        require(signer != address(0), "Invalid signature");

        // 5. **核心防重放：递增 nonce**
        nonces[from]++;

        // 6. 执行业务逻辑...
        // IERC20(tokenAddress).transferFrom(from, to, amount);
    }
}
```

### 5.2 前端签名示例

```javascript
// 使用 ethers.js 进行 EIP-712 签名
const domain = {
  name: "MyDApp",
  version: "1",
  chainId: 1, // 主网
  verifyingContract: "0x..." // 合约地址
};

const types = {
  TransferRequest: [
    { name: "from", type: "address" },
    { name: "to", type: "address" },
    { name: "amount", type: "uint256" },
    { name: "nonce", type: "uint256" }
  ]
};

const value = {
  from: "0xAlice...",
  to: "0xBob...",
  amount: 100,
  nonce: 0
};

// 用户签名
const signature = await signer._signTypedData(domain, types, value);
```

---

## 📚 学习资源

### 官方文档
- [EIP-712 Standard](https://eips.ethereum.org/EIPS/eip-712)
- [OpenZeppelin EIP712](https://docs.openzeppelin.com/contracts/4.x/api/utils#EIP712)
- [OpenZeppelin ECDSA](https://docs.openzeppelin.com/contracts/4.x/api/utils#ECDSA)

### 工具
- [eth-sig-util](https://github.com/MetaMask/eth-sig-util) - MetaMask 签名工具

---

## ✅ 学习检查清单

完成本章节后，确认你已经：

- [ ] 理解了链下签名的应用场景
- [ ] 知道什么是签名重放攻击
- [ ] 掌握了 Nonce 防重放机制
- [ ] 理解了 chainId 和合约地址的作用
- [ ] 知道 EIP-712 的核心概念
- [ ] 会使用 OpenZeppelin 的 EIP712 合约
- [ ] 能够在前端使用 ethers.js 进行签名

---

## 🎯 下一步

1. ✅ 实现一个完整的 Gasless 交易系统
2. ✅ 学习 **选择器碰撞攻击** → `02-选择器碰撞攻击/`
3. ✅ 更新你的 `PROGRESS.md`

---

**记住**：
- ✅ **永远使用 Nonce 防止重放**
- ✅ **采用 EIP-712 标准**
- ✅ **包含 chainId 和合约地址**
- ✅ **使用 OpenZeppelin 库**

祝你学习顺利！🚀

