# 实操：在Uniswap上Swap

> 💡 **学习目标**
> - 完成你的第一笔DeFi交易
> - 理解Swap的完整流程
> - 学会设置滑点保护
> - 理解Gas费和交易确认

---

## 📚 目录

1. [准备工作](#1-准备工作)
2. [连接钱包](#2-连接钱包)
3. [执行Swap](#3-执行swap)
4. [理解交易详情](#4-理解交易详情)
5. [常见问题](#5-常见问题)

---

## 1. 准备工作

### 1.1 你需要

- ✅ MetaMask钱包（已安装）
- ✅ 一些ETH（用于gas费）
- ✅ 想要交易的代币
- ✅ 基本的英文阅读能力

### 1.2 测试网 vs 主网

**强烈建议先在测试网练习！**

#### Sepolia测试网

```
1. MetaMask切换到Sepolia测试网
2. 获取测试ETH:
   - https://sepoliafaucet.com/
   - https://www.alchemy.com/faucets/ethereum-sepolia

3. 访问Uniswap:
   - https://app.uniswap.org/
   - 自动检测到测试网
```

---

## 2. 连接钱包

### 2.1 访问Uniswap

1. 打开 https://app.uniswap.org/
2. 点击右上角 **"Connect Wallet"**
3. 选择 **MetaMask**
4. 在MetaMask弹窗中点击 **"Connect"**

### 2.2 检查连接

连接成功后，右上角会显示：
```
[以太坊图标] 0x1234...5678
```

### 2.3 检查网络

确保你在正确的网络：

```
测试网学习 → Sepolia
真实交易 → Ethereum Mainnet
省gas → Arbitrum / Optimism
```

---

## 3. 执行Swap

### 3.1 选择代币对

**步骤1：选择输入代币**

```
[You pay]
ETH ▼              [Select token]
0.1                [Balance: 1.5 ETH]
```

**步骤2：选择输出代币**

```
[You receive]
USDC ▼             [Select token]
~195.50            [Estimated]
```

### 3.2 设置交易参数

#### 输入金额

```
手动输入：0.1 ETH
或
点击"MAX"使用全部余额（注意留gas费！）
```

#### 滑点设置（重要！）

点击右上角设置图标 ⚙️：

```
Slippage Tolerance (滑点容忍度)
○ Auto (0.5%)
○ 0.1%
○ 0.5%  ← 推荐
○ 1.0%
○ Custom: ____%

建议：
- 稳定币swap: 0.1-0.5%
- 主流币swap: 0.5-1%
- 小币种swap: 1-3%
- 波动期: 2-5%
```

### 3.3 查看交易详情

点击展开，查看：

```
Rate (汇率)
1 ETH = 1,955 USDC

Price Impact (价格影响)
< 0.01%               ← 越小越好

Minimum received (最少收到)
194.52 USDC          ← 滑点保护

Liquidity Provider Fee (手续费)
0.3 ETH = $0.59      ← 给LP的费用

Route (路由)
ETH → USDC           ← 直接交易
或
ETH → WETH → USDC    ← 可能的路由
```

### 3.4 确认交易

**步骤1：点击"Swap"**

**步骤2：确认详情**

```
┌──────────────────────────┐
│   Confirm Swap           │
├──────────────────────────┤
│ You pay:                 │
│   0.1 ETH                │
│                          │
│ You receive:             │
│   195.50 USDC            │
│                          │
│ Gas fee: ~$5.23          │
└──────────────────────────┘
    [Confirm Swap]
```

**步骤3：MetaMask确认**

MetaMask会弹窗显示：

```
ESTIMATED GAS FEE
$5.23
Max: $6.50

[ Reject ]  [ Confirm ]
```

点击 **Confirm**！

### 3.5 等待确认

```
[Pending...] ⏳

约15秒-2分钟后：

[Success!] ✅

View on Etherscan →
```

---

## 4. 理解交易详情

### 4.1 在Etherscan查看

点击 "View on Etherscan"，你会看到：

```
Transaction Hash: 0xabc123...
Status: Success ✅
Block: 12345678
From: 0x你的地址
To: Uniswap V2 Router
Value: 0.1 ETH
Transaction Fee: 0.002 ETH ($5.23)
```

### 4.2 Token Transfers

往下滚动到 "Tokens Transferred"：

```
From          To              Value
─────────────────────────────────────
你的地址    → Uniswap Router  0.1 ETH
Uniswap Pool → 你的地址       195.5 USDC
```

### 4.3 理解Gas费

```
Gas费 = Gas Used × Gas Price

例如：
21,000 Gas × 250 Gwei
= 21,000 × 250 × 10^-9 ETH
= 0.00525 ETH
= $10.50 (假设ETH = $2000)

Gas费组成：
- Base Fee: 给网络
- Priority Fee: 给矿工/验证者
```

---

## 5. 常见问题

### ❓ Q1: 为什么实际收到的和显示的不一样？

**A**: 价格在你点击"Swap"和交易确认之间可能变化了。

```
显示: 195.5 USDC
实际: 195.2 USDC

差异在滑点容忍度内 → 交易成功
差异超过滑点 → 交易失败（Reverted）
```

### ❓ Q2: 交易失败了，Gas费还扣吗？

**A**: 是的！即使交易失败，Gas费也会被扣除。

```
原因：
矿工已经处理了你的交易
只是合约执行失败了

如何避免：
- 设置合理的滑点
- Gas费不要设置太低
- 检查代币授权
```

### ❓ Q3: 为什么需要先"Approve"？

**A**: 第一次swap某个代币时，需要授权Uniswap使用你的代币。

```
步骤：
1. 点击Swap
2. MetaMask弹窗: "Approve USDC"
3. 确认授权
4. 等待确认
5. 再次点击Swap
6. 执行真正的交易

第2次swap同一代币：
直接交易，不需要再授权
```

### ❓ Q4: 如何节省Gas费？

```
技巧：
1. 选择Gas费低的时段（周末、凌晨）
2. 使用L2（Arbitrum、Optimism）
3. 批量交易
4. 使用GasTracker查看实时gas价格
```

---

## 🎯 实战任务

### 任务1：测试网Swap

在Sepolia测试网：

1. [ ] 获取测试ETH
2. [ ] 连接MetaMask到Uniswap
3. [ ] Swap 0.01 ETH → USDC
4. [ ] 在Etherscan查看交易
5. [ ] 截图保存

### 任务2：主网小额Swap

在主网（**小额！**）：

1. [ ] 准备$20-50的ETH
2. [ ] Swap一小部分到USDC
3. [ ] 体验真实的Gas费
4. [ ] 记录滑点和价格影响

### 任务3：对比不同设置

尝试不同的滑点设置，观察：
- 0.1% 滑点
- 1% 滑点
- 5% 滑点

哪个会失败？哪个会成功但损失大？

---

## 📚 学习资源

### Uniswap官方
- [Uniswap Interface](https://app.uniswap.org/)
- [Uniswap Docs](https://docs.uniswap.org/)
- [Uniswap Help Center](https://support.uniswap.org/)

### 工具
- [Etherscan](https://etherscan.io/) - 查看交易
- [ETH Gas Station](https://ethgasstation.info/) - 查看gas价格

---

## ✅ 学习检查清单

完成本章后，你应该：

- [ ] 成功在测试网完成swap
- [ ] 理解滑点的作用
- [ ] 知道如何设置gas费
- [ ] 会在Etherscan查看交易
- [ ] 理解代币授权的必要性
- [ ] （可选）在主网完成小额swap

---

## 🎯 下一步

完成第一笔swap后，继续实操：

1. ✅ **提供流动性** → 成为LP赚手续费
2. ✅ **在Aave存款** → 体验借贷
3. ✅ **对比不同DEX** → Uniswap vs SushiSwap vs Curve

---

**恭喜你完成了第一笔DeFi交易！**

你已经迈出了成为DeFi高手的第一步！🎉🚀

**注意安全：**
- 🔐 保护好私钥
- ⚠️ 小额开始
- 📖 理解后再操作
- 🛡️ 警惕钓鱼网站
