# 访问控制漏洞 (Access Control Vulnerabilities)

> 💡 **核心要点**
> - 访问控制是智能合约安全的基石
> - 永远不要使用 `tx.origin` 做权限验证
> - 修饰符（modifier）是实现权限控制的最佳实践
> - Ownable 和 AccessControl 是经过验证的模式

---

## 📚 目录

1. [访问控制概述](#1-访问控制概述)
2. [常见的权限漏洞](#2-常见的权限漏洞)
3. [tx.origin vs msg.sender](#3-txorigin-vs-msgsender)
4. [修饰符安全](#4-修饰符安全)
5. [Ownable 模式](#5-ownable-模式)
6. [AccessControl 模式](#6-accesscontrol-模式)
7. [实战演练](#7-实战演练)
8. [最佳实践](#8-最佳实践)
9. [深入思考](#9-深入思考)

---

## 1. 访问控制概述

### 1.1 什么是访问控制？

访问控制确保只有授权的用户才能执行特定的操作。在智能合约中，这通常意味着限制谁可以：
- 修改合约状态
- 提取资金
- 暂停/升级合约
- 铸造代币
- 修改配置参数

### 1.2 为什么访问控制很重要？

```solidity
// ❌ 没有访问控制的合约
contract VulnerableBank {
    mapping(address => uint256) public balances;
    
    // 任何人都可以提取任何人的钱！
    function withdraw(address user, uint256 amount) public {
        require(balances[user] >= amount);
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success);
        
        balances[user] -= amount;
    }
}
```

**后果**：
- 💸 资金被盗
- 🔓 合约被恶意控制
- 💔 用户信任崩塌

### 1.3 访问控制的类型

| 类型 | 说明 | 适用场景 |
|------|------|----------|
| **单一所有者** | 只有一个账户拥有管理权限 | 简单 DApp、个人项目 |
| **多签钱包** | 需要多个签名才能执行 | DAO、团队管理的合约 |
| **基于角色** | 不同角色有不同权限 | 复杂 DeFi 协议、企业应用 |
| **时间锁** | 操作需要延迟执行 | 治理合约、协议升级 |

---

## 2. 常见的权限漏洞

### 2.1 缺失权限检查

#### ❌ 漏洞示例

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract VulnerableToken {
    mapping(address => uint256) public balances;
    uint256 public totalSupply;
    
    // ❌ 任何人都可以铸造代币！
    function mint(address to, uint256 amount) public {
        balances[to] += amount;
        totalSupply += amount;
    }
}
```

#### ✅ 修复后

```solidity
contract SafeToken {
    mapping(address => uint256) public balances;
    uint256 public totalSupply;
    address public owner;
    
    constructor() {
        owner = msg.sender;
    }
    
    // ✅ 只有 owner 可以铸造
    function mint(address to, uint256 amount) public {
        require(msg.sender == owner, "Only owner can mint");
        balances[to] += amount;
        totalSupply += amount;
    }
}
```

### 2.2 未初始化的 Owner

#### ❌ 漏洞示例

```solidity
contract UninitializedOwner {
    address public owner;  // ❌ 默认值是 address(0)
    
    function mint(address to, uint256 amount) public {
        require(msg.sender == owner);
        // ...
    }
}
```

**问题**：
- `owner` 初始值是 `address(0)`
- 如果没有初始化，任何人都无法调用 `mint`
- 或者，如果检查不严格，可能被利用

#### ✅ 修复

```solidity
contract InitializedOwner {
    address public owner;
    
    constructor() {
        owner = msg.sender;  // ✅ 在构造函数中初始化
    }
}
```

### 2.3 权限验证的逻辑错误

#### ❌ 漏洞示例

```solidity
contract LogicError {
    address public admin;
    
    constructor() {
        admin = msg.sender;
    }
    
    // ❌ 逻辑反了！
    function dangerousFunction() public {
        require(msg.sender != admin, "Not admin");  // 应该是 ==
        // 敏感操作
    }
}
```

### 2.4 前门后门并存

#### ❌ 漏洞示例

```solidity
contract BackdoorContract {
    address public owner;
    
    constructor() {
        owner = msg.sender;
    }
    
    function transferOwnership(address newOwner) public {
        require(msg.sender == owner);
        owner = newOwner;
    }
    
    // ❌ 后门：任何人都可以提取资金！
    function emergencyWithdraw() public {
        payable(msg.sender).transfer(address(this).balance);
    }
}
```

---

## 3. tx.origin vs msg.sender

### 3.1 区别是什么？

```solidity
// 场景：用户 Alice 调用合约 A，合约 A 调用合约 B

// 在合约 B 中：
// tx.origin  = Alice（原始发起者，永远是 EOA）
// msg.sender = 合约 A（直接调用者）
```

**图示**：

```
Alice (EOA) --调用--> Contract A --调用--> Contract B

在 Contract B 中：
├─ tx.origin  = Alice
└─ msg.sender = Contract A
```

### 3.2 为什么 tx.origin 危险？

#### ❌ 使用 tx.origin 的漏洞合约

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract VulnerableWallet {
    address public owner;
    
    constructor() {
        owner = msg.sender;
    }
    
    // ❌ 使用 tx.origin 验证权限
    function withdraw(address payable to, uint256 amount) public {
        require(tx.origin == owner, "Not owner");
        to.transfer(amount);
    }
    
    receive() external payable {}
}
```

#### 💣 攻击合约

```solidity
contract AttackWallet {
    VulnerableWallet public wallet;
    address public attacker;
    
    constructor(address _walletAddress) {
        wallet = VulnerableWallet(payable(_walletAddress));
        attacker = msg.sender;
    }
    
    // 攻击函数（诱骗 owner 调用）
    function attack() public {
        // 当 owner 调用此函数时：
        // tx.origin = owner
        // msg.sender = AttackWallet
        
        // 由于 VulnerableWallet 使用 tx.origin，检查会通过！
        wallet.withdraw(payable(attacker), address(wallet).balance);
    }
}
```

#### 🎣 攻击流程

```
1. 攻击者部署 AttackWallet
2. 攻击者诱骗 owner 调用 AttackWallet.attack()
   （比如说："这是一个空投合约，快来领取！"）
3. 当 owner 调用时：
   - tx.origin = owner (通过检查！)
   - AttackWallet.attack() 调用 VulnerableWallet.withdraw()
4. 资金被盗到攻击者地址
```

这个tx.origin是可以通过被别人引诱而间接去调用这个函数，导致财产得到亏损



### 3.3 正确的方式

#### ✅ 使用 msg.sender

```solidity
contract SafeWallet {
    address public owner;
    
    constructor() {
        owner = msg.sender;
    }
    
    // ✅ 使用 msg.sender 验证
    function withdraw(address payable to, uint256 amount) public {
        require(msg.sender == owner, "Not owner");
        to.transfer(amount);
    }
    
    receive() external payable {}
}
```

**为什么安全**：
- 攻击者的合约调用时，`msg.sender` 是攻击合约地址，不是 owner
- 检查会失败，攻击被阻止

### 3.4 tx.origin 的唯一合法用途

```solidity
// 仅用于日志记录，不用于权限验证
event Action(address indexed txOrigin, address indexed msgSender);

function doSomething() public {
    emit Action(tx.origin, msg.sender);
    // 记录原始用户和直接调用者
}
```

### 3.5 对比总结

| 特性 | tx.origin | msg.sender |
|------|-----------|------------|
| **定义** | 交易的原始发起者（EOA） | 当前函数的直接调用者 |
| **类型** | 永远是 EOA（外部账户） | 可以是 EOA 或合约 |
| **跨合约** | 不变（始终是最初的用户） | 变化（每次调用都是直接调用者） |
| **用于权限** | ❌ 危险！容易被钓鱼 | ✅ 安全，推荐 |
| **Gas 成本** | 相同 | 相同 |

---

## 4. 修饰符安全

### 4.1 什么是修饰符？

修饰符（Modifier）是 Solidity 中的一种语法糖，用于在函数执行前/后插入检查逻辑。

### 4.2 基础修饰符

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract ModifierExample {
    address public owner;
    
    constructor() {
        owner = msg.sender;
    }
    
    // ✅ 定义修饰符
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;  // 函数体在这里执行
    }
    
    // ✅ 使用修饰符
    function restrictedFunction() public onlyOwner {
        // 只有 owner 可以执行
    }
}
```

### 4.3 修饰符的执行顺序

```solidity
contract OrderExample {
    bool public step1;
    bool public step2;
    
    modifier first() {
        step1 = true;
        _;  // 函数体
        step1 = false;
    }
    
    modifier second() {
        step2 = true;
        _;  // 函数体
        step2 = false;
    }
    
    // 修饰符从左到右执行
    function test() public first second {
        // 执行顺序：
        // 1. step1 = true (first 前)
        // 2. step2 = true (second 前)
        // 3. 函数体
        // 4. step2 = false (second 后)
        // 5. step1 = false (first 后)
    }
}
```

### 4.4 常见的修饰符错误

#### ❌ 错误 1：忘记 `_`

```solidity
modifier broken() {
    require(msg.sender == owner);
    // ❌ 忘记了 _，函数体永远不会执行！
}
```

#### ❌ 错误 2：`_` 位置错误

```solidity
modifier alwaysReverts() {
    _;  // 函数体先执行
    require(false, "Always fails");  // 然后总是失败
}
```

#### ❌ 错误 3：修饰符内的状态修改

```solidity
uint256 public count;

// ⚠️ 谨慎：修饰符中修改状态
modifier incrementCount() {
    count++;  // 即使函数 revert，这个也会执行
    _;
}

function mayFail() public incrementCount {
    require(false, "Always fails");
    // count 仍然增加了！
}
```

**正确做法**：

```solidity
modifier safeIncrement() {
    _;  // 先执行函数
    count++;  // 函数成功后才增加
}
```

### 4.5 高级修饰符模式

#### 模式 1：带参数的修饰符

```solidity
contract ParameterizedModifier {
    mapping(address => bool) public whitelist;
    
    modifier onlyWhitelisted(address user) {
        require(whitelist[user], "Not whitelisted");
        _;
    }
    
    function restrictedAction(address user) public onlyWhitelisted(user) {
        // 只有白名单用户可以执行
    }
}
```

#### 模式 2：组合修饰符

```solidity
contract CombinedModifiers {
    address public owner;
    bool public paused;
    
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused);
        _;
    }
    
    // 同时检查两个条件
    function emergencyStop() public onlyOwner whenNotPaused {
        paused = true;
    }
}
```

#### 模式 3：可重入保护修饰符

```solidity
contract ReentrancyGuard {
    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    
    constructor() {
        _status = _NOT_ENTERED;
    }
    
    modifier nonReentrant() {
        require(_status != _ENTERED, "Reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
    
    function withdraw(uint256 amount) public nonReentrant {
        // 防止重入攻击
    }
}
```

---

## 5. Ownable 模式

### 5.1 Ownable 是什么？

Ownable 是最常见的访问控制模式，提供基本的单一所有者权限管理。

### 5.2 自己实现 Ownable

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Ownable {
    address private _owner;
    
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    
    constructor() {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }
    
    // 查看当前 owner
    function owner() public view returns (address) {
        return _owner;
    }
    
    // 修饰符：仅 owner
    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: caller is not the owner");
        _;
    }
    
    // 放弃所有权（谨慎使用！）
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
    
    // 转移所有权
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}
```

### 5.3 使用 Ownable

```solidity
contract MyToken is Ownable {
    mapping(address => uint256) public balances;
    uint256 public totalSupply;
    
    // ✅ 只有 owner 可以铸造
    function mint(address to, uint256 amount) public onlyOwner {
        balances[to] += amount;
        totalSupply += amount;
    }
    
    // ✅ 只有 owner 可以销毁
    function burn(address from, uint256 amount) public onlyOwner {
        require(balances[from] >= amount);
        balances[from] -= amount;
        totalSupply -= amount;
    }
}
```

### 5.4 OpenZeppelin 的 Ownable

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";

contract MyContract is Ownable {
    // constructor() Ownable(msg.sender) {}  // Ownable 2.0 需要传入初始 owner
    
    function restrictedFunction() public onlyOwner {
        // 只有 owner 可以执行
    }
}
```

### 5.5 Ownable 的风险

#### ❌ 风险 1：单点故障

```solidity
// 如果 owner 私钥丢失或泄露，合约将：
// - 无法管理（丢失）
// - 被恶意控制（泄露）
```

**解决方案**：使用多签钱包或 DAO 作为 owner

#### ❌ 风险 2：误操作

```solidity
contract AccidentalRenounce is Ownable {
    function importantFunction() public onlyOwner {
        renounceOwnership();  // ❌ 手滑点错了！
        // 合约永久失去管理权限
    }
}
```

**解决方案**：
- 添加时间锁
- 使用两步转移
- 去除 `renounceOwnership` 函数

#### ✅ 改进：两步转移

```solidity
contract TwoStepOwnable {
    address public owner;
    address public pendingOwner;
    
    function transferOwnership(address newOwner) public {
        require(msg.sender == owner);
        pendingOwner = newOwner;
    }
    
    // 新 owner 必须主动接受
    function acceptOwnership() public {
        require(msg.sender == pendingOwner);
        owner = pendingOwner;
        pendingOwner = address(0);
    }
}
```

---

## 6. AccessControl 模式

### 6.1 基于角色的访问控制

对于复杂的 DApp，Ownable 不够用，需要多种角色。

### 6.2 自己实现 AccessControl

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract AccessControl {
    // 角色定义
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    
    // 角色 => 地址 => 是否拥有
    mapping(bytes32 => mapping(address => bool)) private _roles;
    
    event RoleGranted(bytes32 indexed role, address indexed account);
    event RoleRevoked(bytes32 indexed role, address indexed account);
    
    constructor() {
        // 部署者获得 ADMIN_ROLE
        _grantRole(ADMIN_ROLE, msg.sender);
    }
    
    // 检查是否拥有角色
    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }
    
    // 修饰符：只有拥有特定角色的用户
    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "AccessControl: unauthorized");
        _;
    }
    
    // 授予角色
    function grantRole(bytes32 role, address account) public onlyRole(ADMIN_ROLE) {
        _grantRole(role, account);
    }
    
    // 撤销角色
    function revokeRole(bytes32 role, address account) public onlyRole(ADMIN_ROLE) {
        _revokeRole(role, account);
    }
    
    // 放弃自己的角色
    function renounceRole(bytes32 role) public {
        _revokeRole(role, msg.sender);
    }
    
    // 内部函数
    function _grantRole(bytes32 role, address account) internal {
        if (!_roles[role][account]) {
            _roles[role][account] = true;
            emit RoleGranted(role, account);
        }
    }
    
    function _revokeRole(bytes32 role, address account) internal {
        if (_roles[role][account]) {
            _roles[role][account] = false;
            emit RoleRevoked(role, account);
        }
    }
}
```

### 6.3 使用 AccessControl

```solidity
contract AdvancedToken is AccessControl {
    mapping(address => uint256) public balances;
    
    // ✅ 只有 MINTER_ROLE 可以铸造
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        balances[to] += amount;
    }
    
    // ✅ 只有 BURNER_ROLE 可以销毁
    function burn(address from, uint256 amount) public onlyRole(BURNER_ROLE) {
        balances[from] -= amount;
    }
    
    // ✅ 只有 ADMIN_ROLE 可以暂停
    function pause() public onlyRole(ADMIN_ROLE) {
        // 暂停逻辑
    }
}
```

### 6.4 OpenZeppelin 的 AccessControl

```solidity
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MyToken is AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }
    
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        // 铸造逻辑
    }
}
```

### 6.5 角色层级

```solidity
contract HierarchicalRoles is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    
    constructor() {
        // 设置角色层级
        _setRoleAdmin(MANAGER_ROLE, ADMIN_ROLE);  // ADMIN 管理 MANAGER
        _setRoleAdmin(OPERATOR_ROLE, MANAGER_ROLE);  // MANAGER 管理 OPERATOR
        
        _grantRole(ADMIN_ROLE, msg.sender);
    }
}
```

---

## 7. 实战演练

### 7.1 Remix 练习：tx.origin 攻击

#### 文件 1: `VulnerableWallet.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract VulnerableWallet {
    address public owner;
    
    constructor() payable {
        owner = msg.sender;
    }
    
    // ❌ 使用 tx.origin
    function withdraw(address payable to, uint256 amount) public {
        require(tx.origin == owner, "Not owner");
        to.transfer(amount);
    }
    
    function deposit() public payable {}
    
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
```

#### 文件 2: `AttackWallet.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IVulnerableWallet {
    function withdraw(address payable to, uint256 amount) external;
}

contract AttackWallet {
    IVulnerableWallet public wallet;
    address payable public attacker;
    
    constructor(address _walletAddress) {
        wallet = IVulnerableWallet(_walletAddress);
        attacker = payable(msg.sender);
    }
    
    // 🎣 诱饵函数（伪装成空投）
    function claimAirdrop() public {
        // 当 owner 调用此函数时，盗取钱包的资金
        wallet.withdraw(attacker, address(wallet).balance);
    }
    
    function getAttackerBalance() public view returns (uint256) {
        return attacker.balance;
    }
}
```

#### 攻击步骤

1. **部署 VulnerableWallet**（Account 1 作为 owner）
   ```
   Value: 5 ETH
   Deploy
   ```

2. **部署 AttackWallet**（Account 2 作为攻击者）
   ```
   参数: VulnerableWallet 地址
   Deploy
   ```

3. **攻击者伪装**
   ```
   攻击者告诉 owner："这是一个空投合约，快来领取 100 ETH！"
   ```

4. **Owner 上钩**（切换到 Account 1）
   ```
   调用 AttackWallet.claimAirdrop()
   ```

5. **观察结果**
   ```
   VulnerableWallet.getBalance() → 0 ETH（被掏空！）
   AttackWallet.getAttackerBalance() → 增加了 5 ETH
   ```

### 7.2 练习：修复漏洞

修改 `VulnerableWallet.sol`，使用 `msg.sender` 而不是 `tx.origin`：

<details>
<summary>💡 点击查看答案</summary>

```solidity
contract SafeWallet {
    address public owner;
    
    constructor() payable {
        owner = msg.sender;
    }
    
    // ✅ 使用 msg.sender
    function withdraw(address payable to, uint256 amount) public {
        require(msg.sender == owner, "Not owner");
        to.transfer(amount);
    }
    
    function deposit() public payable {}
    
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
```

**再次尝试攻击**：
- Owner 调用 `AttackWallet.claimAirdrop()`
- `AttackWallet` 调用 `SafeWallet.withdraw()`
- `msg.sender` 是 `AttackWallet` 地址，不是 owner
- ❌ 交易失败："Not owner"
</details>

### 7.3 练习：实现多角色代币

实现一个代币合约，要求：
- ADMIN 可以授予/撤销角色
- MINTER 可以铸造
- BURNER 可以销毁
- PAUSER 可以暂停转账

<details>
<summary>💡 点击查看答案</summary>

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract MultiRoleToken {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER");
    
    mapping(bytes32 => mapping(address => bool)) private _roles;
    mapping(address => uint256) public balances;
    uint256 public totalSupply;
    bool public paused;
    
    constructor() {
        _grantRole(ADMIN_ROLE, msg.sender);
    }
    
    modifier onlyRole(bytes32 role) {
        require(_roles[role][msg.sender], "Unauthorized");
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused, "Paused");
        _;
    }
    
    function grantRole(bytes32 role, address account) public onlyRole(ADMIN_ROLE) {
        _grantRole(role, account);
    }
    
    function _grantRole(bytes32 role, address account) internal {
        _roles[role][account] = true;
    }
    
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        balances[to] += amount;
        totalSupply += amount;
    }
    
    function burn(address from, uint256 amount) public onlyRole(BURNER_ROLE) {
        balances[from] -= amount;
        totalSupply -= amount;
    }
    
    function pause() public onlyRole(PAUSER_ROLE) {
        paused = true;
    }
    
    function unpause() public onlyRole(PAUSER_ROLE) {
        paused = false;
    }
    
    function transfer(address to, uint256 amount) public whenNotPaused {
        require(balances[msg.sender] >= amount);
        balances[msg.sender] -= amount;
        balances[to] += amount;
    }
}
```
</details>

---

## 8. 最佳实践

### 8.1 权限检查清单

- [ ] 所有管理函数都有权限检查
- [ ] 使用 `msg.sender` 而不是 `tx.origin`
- [ ] Owner 在构造函数中初始化
- [ ] 敏感函数使用修饰符
- [ ] 考虑使用两步转移所有权
- [ ] 使用 OpenZeppelin 的经过审计的库

### 8.2 选择合适的模式

| 场景 | 推荐模式 | 理由 |
|------|---------|------|
| 简单 DApp | Ownable | 足够简单，Gas 低 |
| 多人管理 | MultiSig | 去中心化，安全 |
| 复杂权限 | AccessControl | 灵活，可扩展 |
| DAO 治理 | Timelock + DAO | 社区驱动，透明 |

### 8.3 代码示例

#### ✅ 推荐写法

```solidity
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract BestPractice is Ownable, Pausable {
    mapping(address => uint256) public balances;
    
    // ✅ 使用修饰符组合
    function emergencyWithdraw() public onlyOwner whenPaused {
        // 只有 owner 在暂停时可以执行
    }
    
    // ✅ 事件记录
    event AdminAction(address indexed admin, string action);
    
    function criticalFunction() public onlyOwner {
        emit AdminAction(msg.sender, "criticalFunction");
        // 敏感操作
    }
}
```

#### ❌ 不推荐写法

```solidity
contract BadPractice {
    address owner;  // ❌ 不是 public，难以验证
    
    // ❌ 没有修饰符，代码重复
    function func1() public {
        require(msg.sender == owner);
        // ...
    }
    
    function func2() public {
        require(msg.sender == owner);
        // ...
    }
    
    // ❌ 使用 tx.origin
    function dangerous() public {
        require(tx.origin == owner);
    }
}
```

### 8.4 测试策略

```solidity
// 使用 Foundry 测试权限
contract AccessControlTest is Test {
    MyContract c;
    address owner = address(1);
    address user = address(2);
    
    function setUp() public {
        vm.prank(owner);
        c = new MyContract();
    }
    
    function testOnlyOwnerCanMint() public {
        // 测试非 owner 不能铸造
        vm.prank(user);
        vm.expectRevert("Not owner");
        c.mint(user, 100);
        
        // 测试 owner 可以铸造
        vm.prank(owner);
        c.mint(user, 100);
        assertEq(c.balances(user), 100);
    }
}
```

---

## 9. 深入思考

### 9.1 为什么不能完全依赖修饰符？

**修饰符只是语法糖**，底层仍然是代码逻辑。如果修饰符本身有漏洞，或者被错误使用，仍然会导致安全问题。

```solidity
// ❌ 修饰符的陷阱
modifier badModifier() {
    if (msg.sender == owner) {
        _;
    }
    // 注意：如果不是 owner，函数仍然返回成功（只是不执行函数体）
}
```

**正确做法**：

```solidity
modifier goodModifier() {
    require(msg.sender == owner);
    _;
}
```

### 9.2 去中心化 vs 安全性

- **中心化**（Ownable）：快速响应，但单点故障
- **去中心化**（DAO）：更安全，但决策慢

**平衡方案**：
```
Emergency MultiSig (2/3) → 快速响应紧急情况
    ↓
DAO Governance (7天投票) → 常规升级和决策
```

### 9.3 真实案例：Parity 多签钱包漏洞

**2017年11月**，Parity 多签钱包的库合约被"意外"销毁，导致价值 1.5 亿美元的 ETH 永久冻结。

**原因**：
- 库合约的 `initWallet` 函数没有权限检查
- 任何人都可以调用它，将自己设为 owner
- 一个用户调用后，又调用了 `kill` 函数（自毁）
- 所有依赖这个库的钱包都失效了

**教训**：
- 库合约也需要权限检查
- `selfdestruct` 要极其谨慎
- 多签不是万能的，代码审计才是根本

---

## 📚 学习资源

### 官方文档
- [OpenZeppelin Ownable](https://docs.openzeppelin.com/contracts/access-control#ownership-and-ownable)
- [OpenZeppelin AccessControl](https://docs.openzeppelin.com/contracts/access-control#role-based-access-control)
- [Solidity Security Considerations](https://docs.soliditylang.org/en/latest/security-considerations.html)

### 工具
- [Slither](https://github.com/crytic/slither) - 检测权限问题
- [Mythril](https://github.com/ConsenSys/mythril) - 符号执行

### 真实案例
- [Parity Wallet Hack](https://www.parity.io/blog/a-postmortem-on-the-parity-multi-sig-library-self-destruct/)
- [Rekt News - Access Control](https://rekt.news/)

### 在线挑战
- [Ethernaut - Fallout](https://ethernaut.openzeppelin.com/level/2) - 构造函数漏洞
- [Ethernaut - Telephone](https://ethernaut.openzeppelin.com/level/4) - tx.origin 攻击
- [Capture the Ether - Authorization](https://capturetheether.com/challenges/)

---

## ✅ 学习检查清单

完成本章节后，确认你已经：

- [ ] 理解了访问控制的重要性
- [ ] 知道常见的权限漏洞类型
- [ ] 明白 `tx.origin` 为什么危险
- [ ] 掌握 `msg.sender` 的正确用法
- [ ] 会编写和使用修饰符
- [ ] 理解 Ownable 模式的实现
- [ ] 了解 AccessControl 的应用场景
- [ ] 在 Remix 中复现了 tx.origin 攻击
- [ ] 完成了多角色代币的练习
- [ ] （可选）完成了 Ethernaut Telephone 挑战

---

## 🎯 下一步

1. ✅ 在 Remix 中实践 tx.origin 攻击
2. ✅ 完成 Ethernaut Level 4: Telephone
3. ✅ 实现一个带多角色的代币合约
4. ✅ 继续学习下一个漏洞：**04-时间戳依赖**
5. ✅ 更新你的 `PROGRESS.md`

---

**记住**：
- 🔐 **永远不要使用 tx.origin 做权限验证**
- 📝 **使用修饰符提高代码可读性**
- 🏛️ **优先使用 OpenZeppelin 的经过审计的库**
- 🧪 **为所有权限函数编写测试**

祝你学习顺利！🚀
