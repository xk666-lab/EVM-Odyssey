# 代码规范与最佳实践

> 💡 **学习OpenZeppelin之前必读！**
> 
> ⏱️ 预计学习时间：**4小时**

---

## 🎯 为什么这一章如此重要？

### 学完语法 ≠ 会写好代码

```
会语法的人：
contract MyToken {
    mapping(address=>uint256) balance;  // 命名不规范
    function send(address to,uint256 amount) public {  // 格式混乱
        balance[msg.sender]-=amount;  // 没检查
        balance[to]+=amount;  // 可能溢出
    }  // 没注释，没事件
}

写好代码的人：
/// @title 我的代币
/// @notice ERC20代币实现
contract MyToken {
    /// @notice 用户余额映射
    mapping(address => uint256) private _balances;
    
    /// @notice 转账事件
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    /// @notice 转账函数
    /// @param to 接收地址
    /// @param amount 转账金额
    function transfer(address to, uint256 amount) public returns (bool) {
        require(to != address(0), "Invalid address");
        require(_balances[msg.sender] >= amount, "Insufficient balance");
        
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        
        emit Transfer(msg.sender, to, amount);
        return true;
    }
}
```

**好代码 = 语法 + 规范 + 安全 + 优化**

---

## 📚 本章内容

### 01-Solidity Style Guide官方规范 (0.5h)
- 官方代码风格指南
- 为什么需要统一规范
- 行业标准

### 02-命名规范 (0.5h) ⭐
- 合约命名：PascalCase
- 函数命名：camelCase  
- 变量命名：camelCase
- 常量命名：UPPER_CASE
- 私有变量：下划线前缀

### 03-NatSpec注释规范 (0.5h) ⭐
- @title、@author、@notice
- @dev、@param、@return
- 文档化代码
- 自动生成文档

### 04-代码组织与结构 (0.5h)
- 合约内部顺序
- 导入顺序
- 函数分组

### 05-函数顺序规范 (0.3h)
- constructor
- receive/fallback
- external
- public
- internal
- private

### 06-导入规范 (0.2h)
- 相对导入vs绝对导入
- 导入顺序

### 07-安全编码规范 (1h) ⭐⭐⭐
**关键！为Week 7铺垫**
- 检查-生效-交互模式
- 输入验证
- 防止重入
- 整数溢出检查
- 访问控制

### 08-Gas优化编码规范 (0.5h) ⭐⭐
**关键！为Week 7铺垫**
- 变量打包意识
- 使用memory缓存
- 避免不必要的存储
- 循环优化意识

### 09-错误处理规范 (0.3h)
- require vs assert vs revert
- 自定义错误
- 错误消息规范

### 10-事件规范 (0.3h)
- 何时触发事件
- indexed参数
- 事件命名

### 11-可读性最佳实践 (0.3h)
- 代码格式化
- 空行使用
- 注释风格

### 12-Linter配置-Solhint (0.3h) ⭐
- Solhint安装
- 规则配置
- 与VSCode集成

### 13-Prettier格式化 (0.2h)
- Prettier Solidity
- 自动格式化

### 14-代码审查清单 (0.2h)
- Review Checklist
- 自查与互查

---

## 🎯 学习目标

学完本章后，你将：

- ✅ 知道什么是"好代码"的标准
- ✅ 养成规范编码习惯
- ✅ 建立安全意识（为Week 7准备）
- ✅ 建立优化意识（为Week 7准备）
- ✅ 准备好学习OpenZeppelin（能理解设计）

---

## 💡 为什么要在学库之前学规范？

### 场景对比

#### ❌ 不学规范直接学OpenZeppelin

\`\`\`solidity
// 读OpenZeppelin ERC20源码

function _update(address from, address to, uint256 value) internal {
    if (from == address(0)) {
        _totalSupply += value;
    } else {
        uint256 fromBalance = _balances[from];
        if (fromBalance < value) {
            revert ERC20InsufficientBalance(from, fromBalance, value);
        }
        unchecked {  // 🤔 为什么用unchecked？
            _balances[from] = fromBalance - value;
        }
    }
    ...
}
\`\`\`

**问题**：看不懂为什么这样设计，只能照抄

#### ✅ 学完规范再学OpenZeppelin

\`\`\`solidity
// 学完3.6后，再读同样的代码

function _update(address from, address to, uint256 value) internal {
    if (from == address(0)) {
        _totalSupply += value;
    } else {
        uint256 fromBalance = _balances[from];
        if (fromBalance < value) {
            revert ERC20InsufficientBalance(from, fromBalance, value);
        }
        unchecked {  // ✅ 懂了！上面已经检查过，用unchecked省Gas
            _balances[from] = fromBalance - value;
        }
    }
    ...
}
\`\`\`

**收获**：理解设计思路，能举一反三！

---

## 🚀 后续章节

学完本章后，继续学习：

1. **Week 7**：`08-基础安全篇` ⭐
   - 深入安全知识
   - 理解常见漏洞

2. **Week 7**：`12-Gas优化篇/基础部分` ⭐
   - 深入优化技巧
   - 理解Gas原理

3. **Week 8**：`05-智能合约库深入篇` 🎯
   - 带着规范知识学习
   - 理解库的设计
   - 学到最佳实践

---

## ✅ 学习检查清单

- [ ] 掌握命名规范
- [ ] 会写NatSpec注释
- [ ] 理解安全编码基本原则
- [ ] 理解Gas优化基本原则
- [ ] 配置了Solhint
- [ ] 能写出规范的合约

---

**Let's write clean, secure, and optimized code! 💎**

