# 貔貅代币 (Honeypot Token / Rug Pull)

> 💡 **核心要点**
> - 貔貅代币：只能买不能卖，仅项目方能卖出
> - 通过修改转账/授权函数实现恶意锁定
> - 使用工具检测貔貅代币（Token Sniffer、Ave Check）
> - 永远做好研究（DYOR）

---

## 📚 目录

1. [什么是貔貅代币](#1-什么是貔貅代币)
2. [貔貅盘的生命周期](#2-貔貅盘的生命周期)
3. [常见的貔貅手法](#3-常见的貔貅手法)
4. [貔貅代币示例](#4-貔貅代币示例)
5. [预防方法](#5-预防方法)
6. [检测工具](#6-检测工具)
7. [最佳实践](#7-最佳实践)

---

## 1. 什么是貔貅代币？

### 1.1 貔貅的由来

[貔貅](https://en.wikipedia.org/wiki/Pixiu)是中国的一个神兽，因为在天庭犯了戒，被玉帝揍的肛门封闭了，只能吃不能拉，可以帮人们聚财。

但在Web3中，**貔貅变为了不详之兽，韭菜的天敌**。

### 1.2 貔貅盘的特点

**貔貅代币的核心特征**：
- 💸 投资人**只能买不能卖**
- 🔓 **仅有项目方地址**能卖出
- 💔 普通用户的资金被永久锁定

---

## 2. 貔貅盘的生命周期

通常一个貔貅盘有如下的生命周期：

### 阶段 1：部署

1. 恶意项目方部署貔貅代币合约
2. 合约代码中埋入恶意逻辑
3. 通常不开源或使用混淆技术

### 阶段 2：诱骗

1. 大力宣传貔貅代币让散户上车
2. 社交媒体炒作、虚假承诺
3. 由于只能买不能卖，代币价格会一路走高
4. 吸引更多散户FOMO入场

### 阶段 3：收割

1. 项目方 `rug pull` 卷走资金
2. 删除社交媒体账号
3. 散户发现无法卖出
4. 资金归零

---

## 3. 常见的貔貅手法

### 3.1 修改 transfer 函数

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract HoneypotToken {
    mapping(address => uint256) public balances;
    address public owner;
    bool public tradingEnabled = false;
    
    constructor() {
        owner = msg.sender;
        balances[owner] = 1000000 * 10**18;
    }
    
    // ❌ 貔貅手法1：只有 owner 能转账
    function transfer(address to, uint256 amount) public returns (bool) {
        require(msg.sender == owner || tradingEnabled, "Trading not enabled");
        
        balances[msg.sender] -= amount;
        balances[to] += amount;
        
        return true;
    }
    
    // 项目方可以随时关闭交易
    function setTradingEnabled(bool _enabled) public {
        require(msg.sender == owner);
        tradingEnabled = _enabled;
    }
}
```

**特征**：
- `tradingEnabled` 初始为 `false`
- 只有 owner 能设置为 `true`
- 项目方可以随时关闭交易

### 3.2 高额转账税

```solidity
contract HighTaxToken {
    uint256 public sellTax = 99; // 99% 税
    
    function transfer(address to, uint256 amount) public returns (bool) {
        uint256 tax = 0;
        
        // 如果不是 owner 卖出，收取99%的税
        if (msg.sender != owner && to == uniswapPair) {
            tax = amount * sellTax / 100;
        }
        
        uint256 amountAfterTax = amount - tax;
        
        balances[msg.sender] -= amount;
        balances[to] += amountAfterTax;
        balances[owner] += tax; // 税收归项目方
        
        return true;
    }
}
```

### 3.3 黑名单机制

```solidity
contract BlacklistToken {
    mapping(address => bool) public blacklist;
    
    function transfer(address to, uint256 amount) public returns (bool) {
        require(!blacklist[msg.sender], "You are blacklisted");
        require(!blacklist[to], "Recipient is blacklisted");
        
        balances[msg.sender] -= amount;
        balances[to] += amount;
        
        return true;
    }
    
    // 项目方可以随意将用户加入黑名单
    function addToBlacklist(address user) public {
        require(msg.sender == owner);
        blacklist[user] = true;
    }
}
```

### 3.4 隐藏的 approve 限制

```solidity
contract RestrictedApprovalToken {
    mapping(address => mapping(address => uint256)) public allowances;
    
    // ❌ approve 函数只对 owner 有效
    function approve(address spender, uint256 amount) public returns (bool) {
        if (msg.sender == owner) {
            allowances[msg.sender][spender] = amount;
            return true;
        }
        
        // 普通用户的 approve 实际上不生效
        return false;
    }
}
```

### 3.5 修改 balanceOf

```solidity
contract FakeBalanceToken {
    mapping(address => uint256) private _realBalances;
    
    // ❌ 显示假的余额
    function balanceOf(address account) public view returns (uint256) {
        if (account == owner) {
            return _realBalances[account];
        }
        
        // 给普通用户显示假余额
        return _realBalances[account] * 1000; // 显示1000倍
    }
    
    function transfer(address to, uint256 amount) public returns (bool) {
        // 但实际转账用真实余额，会失败
        _realBalances[msg.sender] -= amount;
        _realBalances[to] += amount;
        return true;
    }
}
```

---

## 4. 貔貅代币示例

### 4.1 完整的貔貅代币

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract CompleteHoneypot {
    string public name = "HoneyPot Token";
    string public symbol = "HONEY";
    uint8 public decimals = 18;
    uint256 public totalSupply = 1000000 * 10**18;
    
    address public owner;
    address public uniswapPair;
    
    bool public tradingEnabled = false;
    uint256 public sellTax = 90; // 90% 卖出税
    
    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;
    mapping(address => bool) public whitelist;
    mapping(address => bool) public blacklist;
    
    constructor() {
        owner = msg.sender;
        balances[owner] = totalSupply;
        whitelist[owner] = true;
    }
    
    function setUniswapPair(address _pair) public {
        require(msg.sender == owner);
        uniswapPair = _pair;
    }
    
    function setTradingEnabled(bool _enabled) public {
        require(msg.sender == owner);
        tradingEnabled = _enabled;
    }
    
    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }
    
    // ❌ 综合多种貔貅手法
    function transfer(address to, uint256 amount) public returns (bool) {
        require(!blacklist[msg.sender], "Blacklisted");
        require(tradingEnabled || whitelist[msg.sender], "Trading not enabled");
        
        uint256 tax = 0;
        
        // 卖出时收取高额税费
        if (!whitelist[msg.sender] && to == uniswapPair) {
            tax = amount * sellTax / 100;
        }
        
        uint256 amountAfterTax = amount - tax;
        
        balances[msg.sender] -= amount;
        balances[to] += amountAfterTax;
        if (tax > 0) {
            balances[owner] += tax;
        }
        
        return true;
    }
    
    function approve(address spender, uint256 amount) public returns (bool) {
        allowances[msg.sender][spender] = amount;
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(!blacklist[from], "Blacklisted");
        require(tradingEnabled || whitelist[from], "Trading not enabled");
        require(allowances[from][msg.sender] >= amount, "Insufficient allowance");
        
        allowances[from][msg.sender] -= amount;
        
        uint256 tax = 0;
        if (!whitelist[from] && to == uniswapPair) {
            tax = amount * sellTax / 100;
        }
        
        uint256 amountAfterTax = amount - tax;
        
        balances[from] -= amount;
        balances[to] += amountAfterTax;
        if (tax > 0) {
            balances[owner] += tax;
        }
        
        return true;
    }
    
    // 项目方的后门
    function addToBlacklist(address user) public {
        require(msg.sender == owner);
        blacklist[user] = true;
    }
    
    function addToWhitelist(address user) public {
        require(msg.sender == owner);
        whitelist[user] = true;
    }
    
    function setSellTax(uint256 _tax) public {
        require(msg.sender == owner);
        sellTax = _tax;
    }
}
```

---

## 5. 预防方法

貔貅币是韭菜在链上梭哈最容易遇到的骗局，并且形式多变，预防非常有难度。我们有以下几点建议，可以降低被貔貅盘割韭菜的风险：

### ✅ 5.1 查看合约代码

1. 在区块链浏览器上（比如 [Etherscan](https://etherscan.io/)）查看合约是否**开源**
2. 如果开源，则分析它的代码，看是否有貔貅漏洞
3. 检查是否有以下可疑特征：
   - `tradingEnabled` 之类的开关
   - 高额的转账税（>5%）
   - 黑名单/白名单机制
   - Owner 权限过大
   - 隐藏的限制条件

### ✅ 5.2 使用检测工具

如果没有编程能力，可以使用貔貅识别工具：

1. **[Token Sniffer](https://tokensniffer.com/)**
   - 自动分析代币合约
   - 给出安全评分
   - 分数低的大概率是貔貅

2. **[Ave Check](https://ave.ai/check)**
   - AI 驱动的合约分析
   - 检测常见貔貅模式

3. **[Honeypot.is](https://honeypot.is/)**
   - 专门的貔貅检测工具
   - 模拟买卖测试

### ✅ 5.3 查看审计报告

1. 看项目是否有**知名机构**的审计报告
2. 审计机构：
   - CertiK
   - PeckShield
   - SlowMist
   - OpenZeppelin

### ✅ 5.4 检查项目背景

1. 仔细检查项目的官网和社交媒体
2. 查看团队是否公开
3. 检查项目的 GitHub 活跃度
4. 查看社区讨论

### ✅ 5.5 DYOR (Do Your Own Research)

1. **只投资你了解的项目**
2. 做好研究，不要FOMO
3. 小额测试，先买再卖
4. 如果不能卖，立即警惕

### ✅ 5.6 使用模拟工具

使用 Tenderly、Phalcon 分叉模拟卖出貔貅：
1. 在测试网模拟买入
2. 尝试模拟卖出
3. 如果失败则确定是貔貅代币

---

## 6. 检测工具

### 6.1 使用 Token Sniffer

```bash
# 访问 https://tokensniffer.com/
# 输入代币合约地址
# 查看安全评分

评分指标：
- 90-100: 相对安全
- 70-89: 中等风险
- 0-69: 高风险，可能是貔貅
```

### 6.2 使用 Tenderly 模拟

```javascript
// 使用 Tenderly Fork 模拟交易
// 1. 创建主网分叉
// 2. 模拟买入代币
// 3. 模拟卖出代币
// 4. 如果卖出失败，则是貔貅
```

### 6.3 手动检测代码

```solidity
// 检查以下可疑模式：

// 1. 是否有交易开关
bool public tradingEnabled;

// 2. 是否有黑名单
mapping(address => bool) public blacklist;

// 3. 是否有高额税
uint256 public sellTax; // 如果 > 10% 要警惕

// 4. 是否限制只有owner能卖
require(msg.sender == owner || tradingEnabled);

// 5. 是否有隐藏的条件
if (block.timestamp < launchTime + 24 hours) {
    // 只能买不能卖
}
```

---

## 7. 最佳实践

### 7.1 投资前检查清单

- [ ] 合约已开源并验证
- [ ] 在 Token Sniffer 评分 > 80
- [ ] 没有 tradingEnabled 开关
- [ ] 转账税 < 5%
- [ ] 没有黑名单机制
- [ ] Owner 权限有限
- [ ] 有审计报告
- [ ] 团队公开透明
- [ ] 社区活跃
- [ ] 已测试过买卖流程

### 7.2 危险信号

🚩 **立即远离的信号**：
- 合约未开源
- Token Sniffer 评分 < 50
- 转账税 > 10%
- 有黑名单功能
- 匿名团队
- 只有 Telegram 群
- 承诺超高回报
- 强制 FOMO（错过就没机会了）

### 7.3 NFT 貔貅

最近也出现貔貅 **NFT**，恶意项目方通过修改 `ERC721` 的转账或授权函数，使得普通投资者不能出售它们。

```solidity
// ❌ NFT 貔貅示例
contract HoneypotNFT is ERC721 {
    function transferFrom(address from, address to, uint256 tokenId) public override {
        require(from == owner, "Only owner can transfer");
        super.transferFrom(from, to, tokenId);
    }
}
```

---

## 📚 学习资源

### 检测工具
- [Token Sniffer](https://tokensniffer.com/)
- [Ave Check](https://ave.ai/check)
- [Honeypot.is](https://honeypot.is/)
- [Tenderly](https://tenderly.co/)

### 真实案例
- [Squid Game Token Rug Pull](https://www.coindesk.com/markets/2021/11/01/squid-game-token-crashes-to-0-after-scammers-make-off-with-33m/)
- [Rekt News - Rug Pulls](https://rekt.news/leaderboard/)

---

## ✅ 学习检查清单

完成本章节后，确认你已经：

- [ ] 理解了貔貅代币的原理
- [ ] 知道常见的貔貅手法
- [ ] 会使用 Token Sniffer 检测工具
- [ ] 知道如何手动识别貔貅代码
- [ ] 理解了 DYOR 的重要性
- [ ] 知道如何使用模拟工具测试

---

## 🎯 下一步

1. ✅ 使用 Token Sniffer 检测几个代币
2. ✅ 学习如何阅读代币合约代码
3. ✅ 继续学习下一个漏洞：**12-合约长度检查绕过**
4. ✅ 更新你的 `PROGRESS.md`

---

**记住**：
- 🔍 **永远 DYOR（做好研究）**
- 🛡️ **使用检测工具验证**
- 📖 **阅读合约代码**
- 🧪 **小额测试买卖**
- ⚠️ **警惕承诺高回报的项目**

**如果看起来好得不像真的，那它很可能就不是真的！**

祝你学习顺利！🚀

