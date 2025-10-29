# 📦 代码组织规范

> 如何组织学习过程中的代码？

---

## 🎯 总体原则

### 1. 三类代码，三个目录

```
examples/   - 代码片段和小示例（学习用）
projects/   - 完整的实战项目（作品集）
exercises/  - 练习题答案（自我检验）
```

### 2. 每个代码目录都要有：

```
必备文件：
├─ contracts/           # Solidity合约
├─ test/               # 测试文件
├─ scripts/            # 部署脚本
├─ hardhat.config.js   # 配置文件
├─ package.json        # 依赖管理
├─ .env.example        # 环境变量示例
├─ README.md           # 说明文档 ⭐
└─ .gitignore          # 忽略文件
```

---

## 📁 目录结构详解

### examples/ - 代码示例

**用途**：配合文档的小型代码示例

```bash
examples/
├─ README.md                    # 所有示例的索引
│
├─ 03-solidity-basics/          # 对应章节
│   ├─ 01-hello-world/
│   │   ├─ HelloWorld.sol       # 单个合约文件
│   │   ├─ test.js              # 简单测试
│   │   └─ README.md            # 说明
│   │
│   ├─ 02-types/
│   │   ├─ ValueTypes.sol
│   │   ├─ ReferenceTypes.sol
│   │   └─ README.md
│   │
│   ├─ 03-functions/
│   └─ ...
│
├─ 05-openzeppelin/
│   ├─ 01-erc20-basic/
│   │   ├─ contracts/
│   │   │   └─ MyToken.sol
│   │   ├─ test/
│   │   │   └─ MyToken.test.js
│   │   ├─ hardhat.config.js
│   │   ├─ package.json
│   │   └─ README.md
│   │
│   └─ 02-erc721-basic/
│
├─ 06-token-standards/
│   ├─ erc20-examples/
│   ├─ erc721-examples/
│   └─ erc1155-examples/
│
├─ 15-defi/
│   ├─ uniswap-v2-demo/        # Uniswap V2核心函数演示
│   │   ├─ contracts/
│   │   │   ├─ SimpleSwap.sol  # 简化版swap
│   │   │   └─ SimplePair.sol  # 简化版pair
│   │   ├─ test/
│   │   ├─ hardhat.config.js
│   │   └─ README.md
│   │
│   ├─ aave-flashloan-demo/    # 闪电贷演示
│   ├─ curve-stableswap-math/  # Curve数学演示
│   └─ compound-interest-demo/ # 利率计算演示
│
└─ ...（其他章节）
```

**特点**：
- ✅ 轻量级，快速理解概念
- ✅ 单一职责，每个示例只演示一个概念
- ✅ 配合文档阅读

---

### projects/ - 完整项目

**用途**：作品集级别的完整项目

```bash
projects/
├─ README.md                    # 项目索引和展示 ⭐
│
├─ 01-erc20-token/              # 项目1: ERC20代币
│   ├─ contracts/
│   │   ├─ MyToken.sol
│   │   └─ Faucet.sol
│   ├─ test/
│   │   ├─ MyToken.test.js
│   │   └─ Faucet.test.js
│   ├─ scripts/
│   │   ├─ deploy.js
│   │   └─ verify.js
│   ├─ frontend/                # 可选：前端代码
│   │   ├─ src/
│   │   ├─ public/
│   │   └─ package.json
│   ├─ docs/
│   │   ├─ architecture.md      # 架构设计
│   │   ├─ api.md               # API文档
│   │   └─ deployment.md        # 部署文档
│   ├─ hardhat.config.js
│   ├─ package.json
│   ├─ .env.example
│   ├─ .gitignore
│   └─ README.md                # 项目完整说明
│
├─ 02-nft-collection/           # 项目2: NFT集合
│   ├─ contracts/
│   │   ├─ MyNFT.sol
│   │   ├─ NFTMarketplace.sol
│   │   └─ interfaces/
│   ├─ test/
│   │   ├─ unit/
│   │   ├─ integration/
│   │   └─ fuzzing/
│   ├─ scripts/
│   ├─ frontend/
│   ├─ docs/
│   └─ README.md
│
├─ 03-nft-marketplace/          # 项目3: NFT交易市场
│   ├─ contracts/
│   ├─ test/
│   ├─ frontend/
│   ├─ backend/                 # 后端服务
│   │   ├─ src/
│   │   ├─ package.json
│   │   └─ README.md
│   ├─ docs/
│   └─ README.md
│
├─ 04-uniswap-v2-fork/          # 项目4: Uniswap V2改进版 ⭐
│   ├─ contracts/
│   │   ├─ core/                # 核心合约
│   │   │   ├─ UniswapV2Pair.sol
│   │   │   ├─ UniswapV2Factory.sol
│   │   │   └─ UniswapV2ERC20.sol
│   │   ├─ periphery/           # 外围合约
│   │   │   └─ UniswapV2Router.sol
│   │   └─ improvements/        # 你的改进
│   │       └─ DynamicFeeRouter.sol
│   ├─ test/
│   │   ├─ core/
│   │   ├─ periphery/
│   │   └─ improvements/
│   ├─ scripts/
│   ├─ frontend/
│   ├─ docs/
│   │   ├─ whitepaper.md        # 你的改进白皮书 ⭐
│   │   ├─ architecture.md
│   │   └─ comparison.md        # 与原版对比
│   └─ README.md
│
├─ 05-flashloan-arbitrage/      # 项目5: 闪电贷套利机器人
├─ 06-dao-governance/           # 项目6: DAO治理系统
├─ 07-staking-platform/         # 项目7: 质押挖矿平台
├─ 08-lending-protocol/         # 项目8: 借贷协议
└─ 09-final-project/            # 项目9: 自选大项目
```

**特点**：
- ✅ 生产级代码质量
- ✅ 完整的测试覆盖（>80%）
- ✅ 完整的文档
- ✅ 已部署到测试网/主网
- ✅ 可以作为作品集展示

---

### exercises/ - 练习题

**用途**：每周练习题的答案

```bash
exercises/
├─ README.md
│
├─ week-01/
│   ├─ exercise-1.sol
│   ├─ exercise-2.sol
│   └─ README.md
│
├─ week-02/
└─ ...
```

---

## 📝 每个项目的 README 模板

### examples/ 中的 README

```markdown
# [示例名称]

> 配合章节：03-Solidity/3.2-语法基础/06-值类型-布尔型

## 🎯 演示内容

- 演示布尔型的基本用法
- 演示逻辑运算符
- 演示条件判断

## 💻 快速运行

\`\`\`bash
cd examples/03-solidity-basics/01-hello-world
npm install
npx hardhat test
\`\`\`

## 📖 代码说明

（简短说明关键代码）

## 🔗 相关章节

- 📘 [03-Solidity/3.2/06-值类型-布尔型](../../03-Solidity语言入门篇/3.2-Solidity语法基础/06-值类型-布尔型.md)
```

### projects/ 中的 README

```markdown
# [项目名称]

> ⭐ 项目X: [一句话描述]

[项目截图或Logo]

## 📊 项目信息

- 📅 开发时间：Week X-Y
- ⏱️ 投入时间：XX小时
- 🎯 学习目标：[目标]
- 🔗 在线Demo：[链接]
- 📜 部署地址：[Etherscan链接]

## 🎯 项目目标

本项目实现了XXX功能，主要目标是：
- 目标1
- 目标2

## ✨ 核心功能

- [x] 功能1
- [x] 功能2
- [x] 功能3
- [ ] 功能4（TODO）

## 🏗️ 技术架构

\`\`\`
[架构图或技术栈说明]
\`\`\`

## 📦 技术栈

- Solidity ^0.8.20
- Hardhat
- OpenZeppelin Contracts
- Ethers.js
- React + Wagmi（如果有前端）

## 💻 快速开始

### 1. 安装依赖

\`\`\`bash
cd projects/01-erc20-token
npm install
\`\`\`

### 2. 配置环境

\`\`\`bash
cp .env.example .env
# 编辑 .env 文件，填入你的配置
\`\`\`

### 3. 运行测试

\`\`\`bash
npx hardhat test
\`\`\`

### 4. 部署到测试网

\`\`\`bash
npx hardhat run scripts/deploy.js --network sepolia
\`\`\`

## 📁 项目结构

\`\`\`
项目目录结构说明...
\`\`\`

## 🔍 核心合约说明

### MyToken.sol

（简要说明核心合约的功能和设计）

## 🧪 测试

测试覆盖率：XX%

\`\`\`bash
npx hardhat coverage
\`\`\`

## 🚀 部署

详细部署文档：[docs/deployment.md](./docs/deployment.md)

已部署的合约地址：
- Sepolia: 0x...
- Mainnet: 0x...

## 💡 学到的知识点

1. **知识点1**：说明
2. **知识点2**：说明
3. **知识点3**：说明

## 🐛 已知问题

- [ ] 问题1
- [x] 问题2（已修复）

## 🔮 未来改进

- [ ] 改进1
- [ ] 改进2

## 📚 参考资源

- [资源1](链接)
- [资源2](链接)

## 📄 License

MIT

---

**如果这个项目对你有帮助，请给个⭐！**
```

---

## 🔧 .gitignore 配置

创建 `.gitignore` 文件：

```gitignore
# Hardhat files
cache
artifacts
typechain-types

# Node modules
node_modules

# Environment variables
.env
.env.local
.env.*.local

# Testing
coverage
coverage.json

# IDE
.vscode/*
!.vscode/settings.json.example
.idea

# OS
.DS_Store
Thumbs.db

# Logs
*.log

# Build
dist
build

# Temp
*.swp
*.swo
*~
```

---

## 📋 Git 提交规范

### Commit Message 格式

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Type 类型

```
feat:     新功能
fix:      修复bug
docs:     文档更新
style:    代码格式（不影响代码运行）
refactor: 重构
test:     测试相关
chore:    构建/工具相关
```

### 示例

```bash
# 文档更新
git commit -m "docs(03-solidity): 完成值类型章节"

# 添加代码示例
git commit -m "feat(examples): 添加Hello World示例"

# 完成项目
git commit -m "feat(projects): 完成ERC20项目并部署到测试网"

# 修复bug
git commit -m "fix(projects/nft): 修复mint函数的重入漏洞"
```

---

## 🚀 工作流程

### 学习新章节时

```bash
1. 创建示例目录
mkdir -p examples/03-solidity-basics/01-hello-world
cd examples/03-solidity-basics/01-hello-world

2. 初始化项目
npm init -y
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox

3. 写代码 + 测试
# 编写 HelloWorld.sol
# 编写 test.js

4. 提交
git add .
git commit -m "feat(examples): 添加HelloWorld示例"
git push
```

### 开始新项目时

```bash
1. 创建项目目录
mkdir -p projects/01-erc20-token
cd projects/01-erc20-token

2. 使用项目模板
# 复制 templates/project-template/

3. 初始化
npm install

4. 开发
# 写合约 → 写测试 → 部署 → 写文档

5. 阶段性提交
git add .
git commit -m "feat(projects/erc20): 实现基本ERC20功能"

# 完成后
git commit -m "feat(projects/erc20): 完成ERC20项目 ⭐"
```

---

## 📊 代码质量标准

### 必须达到的标准

#### 1. 代码可运行
```bash
# 所有代码必须通过以下测试
npm install  ✅ 依赖安装成功
npx hardhat compile  ✅ 编译通过
npx hardhat test  ✅ 测试通过
```

#### 2. 测试覆盖率

```
examples/  - 覆盖率 >60%
projects/  - 覆盖率 >80% ⭐
```

#### 3. 代码规范

```bash
# 使用 Solhint 检查
npx solhint 'contracts/**/*.sol'

# 没有 Critical 和 Major 警告
```

#### 4. 文档完整

```
每个项目必须有：
├─ README.md      ✅ 项目说明
├─ docs/          ✅ 详细文档
└─ 代码注释        ✅ NatSpec注释
```

---

## 🎯 代码管理最佳实践

### 1. 小步提交

```bash
❌ 不好：
git commit -m "完成Solidity章节"  # 太笼统

✅ 好：
git commit -m "feat(examples): 添加布尔型示例"
git commit -m "feat(examples): 添加整数型示例"
git commit -m "feat(examples): 添加地址类型示例"
```

### 2. 一个功能一个分支（可选）

```bash
# 开发新项目时
git checkout -b project/erc20-token

# 开发完成后
git checkout main
git merge project/erc20-token
```

### 3. 定期推送

```bash
# 每天至少一次
git push origin main

# 避免代码丢失
```

### 4. 使用标签标记里程碑

```bash
# 完成一个大项目
git tag -a v1.0-erc20 -m "完成ERC20项目"
git push origin v1.0-erc20

# 完成一个阶段
git tag -a week-08 -m "完成阶段二"
git push origin week-08
```

---

## 💡 常见问题

### Q1: 代码放在同一个仓库还是分开？

```
A: 推荐同一个仓库（Monorepo）

优势：
✅ 统一管理
✅ 方便查看进度
✅ 展示完整学习历程

如果项目特别大，可以：
projects/04-uniswap-fork/ → 单独仓库
然后在主仓库添加 submodule
```

### Q2: 敏感信息如何处理？

```
A: 永远不要提交敏感信息！

1. 使用 .env 文件
2. .gitignore 忽略 .env
3. 提供 .env.example 模板

.env.example:
PRIVATE_KEY=your_private_key_here
ETHERSCAN_API_KEY=your_api_key_here
```

### Q3: 代码写错了怎么办？

```
A: 标记TODO，继续前进！

// TODO: 这里有bug，后续修复
// 或者
// FIXME: 需要优化Gas

不要追求完美，持续迭代！
```

---

## 📚 代码示例索引

创建 `examples/README.md` 作为总索引：

```markdown
# 代码示例索引

所有代码示例的快速导航

## 03-Solidity基础

- [Hello World](./03-solidity-basics/01-hello-world) - 第一个合约
- [值类型](./03-solidity-basics/02-types) - 值类型演示
- ...

## 05-OpenZeppelin

- [ERC20基础](./05-openzeppelin/01-erc20-basic) - 基本ERC20代币
- ...

## 15-DeFi

- [Uniswap V2 Demo](./15-defi/uniswap-v2-demo) - Uniswap核心功能
- [Aave闪电贷](./15-defi/aave-flashloan-demo) - 闪电贷演示
- ...
```

---

**代码和文档一样重要！保持代码整洁，持续提交！** 💻🚀


