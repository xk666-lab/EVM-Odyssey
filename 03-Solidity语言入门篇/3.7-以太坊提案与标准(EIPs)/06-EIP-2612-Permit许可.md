# EIP-2612 Permit 许可

> 📝 待编写

## 学习目标

- 理解 Gasless Approval 的概念
- 掌握 Permit 的实现原理
- 学会集成 Permit 功能
- 理解与 EIP-712 的关系

## 大纲

### 1. 传统 Approval 的问题

#### 1.1 两步流程
```solidity
// 步骤1：用户授权（需要 Gas）
token.approve(spender, amount);

// 步骤2：协议使用授权
protocol.doSomething();  // 内部调用 transferFrom
```

#### 1.2 痛点
- 用户需要发送两笔交易
- 需要支付两次 Gas
- 用户体验差

### 2. Permit 的解决方案

#### 2.1 一步完成
```solidity
// 用户只需签名（免 Gas）
const signature = await signer.signTypedData(...);

// 协议一次完成授权+操作
protocol.doSomethingWithPermit(
    owner, spender, value, deadline, v, r, s
);
```

### 3. EIP-2612 接口

```solidity
interface IERC20Permit {
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
    
    function nonces(address owner) external view returns (uint256);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
```

### 4. 完整实现

```solidity
contract ERC20Permit is ERC20, EIP712 {
    mapping(address => uint256) private _nonces;
    
    bytes32 private constant PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );
    
    constructor(string memory name) EIP712(name, "1") {}
    
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(block.timestamp <= deadline, "Permit expired");
        
        bytes32 structHash = keccak256(abi.encode(
            PERMIT_TYPEHASH,
            owner,
            spender,
            value,
            _useNonce(owner),
            deadline
        ));
        
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == owner, "Invalid signature");
        
        _approve(owner, spender, value);
    }
    
    function nonces(address owner) external view returns (uint256) {
        return _nonces[owner];
    }
    
    function _useNonce(address owner) internal returns (uint256 current) {
        current = _nonces[owner];
        _nonces[owner]++;
    }
}
```

### 5. 前端集成

```javascript
// 1. 准备签名数据
const value = {
  owner: ownerAddress,
  spender: protocolAddress,
  value: amount,
  nonce: await token.nonces(ownerAddress),
  deadline: Math.floor(Date.now() / 1000) + 3600  // 1小时
};

// 2. 用户签名
const signature = await signer._signTypedData(domain, types, value);
const { v, r, s } = ethers.utils.splitSignature(signature);

// 3. 调用协议（一次交易完成所有操作）
await protocol.doSomethingWithPermit(
  ownerAddress,
  protocolAddress,
  amount,
  deadline,
  v, r, s
);
```

### 6. 实际应用场景

#### 6.1 Uniswap V2
```solidity
function removeLiquidityWithPermit(
    address tokenA,
    address tokenB,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    address to,
    uint deadline,
    bool approveMax,
    uint8 v, bytes32 r, bytes32 s
) external returns (uint amountA, uint amountB);
```

#### 6.2 DEX 交易
- 一笔交易完成授权+交易
- 用户体验极佳

#### 6.3 DAO 投票
- 签名投票
- 节省 Gas

### 7. 安全考虑

#### 7.1 Nonce 管理
```solidity
// ✅ 正确：使用后立即递增
uint256 current = _nonces[owner]++;

// ❌ 错误：可能被重放
uint256 current = _nonces[owner];
```

#### 7.2 Deadline 检查
```solidity
require(block.timestamp <= deadline, "Permit expired");
```

#### 7.3 签名验证
```solidity
address signer = ECDSA.recover(hash, v, r, s);
require(signer == owner, "Invalid signature");
```

### 8. 与 EIP-3009 的对比

| 特性 | EIP-2612 (Permit) | EIP-3009 |
|------|-------------------|----------|
| 授权 | 授权额度 | 直接转账 |
| 灵活性 | 高（可多次使用） | 低（一次性） |
| 采用度 | 广泛 | 较少 |
| 代表项目 | Uniswap | Coinbase USDC |

### 9. OpenZeppelin 实现

```solidity
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract MyToken is ERC20Permit {
    constructor() ERC20("MyToken", "MTK") ERC20Permit("MyToken") {}
}
```

### 10. 实战练习

#### 练习 1：实现 Permit
1. 创建支持 Permit 的 ERC-20
2. 测试 permit 函数
3. 验证 nonce 递增

#### 练习 2：前端集成
1. 实现签名逻辑
2. 调用 permit
3. 验证授权成功

#### 练习 3：协议集成
```solidity
contract Protocol {
    function doWithPermit(
        IERC20Permit token,
        address owner,
        uint256 amount,
        uint256 deadline,
        uint8 v, bytes32 r, bytes32 s
    ) external {
        // 1. 调用 permit 完成授权
        token.permit(owner, address(this), amount, deadline, v, r, s);
        
        // 2. 使用授权
        token.transferFrom(owner, address(this), amount);
        
        // 3. 执行业务逻辑
        // ...
    }
}
```

---

## ✅ 检查清单

- [ ] 理解 Gasless Approval
- [ ] 掌握 Permit 实现
- [ ] 理解与 EIP-712 的关系
- [ ] 会前端集成
- [ ] 知道实际应用
- [ ] 了解安全注意事项

---

## 📚 参考资料

- [EIP-2612 官方文档](https://eips.ethereum.org/EIPS/eip-2612)
- [OpenZeppelin ERC20Permit](https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#ERC20Permit)
- [Uniswap Permit2](https://github.com/Uniswap/permit2)

