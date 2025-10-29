# 代码审计工具完全指南

> 💡 **核心要点**
> - 静态分析工具是第一道防线
> - Slither + Foundry 是最佳组合
> - 工具无法替代人工审计
> - 建立多层防御体系

---

## 📚 目录

1. [静态分析工具](#1-静态分析工具)
2. [动态分析与测试框架](#2-动态分析与测试框架)
3. [形式化验证工具](#3-形式化验证工具)
4. [可视化与辅助工具](#4-可视化与辅助工具)
5. [审计工作流建议](#5-审计工作流建议)

---

## 1. 静态分析工具

这类工具不运行代码，而是直接扫描源代码或字节码，根据预设的漏洞模式进行检查。它们是审计工作流的**第一道防线**。

### 1.1 Slither（强烈推荐）⭐⭐⭐⭐⭐

#### 介绍

由顶级安全公司 **Trail of Bits** 开发，是目前**最强大、最流行**的静态分析工具。它支持多种漏洞检测器，并且有很好的扩展性。

#### 优点

- **检测范围广**：内置了超过70种漏洞和代码问题的检测器
- **输出清晰**：能以多种格式（控制台、JSON、Markdown）输出报告，清晰地指出问题代码的位置和风险等级
- **可定制性强**：可以编写自己的检测脚本或禁用某些检测
- **集成方便**：可以轻松集成到 CI/CD 流程中

#### 如何使用

```bash
# 安装
pip3 install slither-analyzer

# 分析整个项目
slither .

# 分析特定合约
slither contracts/MyContract.sol

# 输出为JSON
slither . --json output.json

# 只显示高危漏洞
slither . --filter-paths "node_modules|test"
```

#### 常见检测项

- 重入攻击
- 整数溢出（Solidity < 0.8）
- 未检查的低级调用
- 访问控制问题
- Gas 优化建议
- 代码质量问题

### 1.2 Mythril

#### 介绍

一个强大的安全分析工具，它使用**符号执行 (Symbolic Execution)** 的方法来探索代码的执行路径，从而发现更深层次的漏洞。

#### 优点

- 能发现一些 Slither 可能遗漏的、与状态相关的复杂漏洞
- 可以分析已部署在链上的合约字节码

#### 缺点

- 分析速度较慢
- 可能会产生一些误报

#### 如何使用

```bash
# 安装
pip3 install mythril

# 分析合约
myth analyze contracts/MyContract.sol

# 分析链上合约
myth analyze -a 0x...contractAddress
```

### 1.3 Solhint

#### 介绍

一个专注于代码风格和安全最佳实践的**Linter（代码规范检查器）**。它更侧重于预防问题，而不是发现严重漏洞。

#### 优点

- 速度极快，可以实时集成在 VS Code 等编辑器中
- 帮助团队统一代码风格，遵循社区的最佳实践
- 规则集可配置

#### 如何使用

```bash
# 安装
npm install -g solhint

# 分析
solhint 'contracts/**/*.sol'

# 生成配置文件
solhint --init

# 自定义规则 .solhint.json
{
  "extends": "solhint:recommended",
  "rules": {
    "compiler-version": ["error", "^0.8.0"],
    "func-visibility": ["warn", {"ignoreConstructors": true}]
  }
}
```

---

## 2. 动态分析与测试框架

这类工具通过在测试环境中实际运行合约代码，模拟交易和交互，来发现运行时才可能暴露的问题。

### 2.1 Foundry（强烈推荐）⭐⭐⭐⭐⭐

#### 介绍

目前**最受专业审计员和开发者欢迎**的智能合约开发与测试框架。它使用 Solidity 语言来编写测试用例，速度极快。

#### 核心组件

- **Forge**：测试运行器。其**模糊测试 (Fuzzing)** 功能极其强大
- **Cast**：命令行工具，用于与链上合约进行交互
- **Anvil**：本地测试网节点

#### 为什么审计员喜欢它

可以直接用 Solidity 编写复杂的攻击场景和测试用例，比用 JavaScript (Hardhat) 更直观、更强大。

#### 如何使用

```bash
# 安装
curl -L https://foundry.paradigm.xyz | bash
foundryup

# 创建项目
forge init my-project
cd my-project

# 运行测试
forge test

# 模糊测试
forge test --fuzz-runs 10000

# Gas报告
forge test --gas-report

# 查看覆盖率
forge coverage
```

#### 测试示例

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/MyContract.sol";

contract MyContractTest is Test {
    MyContract public myContract;
    
    function setUp() public {
        myContract = new MyContract();
    }
    
    // 基础测试
    function testBasicFunction() public {
        uint256 result = myContract.myFunction(10);
        assertEq(result, 100);
    }
    
    // 模糊测试
    function testFuzz_MyFunction(uint256 x) public {
        vm.assume(x < type(uint256).max / 10);
        uint256 result = myContract.myFunction(x);
        assertEq(result, x * 10);
    }
    
    // 测试重入攻击
    function testReentrancyAttack() public {
        Attacker attacker = new Attacker(address(myContract));
        vm.expectRevert();
        attacker.attack();
    }
}
```

### 2.2 Hardhat

#### 介绍

一个基于 JavaScript/TypeScript 的开发环境，曾经是行业标准，现在依然非常流行。

#### 优点

- 拥有庞大的插件生态系统（如 `hardhat-gas-reporter`, `solidity-coverage`）
- JavaScript 社区庞大，上手相对容易

#### 如何使用

```bash
# 安装
npm install --save-dev hardhat

# 初始化
npx hardhat

# 运行测试
npx hardhat test

# Gas报告
npx hardhat test --grep "Gas"
```

---

## 3. 形式化验证工具

这是最硬核的一类工具，它试图用**数学方法严格证明**合约代码在所有可能的输入下都符合预设的规范。

### 3.1 Certora Prover

#### 介绍

形式化验证领域的领导者。用户需要使用一种专门的规范语言 (CVL - Certora Verification Language) 来描述合约应该遵守的"不变量"和规则。

#### 优点

- **能提供最高级别的安全保证**。一旦一个属性被证明，就意味着在数学上不可能违反它
- 能发现最隐蔽、最违反直觉的逻辑漏洞

#### 缺点

- 学习曲线极其陡峭
- 需要深厚的计算机科学和逻辑学背景
- 通常只有大型头部协议会进行形式化验证

#### 示例规范

```cvl
// Certora 规范示例
invariant totalSupplyEqualsBalances()
    sum(balanceOf) == totalSupply();

rule transferPreservesTotalSupply(address from, address to, uint256 amount) {
    uint256 totalBefore = totalSupply();
    transfer(from, to, amount);
    uint256 totalAfter = totalSupply();
    assert totalBefore == totalAfter, "Total supply changed";
}
```

---

## 4. 可视化与辅助工具

### 4.1 Solidity Visual Developer (VS Code 插件)

#### 介绍

一个 VS Code 插件，可以将合约的继承关系、函数调用图等**可视化**，帮助审计员快速理解一个复杂项目的代码结构。

#### 功能

- 合约继承图
- 函数调用图
- 状态变量依赖图
- 代码导航

### 4.2 Etherscan / Phalcon (区块浏览器)

#### 介绍

虽然是区块浏览器，但它们是分析**已发生攻击**的终极工具。

通过 Etherscan 的交易详情和 Phalcon 的交易模拟器，可以一步步回溯攻击者的每一步操作，是学习真实世界攻击手法的最佳课堂。

---

## 5. 审计工作流建议

### 5.1 专业审计员的典型工作流

1. **初步扫描**：先用 **Slither** 和 **Solhint** 对整个代码库进行快速扫描，找出所有低级和中级的已知问题

2. **手动代码审查**：**这是最核心、最不可替代的一步**。审计员会逐行阅读代码，重点理解业务逻辑，寻找设计缺陷

3. **编写测试用例**：使用 **Foundry** 针对自己怀疑有问题的复杂逻辑，编写专门的测试用例和模糊测试，尝试"打破"合约

4. **深入分析**：对于特别关键但又难以测试的模块，可能会使用 **Mythril** 或进行小范围的**形式化验证**

5. **撰写报告**：将所有发现汇总成详细的审计报告

### 5.2 推荐的工具组合

#### 基础组合（必备）

```
Slither + Foundry + Solhint
```

#### 进阶组合

```
Slither + Foundry + Mythril + Certora
```

### 5.3 CI/CD 集成示例

```yaml
# .github/workflows/security.yml
name: Security Checks

on: [push, pull_request]

jobs:
  slither:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Slither
        uses: crytic/slither-action@v0.3.0
        with:
          target: 'contracts/'
          
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install Foundry
        uses: foundry-rs/foundry-toolchain@v1
      - name: Run tests
        run: forge test
      - name: Check coverage
        run: forge coverage
```

---

## 📚 学习资源

### 工具官方文档
- [Slither](https://github.com/crytic/slither)
- [Foundry Book](https://book.getfoundry.sh/)
- [Mythril](https://github.com/ConsenSys/mythril)
- [Certora](https://www.certora.com/)

### 教程
- [Secureum](https://secureum.substack.com/) - 安全审计最佳教程
- [Smart Contract Security Best Practices](https://consensys.github.io/smart-contract-best-practices/)

---

## ✅ 学习检查清单

完成本章节后，确认你已经：

- [ ] 安装并使用了 Slither
- [ ] 安装并使用了 Foundry
- [ ] 理解了静态分析 vs 动态分析
- [ ] 知道模糊测试的重要性
- [ ] 理解了形式化验证的概念
- [ ] 建立了自己的审计工作流

---

## 🎯 下一步

1. ✅ 用 Slither 扫描你的项目
2. ✅ 用 Foundry 编写完整的测试套件
3. ✅ 集成 CI/CD 自动化检查
4. ✅ 更新你的 `PROGRESS.md`

---

**记住**：
- 🔍 **工具是辅助，人工审计最重要**
- ⚡ **Slither + Foundry 是最佳组合**
- 🧪 **模糊测试能发现意外bug**
- 🔄 **持续集成自动化检查**

祝你学习顺利！🚀

