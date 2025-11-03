# 其他重要 EIPs 概览

> 📝 待编写

## 学习目标

- 快速了解其他重要的 EIP 标准
- 建立完整的 EIP 知识体系
- 知道在哪些场景使用哪些标准
- 学会持续关注新提案

## 大纲

### 1. NFT 相关

#### 1.1 EIP-721: 非同质化代币（NFT）⭐⭐⭐
```solidity
interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function setApprovalForAll(address operator, bool approved) external;
}
```

**应用**：
- 所有 NFT 项目的基础
- CryptoPunks、BAYC、Azuki 等

#### 1.2 EIP-1155: 多代币标准 ⭐⭐
```solidity
interface IERC1155 {
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function balanceOfBatch(address[] accounts, uint256[] ids) external view returns (uint256[]);
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes data) external;
    function safeBatchTransferFrom(address from, address to, uint256[] ids, uint256[] amounts, bytes data) external;
}
```

**特点**：
- 同时支持同质化和非同质化代币
- 批量操作省 Gas
- 游戏资产的首选

**应用**：
- OpenSea、Enjin
- 游戏道具

#### 1.3 EIP-2981: NFT 版税标准 ⭐⭐
```solidity
interface IERC2981 {
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view returns (address receiver, uint256 royaltyAmount);
}
```

**作用**：
- 标准化 NFT 版税
- 市场自动支付版税

### 2. 代理与升级

#### 2.1 EIP-1967: 代理存储槽 ⭐⭐⭐
```solidity
// 实现合约地址存储槽
bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
// 管理员地址存储槽
bytes32(uint256(keccak256('eip1967.proxy.admin')) - 1)
```

**作用**：
- 标准化代理合约的存储位置
- 避免存储冲突
- OpenZeppelin 代理的基础

#### 2.2 EIP-1822: UUPS（Universal Upgradeable Proxy Standard）⭐⭐
```solidity
contract UUPSProxy {
    function upgradeTo(address newImplementation) external {
        // 升级逻辑在实现合约中
    }
}
```

**特点**：
- 升级逻辑在实现合约
- 比透明代理省 Gas
- 更灵活

### 3. DeFi 相关

#### 3.1 EIP-4626: 代币化金库标准 ⭐⭐⭐
```solidity
interface IERC4626 {
    function asset() external view returns (address);
    function totalAssets() external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function mint(uint256 shares, address receiver) external returns (uint256 assets);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
}
```

**作用**：
- 标准化收益金库
- Yearn、Compound、Aave 等的标准接口
- DeFi 乐高的重要基石

**应用**：
- 收益聚合器
- 借贷协议
- 流动性挖矿

#### 3.2 EIP-3156: Flash Loans 标准 ⭐⭐
```solidity
interface IERC3156FlashLender {
    function maxFlashLoan(address token) external view returns (uint256);
    function flashFee(address token, uint256 amount) external view returns (uint256);
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
}

interface IERC3156FlashBorrower {
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32);
}
```

**应用**：
- Aave Flash Loans
- Uniswap V3 Flash Swaps
- 套利、清算等

### 4. Gas 优化

#### 4.1 EIP-2929: Gas 成本增加 ⭐
- 首次访问账户/存储槽更贵
- 后续访问更便宜
- 影响合约设计

#### 4.2 EIP-2930: 可选访问列表 ⭐
```javascript
{
  type: 1,  // EIP-2930 交易类型
  accessList: [
    {
      address: "0x...",
      storageKeys: ["0x..."]
    }
  ]
}
```

### 5. 核心协议改进

#### 5.1 EIP-1559: Gas 费改革 ⭐⭐⭐
```
Total Fee = Base Fee + Priority Fee
```

**特点**：
- 基础费用销毁
- 可预测的费用
- 2021 年 8 月实施

#### 5.2 EIP-4844: Proto-Danksharding ⭐⭐⭐
**即将到来（2024）**
- Blob 交易
- Layer 2 成本大幅降低
- 以太坊扩容的重要一步

### 6. 安全相关

#### 6.1 EIP-191: 签名数据标准 ⭐⭐
```solidity
0x19 <1 byte version> <version specific data> <data to sign>
```

**版本**：
- `0x00`：数据带验证器
- `0x01`：结构化数据（EIP-712 使用）
- `0x45`：个人签名

#### 6.2 EIP-2612: Permit（已讲）⭐⭐⭐

### 7. 身份与凭证

#### 7.1 EIP-725: 以太坊身份标准 ⭐
- 代理账户
- 数据存储
- 权限管理

#### 7.2 EIP-735: 声明持有者 ⭐
- 链上声明
- 身份验证

### 8. 跨链相关

#### 8.1 EIP-3074: AUTH 和 AUTHCALL 操作码 ⭐⭐
**未来提案**
- 允许 EOA 委托给合约
- 账户抽象的另一种方案

#### 8.2 EIP-5164: 跨链执行 ⭐
- 标准化跨链消息
- Layer 2 互操作性

### 9. 元数据相关

#### 9.1 EIP-1538: 透明合约标准 ⭐
- 函数注册
- 合约透明度

#### 9.2 EIP-1046: tokenURI 互操作性 ⭐
- NFT 元数据标准
- IPFS 集成

### 10. 如何持续关注 EIPs？

#### 10.1 官方渠道
- [EIPs 官网](https://eips.ethereum.org/)
- [EIPs GitHub](https://github.com/ethereum/EIPs)
- [Ethereum Magicians 论坛](https://ethereum-magicians.org/)

#### 10.2 社区资源
- [Week in Ethereum News](https://weekinethereumnews.com/)
- [EIP.fun](https://eip.fun/)
- Twitter 关注核心开发者

#### 10.3 分类查看
```
EIPs 首页 → 按状态筛选
- Final: 已定稿
- Last Call: 即将定稿
- Review: 审查中
- Draft: 草案
```

#### 10.4 开发者关注重点
1. **ERC 标准**（应用层）
   - 关注度：⭐⭐⭐
   - 直接影响智能合约开发

2. **Core 提案**（共识层）
   - 关注度：⭐⭐
   - 了解网络升级

3. **Interface 提案**（接口层）
   - 关注度：⭐
   - 影响客户端交互

### 11. EIPs 速查表

#### 11.1 必知标准（⭐⭐⭐）
| EIP | 名称 | 用途 |
|-----|------|------|
| 20 | ERC-20 | 同质化代币 |
| 721 | ERC-721 | NFT |
| 712 | EIP-712 | 结构化签名 |
| 1559 | Gas 费改革 | 交易费用 |
| 2612 | Permit | Gasless approval |
| 4337 | 账户抽象 | 智能账户 |
| 4626 | 代币化金库 | DeFi 标准 |

#### 11.2 重要标准（⭐⭐）
| EIP | 名称 | 用途 |
|-----|------|------|
| 165 | 接口检测 | 合约能力查询 |
| 1155 | 多代币标准 | 游戏资产 |
| 1967 | 代理存储槽 | 可升级合约 |
| 2981 | NFT 版税 | 版税标准 |
| 3009 | 转账授权 | USDC 授权 |

#### 11.3 了解即可（⭐）
| EIP | 名称 | 用途 |
|-----|------|------|
| 1271 | 合约签名 | 智能钱包签名 |
| 2535 | 钻石标准 | 模块化合约 |
| 3156 | Flash Loans | 闪电贷标准 |

### 12. 实战练习

#### 练习 1：EIP 查找与阅读
1. 访问 https://eips.ethereum.org/
2. 找到 EIP-4626
3. 阅读并总结其核心接口
4. 找一个实际实现（如 Yearn）

#### 练习 2：标准对比
1. 对比 EIP-2612 和 EIP-3009
2. 列出相同点和不同点
3. 分析各自适用场景

#### 练习 3：追踪新提案
1. 在 GitHub 关注 EIPs 仓库
2. 找到 3 个 Draft 状态的提案
3. 阅读其 Abstract
4. 思考是否有实际应用价值

---

## ✅ 检查清单

### 标准认知
- [ ] 了解 NFT 相关标准（721、1155、2981）
- [ ] 了解 DeFi 相关标准（4626、3156）
- [ ] 了解代理标准（1967、1822）
- [ ] 了解核心改进（1559、4844）

### 应用能力
- [ ] 会查找相关标准
- [ ] 能读懂标准文档
- [ ] 知道何时使用何种标准
- [ ] 能持续关注新提案

---

## 📚 参考资料

### 官方资源
- [EIPs 官网](https://eips.ethereum.org/)
- [EIPs GitHub](https://github.com/ethereum/EIPs)
- [以太坊改进提案指南](https://eips.ethereum.org/EIPS/eip-1)

### 社区资源
- [Ethereum Magicians](https://ethereum-magicians.org/)
- [EIP.fun](https://eip.fun/)
- [Week in Ethereum News](https://weekinethereumnews.com/)

### 标准实现
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts)
- [Solmate](https://github.com/transmissions11/solmate)

---

**保持学习，持续关注以太坊生态的发展！🚀**

