# gas优化





## **1.存储变量的打包**

将变量打包在一个槽位中，方法是将其定义为较低的数据类型。打包仅当在同一调用中访问打包槽位中的多个变量时才有用。如果操作不当，由于需要进行移位，反而会增加 gas 成本。

Before: 

```
contract MyContract {
  uint32  x; // Storage slot 0
  uint256 y; // Storage slot 1
  uint32  z; // Storage slot 2
}
```

After:

```
contract MyContract {
  uint32 x;  // Storage slot 0
  uint32 z;  // Storage slot 0
  uint256 y; // Storage slot 1
}
```

假设evm的32字节是一个储物柜，并且不是一个变量就占据一个储物柜，而是转满位置，所以如果两个小类型变量的在一起声明，他们可以装进同一个柜子里，然后另外一个变量装进另外一个，这样只需要两个，如果，不在一起声明，会需要三个储物柜。因为声明x时有一个储物柜，后面又声明一个大的，转不下了，只能又开一个，后面还有一个小变量也要有一个。因此，需要三个。还浪费了许多空间。

你好！我们来深入探讨一下这个非常重要的 Gas 优化技巧——**存储打包 (Storage Packing)**。当前时间是2025年9月15日，星期一，凌晨2:38，地点在美国。

你的理解**大方向是完全正确的**！你已经抓住了核心思想：**将较小的数据类型紧挨着声明，以便将它们打包进同一个存储槽中。**

现在，我们来精确一下你理解中的一些细节，并解释其背后的原理。

------



### 核心原理：EVM 的 32 字节“储物柜”



你可以把智能合约的存储空间想象成一排**固定大小的储物柜（Storage Slots）**。

- **每个储物柜的宽度都是 32 字节 (256 位)。**
- EVM 收取 Gas 费的一个主要依据是**你占用了多少个储物柜**，而不是储物柜里装了多少东西。哪怕一个储物柜只放了一支笔，也要收一整个柜子的租金。

现在我们来看不同数据类型的大小：

- `uint256`: 32 字节宽。**正好能装满一个储物柜。**
- `uint128`: 16 字节宽。占半个储物柜。
- `uint32`: 4 字节宽。只占储物柜的一小部分。
- `address`: 20 字节宽。
- `bool`: 1 字节宽。

**存储打包的原理就是**：当 Solidity 编译器发现你连续声明了多个小尺寸的变量时，它会尽可能地将它们**“塞进”同一个 32 字节的储物柜**，直到装满为止。

EVM 在打包时只关心两件事：

1. 这个变量是不是一个**“值类型” (Value Type)**？
2. 把它放进去后，当前的储物柜（存储槽）还剩下多少**空间**？

它完全**不关心**你放进来的是 `uint32` 还是 `bytes4` 还是 `address` 还是 `bool`。在 EVM 看来，它们都是不同长度的字节序列而已。

### “可打包” vs “不可打包”的类型

- **可打包的类型 (值类型)**：
  - `uint` / `int` (所有位数，如 `uint8`, `uint128`)
  - `bytes1` 到 `bytes32`
  - `address` (20 字节)
  - `bool` (1 字节)
  - `enum` (枚举，通常是 `uint8`)
- **不可打包的类型 (引用类型)**：
  - `mapping`
  - 动态数组 (`[]`)
  - `bytes`
  - `string`

这些引用类型的数据结构比较复杂，它们本身就需要占据一整个存储槽来存放它们的元信息（比如长度或指针），因此它们不能和其他变量共享一个存储槽。

## **2.局部变量赋值**

捕获内存/堆栈中经常使用的存储变量，将多个 `SLOAD` 转换为 1 个 `SLOAD` 。

Before: 前：

```solidity
uint256 length = 10;

function loop() public {
    for (uint256 i = 0; i < length; i++) {
        // do something here
    }
}
```

After: 后：

```solidity
uint256 length = 10;

function loop() {
    uint256 l = length;

    for (uint256 i = 0; i < l; i++) {
        // do something here
    }
}
```

这样也能节省gas，

**核心原理在于：局部变量存储的位置不同，其读写成本也天差地别。**

在函数执行期间，EVM（以太坊虚拟机）为局部变量提供了三个“工作区”：

1. **栈 (Stack)**：最快、最便宜。
2. **内存 (Memory)**：速度和成本居中。
3. **存储 (Storage)**：最慢、最昂贵。

### 1. 栈变量 (Stack Variables) - 成本最低



- **是什么**：在函数中声明的**简单值类型**变量，如 `uint`, `int`, `bool`, `address`, `bytes1` 到 `bytes32`。

- **原理**：编译器会尽可能地将这些变量放在栈上。对栈的操作（`PUSH`, `POP`, `DUP` 等）是 EVM 中最基础、最快的指令，因此 Gas 成本极低。

- **示例**:

  Solidity

  ```
  function calculate(uint256 a, uint256 b) public pure returns (uint256) {
      // a, b, result, doubleResult 全部都是栈变量
      uint256 result = a + b;
      uint256 doubleResult = result * 2;
      return doubleResult;
  }
  ```

  这个函数的所有操作都像是在木匠的“双手”中完成，效率极高。



### 2. 内存变量 (Memory Variables) - 成本居中

- **是什么**：在函数中声明的**复杂引用类型**变量，如 `string`, `bytes`, 结构体 `struct`，以及动态数组 `uint[]`。

- **原理**：这些变量体积较大且长度可变，无法直接放在栈上，必须存储在内存（“工作台”）中。操作内存需要 `MLOAD` 和 `MSTORE` 指令，它们的成本比栈操作要高。此外，扩展内存本身也需要支付 Gas，成本会随着内存的增大而增加。

- **示例**:

  Solidity

  ```
  function processData(uint256[] calldata rawData) public pure {
      // 在内存中创建了一个新数组，这是一个相对昂贵的操作
      uint256[] memory processedData = new uint256[](rawData.length);
      for (uint i = 0; i < rawData.length; i++) {
          processedData[i] = rawData[i] * 2; // MSTORE 操作
      }
  }
  ```

------

### 3. “伪”局部变量：存储指针 (Storage Pointers) - 常见的 Gas 陷阱与优化点

这是最容易产生混淆，也是优化潜力最大的地方。

#### 错误的常见做法：将存储变量复制到内存

```
// 这是一个状态变量，存放在“永久仓库”
uint256[] public stateArray;

function sumArray() public view returns (uint256) {
    // !! 极其昂贵的操作 !!
    // 将整个仓库里的 stateArray 数组，完整地复制一份到“工作台”上
    uint256[] memory localArray = stateArray; 
    
    uint256 total = 0;
    for (uint i = 0; i < localArray.length; i++) {
        total += localArray[i];
    }
    return total;
}
```

这行 `uint256[] memory localArray = stateArray;` 会触发一个从 `STORAGE` 到 `MEMORY` 的完整拷贝，如果数组很大，会消耗巨量的 Gas。

#### 正确的优化做法：使用存储指针

```
uint256[] public stateArray;

function sumArrayOptimized() public view returns (uint256) {
    // !! 极其便宜的操作 !!
    // localPointer 只是一个指向仓库里 stateArray 的“快捷方式”或“指针”
    uint256[] storage localPointer = stateArray; 
    
    uint256 total = 0;
    for (uint i = 0; i < localPointer.length; i++) {
        total += localPointer[i]; // 每次循环仍然是从 STORAGE 读取，但避免了大规模拷贝
    }
    return total;
}
```

这里的 `localPointer` 不是一个**副本**，而是一个指向原始仓库货架的**指针**。它本身只占用一个栈空间，非常便宜。

好的，我们来深入探讨局部变量（Local Variables）影响 Gas 的原理。这是一个非常核心的优化点。当前时间是2025年9月15日，星期一，凌晨2:51，地点在美国。

**核心原理在于：局部变量存储的位置不同，其读写成本也天差地别。**

在函数执行期间，EVM（以太坊虚拟机）为局部变量提供了三个“工作区”：

1. **栈 (Stack)**：最快、最便宜。
2. **内存 (Memory)**：速度和成本居中。
3. **存储 (Storage)**：最慢、最昂贵。

让我们用一个**木匠的工作坊**来比喻这三个区域：

- **栈 (Stack)**: 木匠的**双手**或**腰间的工具袋**。拿取和放置工具（数据）几乎不花时间和力气，但空间非常有限，只能放几件小工具（`uint`, `address`, `bool` 等）。
- **内存 (Memory)**: 木匠的**主工作台**。比工具袋大得多，可以摆放复杂的零件（`struct`, 数组等）进行组装。每次工作（交易）开始时，工作台都是干净的；工作结束后，上面的所有东西都会被清空。使用工作台比直接在手上操作要费力一些。
- **存储 (Storage)**: 车间旁边的**永久仓库**。这里存放着所有最终成品和原材料（合约的状态变量）。从仓库里取东西或把东西放回仓库（`SLOAD`/`SSTORE`）是最费时费力的操作。

------



### 1. 栈变量 (Stack Variables) - 成本最低



- **是什么**：在函数中声明的**简单值类型**变量，如 `uint`, `int`, `bool`, `address`, `bytes1` 到 `bytes32`。

- **原理**：编译器会尽可能地将这些变量放在栈上。对栈的操作（`PUSH`, `POP`, `DUP` 等）是 EVM 中最基础、最快的指令，因此 Gas 成本极低。

- **示例**:

  Solidity

  ```
  function calculate(uint256 a, uint256 b) public pure returns (uint256) {
      // a, b, result, doubleResult 全部都是栈变量
      uint256 result = a + b;
      uint256 doubleResult = result * 2;
      return doubleResult;
  }
  ```

  这个函数的所有操作都像是在木匠的“双手”中完成，效率极高。

------



### 2. 内存变量 (Memory Variables) - 成本居中



- **是什么**：在函数中声明的**复杂引用类型**变量，如 `string`, `bytes`, 结构体 `struct`，以及动态数组 `uint[]`。

- **原理**：这些变量体积较大且长度可变，无法直接放在栈上，必须存储在内存（“工作台”）中。操作内存需要 `MLOAD` 和 `MSTORE` 指令，它们的成本比栈操作要高。此外，扩展内存本身也需要支付 Gas，成本会随着内存的增大而增加。

- **示例**:

  Solidity

  ```
  function processData(uint256[] calldata rawData) public pure {
      // 在内存中创建了一个新数组，这是一个相对昂贵的操作
      uint256[] memory processedData = new uint256[](rawData.length);
      for (uint i = 0; i < rawData.length; i++) {
          processedData[i] = rawData[i] * 2; // MSTORE 操作
      }
  }
  ```

------



### 3. “伪”局部变量：存储指针 (Storage Pointers) - 常见的 Gas 陷阱与优化点



这是最容易产生混淆，也是优化潜力最大的地方。



#### 错误的常见做法：将存储变量复制到内存



Solidity

```
// 这是一个状态变量，存放在“永久仓库”
uint256[] public stateArray;

function sumArray() public view returns (uint256) {
    // !! 极其昂贵的操作 !!
    // 将整个仓库里的 stateArray 数组，完整地复制一份到“工作台”上
    uint256[] memory localArray = stateArray; 
    
    uint256 total = 0;
    for (uint i = 0; i < localArray.length; i++) {
        total += localArray[i];
    }
    return total;
}
```

这行 `uint256[] memory localArray = stateArray;` 会触发一个从 `STORAGE` 到 `MEMORY` 的完整拷贝，如果数组很大，会消耗巨量的 Gas。



#### 正确的优化做法：使用存储指针



Solidity

```
uint256[] public stateArray;

function sumArrayOptimized() public view returns (uint256) {
    // !! 极其便宜的操作 !!
    // localPointer 只是一个指向仓库里 stateArray 的“快捷方式”或“指针”
    uint256[] storage localPointer = stateArray; 
    
    uint256 total = 0;
    for (uint i = 0; i < localPointer.length; i++) {
        total += localPointer[i]; // 每次循环仍然是从 STORAGE 读取，但避免了大规模拷贝
    }
    return total;
}
```

这里的 `localPointer` 不是一个**副本**，而是一个指向原始仓库货架的**指针**。它本身只占用一个栈空间，非常便宜。



### 总结与优化原则

| 变量位置                  | Gas 成本 | 类比          |
| ------------------------- | -------- | ------------- |
| **栈 (Stack) 栈（堆栈）** | **极低** | 双手 / 工具袋 |
| **内存 (Memory)**         | **中等** | 工作台        |
| **存储 (Storage)**        | **极高** | 永久仓库      |

Export to Sheets 导出至表格

**基于此原理，优化局部变量 Gas 的核心原则是：**

1. **缓存状态变量到栈**：如果一个函数需要**多次读取同一个状态变量**，最好的方法是在函数开头把它读一次，存到一个**栈变量**中，然后在函数内部一直使用这个栈变量。这用一次昂贵的 `SLOAD`（从仓库取货）代替了多次。

   Solidity

   ```
   uint256 public myValue;
   
   function doSomethingRepeatedly() public {
       // 将仓库里的 myValue 取一次，放到“手上”（栈）
       uint256 localValue = myValue; 
   
       // 接下来所有计算都用手上的 localValue，非常快
       doCalc1(localValue);
       doCalc2(localValue);
   }
   ```

2. **使用 `storage` 指针操作状态数组/结构体**：如上所述，当你需要处理一个状态变量中的数组或结构体时，应始终在函数内部创建一个指向它的 `storage` 指针，而不是把它完整地复制到 `memory` 中。

3. **优先使用 `calldata`**：对于 `external` 函数的复杂类型参数，`calldata` 是最便宜的位置，因为它避免了任何内存拷贝。

## **3. 使用固定大小的字节数组而不是字符串或 bytes[]**

如果您处理的字符串最多可以限制为 32 个字符，请使用 `bytes[32]` 而不是动态 `bytes` 数组或 `string` 。

Before: 前：

```solidity
string a;
function add(string str) {
    a = str;
}
```

After: 后：

```solidity
bytes32 a;
function add(bytes32 str) public {
    a = str;
}
```

`bytes32` 之所以便宜，是因为它在设计上完美契合了 EVM 的 32 字节架构。EVM 可以像处理一个简单的数字一样，用最少的指令来操作它。

`string` 之所以昂贵，是因为它的**动态性**。为了处理不确定的长度，EVM 必须引入一套复杂的“指针 + 长度 + 数据”的存储和管理机制，这在每一步都会产生额外的 Gas 开销。

bytes这些都是引用数据类型的，他们比较复杂，又得要指针，又得要开辟空间，而且不确定长度，是动态的

### 技术层面的详细解释

| 操作 (Operation) 操作（操作） | `bytes32` (登机箱)                                         | `string` (托运行李)                                          | 为什么 `bytes32` 更便宜？                                    |
| ----------------------------- | ---------------------------------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| **写入存储 (SSTORE)**         | **1 次** `SSTORE` 操作。                                   | **1 到多次** `SSTORE` 操作 (通常是多次)。                    | `SSTORE` 是 EVM 中最昂贵的操作之一。对于一个长字符串，合约不仅要在主存储槽记录其长度，还要在另外的位置存储其实际内容，这会产生多次 `SSTORE` 调用，成本剧增。 |
| **作为函数参数传递**          | 直接在 `calldata` 中传递，占用固定的 32 字节。             | 需要进行复杂的 ABI 编码，包含位置指针、长度和实际数据，导致 `calldata` 体积更大。 | 交易的固定成本（intrinsic gas）与 `calldata` 的大小正相关。`calldata` 越大，基础 Gas 费就越高。 |
| **在函数内部使用**            | 可以直接在**栈 (Stack)** 上进行操作，这是 EVM 最快的区域。 | 必须在**内存 (Memory)** 中进行分配和操作。                   | 内存操作 (`MLOAD`, `MSTORE`) 比栈操作昂贵，并且在内存中创建动态数组还需要额外的 Gas 成本。 |

## **4. 使用不可变和常量**

如果要在构造时分配永久值，请使用 immutable 。如果已经知道永久值，请使用常量。两者都直接嵌入字节码，从而节省 `SLOAD` 。

```
contract MyContract {
    uint256 constant y = 10;
    uint256 immutable x;

    constructor() {
        x = 5;
    } 
 }
```

### 原理一：昂贵的“仓库” —— 合约存储 (Storage)



你可以把合约的**存储 (Storage)** 想象成一个**永久性的、位于区块链上的大型仓库**。

- **普通的状态变量** (例如 `uint256 myVar;`) 就存放在这个仓库的货架上。
- 当一个函数需要读取这个变量的值时，EVM 必须执行一个叫做 **`SLOAD`** 的操作码 (Opcode)。
- `SLOAD` 的意思是 “Storage Load”（存储加载）。你可以把它想象成 EVM 派一个小机器人跑到遥远的仓库，找到对应的货架，读取上面的数据，然后再跑回来。
- 这个过程需要与区块链的“硬盘”（世界状态树）进行交互，因此 **`SLOAD` 是 EVM 中最昂贵的操作之一**，通常会消耗数千 Gas。

------



### 原理二：廉价的“蓝图” —— 合约字节码 (Bytecode)

现在，我们来看看 `constant` 和 `immutable` 是如何巧妙地避开这个昂贵仓库的。

`constant` 和 `immutable` 变量的值**不会被存放在合约的存储（仓库）中**。相反，它们的值被直接**嵌入（embed）**或**硬编码（hardcode）**到了合约部署后的**字节码（Bytecode）**本身。

**我们继续用比喻来理解：**

- **读取普通变量**: 机器人的指令是：“去仓库的 #5 号货架，看看上面写着什么数字，然后回来告诉我。” (**执行 `SLOAD`**)
- **读取 `constant` 或 `immutable` 变量**: 机器人的指令是：“你需要用的数字就是 **10**，直接用就行了，**根本不用去仓库**。” (**执行 `PUSH`**)

当 EVM 需要使用 `constant` 或 `immutable` 变量的值时，它不需要执行昂贵的 `SLOAD`，而是执行一个极其廉价的 **`PUSH`** 操作码。`PUSH` 只是简单地将一个值推到栈上，消耗的 Gas 微乎其微（通常只有 3 Gas）。



### `constant` 和 `immutable` 的细微差别

它们实现这个“硬编码”的时机略有不同，这也决定了它们的适用场景：

#### `uint256 constant y = 10;`

- **赋值时机**: **编译时 (Compile Time)**。
- **工作流程**: 在你点击“编译”按钮的那一刻，Solidity 编译器会扫描你的所有代码，找到所有使用 `y` 的地方，然后**直接用数字 `10` 把它替换掉**。最终生成的字节码里甚至可能都没有 `y` 这个名字了，只有数字 `10`。
- **适用场景**: 用于那些在写代码时就已经确定的、永恒不变的值，比如最大供应量 `MAX_SUPPLY`、一个数学常数等。

#### `uint256 immutable x;` 和 `constructor() { x = 5; }`

- **赋值时机**: **部署时 (Deployment Time)**。
- **工作流程**:
  1. 在**编译时**，编译器看到 `immutable x`，它会在字节码中为 `x` 预留一个“占位符”。
  2. 当你**部署**合约时，`constructor` 函数会执行，`x` 被赋值为 `5`。
  3. 在部署过程的最后一步，部署代码会把**最终的运行时字节码**拿过来，找到所有为 `x` 预留的“占位符”，然后**用数字 `5` 把它们全部替换掉**。
  4. 最终被永久记录在区块链上的合约字节码，其内容已经包含了值 `5`。
- **适用场景**: 用于那些在部署时才能确定、但之后就永远不变的值。最常见的例子就是一个合约需要关联的另一个合约的地址（比如 `tokenAddress`），或者是合约的 `owner`。

### 总结

`constant` 和 `immutable` 节省 Gas 的原理是：

**通过在编译时或部署时将变量的值直接硬编码到合约的字节码中，从而在运行时用极其廉价的 `PUSH` 操作，替代了极其昂贵的 `SLOAD`（访问存储）操作。**

## **5. 使用 unchecked**

在确保不会溢出或下溢的情况下，使用未经检查的算术运算，从而节省从 solidity v0.8.0 添加的检查的 gas 成本。

在下面的例子中，变量 `i` 不会溢出，因为条件是 `i < length` ，其中 `length` 定义为 `uint256` 。 `i` 可以达到的最大值是 `max(uint)-1` 。因此，在 `unchecked` 区块内增加 `i` 是安全的，并且消耗更少的 gas。

```solidity
function loop(uint256 length) public {
	for (uint256 i = 0; i < length; ) {
	    // do something
	    unchecked {
	        i++;
	    }
	}
}
```

### `unchecked` 节省 Gas 的原理

1. **Solidity 0.8.x 的默认安全机制**：

   - 从 Solidity 0.8 版本开始，为了安全，编译器会**自动**为所有的算术运算（`+`, `-`, `*`, `++` 等）添加**溢出检查代码**。
   - 比如对于 `i++`，编译器生成的底层字节码大致是这样的：
     1. 计算 `i + 1` 的结果。
     2. **检查**这个结果是否比原来的 `i` 小（如果变小了，就说明发生了上溢）。
     3. 如果检查发现上溢，就立即 `revert` 交易。
     4. 如果没问题，才将新值赋给 `i`。
   - 这个额外的“检查”步骤（第 2 和第 3 步）需要执行额外的 EVM 操作码，因此会消耗 Gas。

2. **`unchecked` 块的作用：开发者的“安全承诺”**：

   - 当你把代码放进 `unchecked` 块时，你其实是在跟编译器立下一个“军令状”：

   > “我（开发者）已经通过代码逻辑，100% 保证了这个区块里的数学运算绝对不会发生上溢或下溢。所以，请你（编译器）相信我，**不必为我添加那些额外的安全检查字节码**。”

3. **结果**：

   - 编译器听从你的指令，不再生成用于检查溢出的操作码。
   - 最终部署到链上的字节码变得更少、更精简。
   - 在运行时，由于需要执行的指令更少，这笔交易消耗的 Gas也就更少了。

## **6. 使用 calldata 代替内存作为函数参数**

通常，直接从 calldata 加载变量比将其复制到内存更便宜。仅当变量需要修改时才使用内存。

Before: 前：

```solidity
function loop(uint[] memory arr) external pure returns (uint sum) {
    for (uint i = 0; i < arr.length; i++) {
        sum += arr[i];
    }
}
```

After: 后：

```solidity
function loop(uint[] calldata arr) external pure returns (uint sum) {
    for (uint i = 0; i < arr.length; i++) {
        sum += arr[i];
    }
}
```

**核心原理在于：`calldata` 是一种只读的、临时的“数据区”，它避免了昂贵的数据拷贝操作。**

为了让你彻底理解，我们用一个非常贴切的比喻：**“看原件 vs. 复印后再看”**。calldata就类似于原件，只可以读不可以改，复印的话，就到了memory中了，储存到了内存中了，可以进行修改

可以这样理解，当你使用calldata进行可读时，他是从外部获取的，是一个储存在一个临时区域，不需要消耗太多的gas，相比于memory是处于内存中，这个calldata是能够节省很多gas的。

## **7. 使用自定义错误来节省部署和运行时成本**

您可以使用自定义错误信息，而不是使用字符串（例如 `require(msg.sender == owner, “unauthorized”)` ）来减少部署和运行时的 Gas 成本。此外，它们非常方便，因为您可以轻松地将动态信息传递给它们。

Before: 前：

```solidity
function add(uint256 _amount) public {
    require(msg.sender == owner, "unauthorized");

    total += _amount;
}
```

After: 后：

```solidity
error Unauthorized(address caller);

function add(uint256 _amount) public {
    if (msg.sender != owner)
        revert Unauthorized(msg.sender);

    total += _amount;
}
```

## **8. 重构修饰符以调用本地函数，而不是直接在修饰符中编写代码，从而节省字节码大小并降低部署成本**

修饰符代码会在所有使用到它的实例中被复制，这会增加字节码的大小。通过对内部函数进行折射，可以显著减少字节码的大小，但代价是执行一次跳转。仅当字节码大小受限时才考虑这样做。

Before: 前：

```solidity
modifier onlyOwner() {
		require(owner() == msg.sender, "Ownable: caller is not the owner");
		_;
}
```

After: 后：

```solidity
modifier onlyOwner() {
		_checkOwner();
		_;
}

function _checkOwner() internal view virtual {
    require(owner() == msg.sender, "Ownable: caller is not the owner");
}
```

### 核心原理：“复制粘贴” vs. “函数跳转”

为了理解这个原理，你必须知道编译器是如何处理 `modifier` 和 `internal function` 的。

#### 1. `modifier` 的工作方式 (复制粘贴)

你可以把 `modifier` 想象成代码的**“复制粘贴”**功能。

- 假设你有一个很长的“用户权限检查”段落（`modifier` 里的代码）。
- 如果你在 10 个不同的函数上都使用了 `onlyOwner` 修饰符。
- 那么，在编译时，Solidity 编译器会把这段“用户权限检查”的**代码完整地复制 10 遍**，分别“粘贴”到那 10 个函数的字节码里。

**结果**:

- **优点**: 在**运行时**，执行这 10 个函数中的任何一个，代码都是线性执行的，不需要额外的跳转，所以单次运行的 Gas 成本会**非常非常低**。
- **缺点**: 合约最终的**字节码体积会变得很大**（因为同一段逻辑被复制了 10 遍）。合约的体积越大，**部署它所需要支付的 Gas 费就越高**。

#### 2. `internal function` 的工作方式 (函数跳转)

现在，你把这段“用户权限检查”的段落写成一个**独立的内部函数 `_checkOwner`**。

- 这个函数在合约的字节码里只存在**一份**。
- 当 10 个函数需要进行权限检查时，它们不再复制粘贴 `require` 的逻辑，而是各自执行一个**“跳转 (JUMP)”**指令，跳到 `_checkOwner` 函数的位置，执行完后再跳回来。

**结果**:

- **优点**: 因为检查逻辑只存在一份，所以合约最终的**字节码体积会小得多**，从而**显著降低了部署成本**。
- **缺点**: 在**运行时**，每次调用都需要执行一次 `JUMP` 操作。`JUMP` 操作本身会消耗一小部分 Gas。因此，单次运行的 Gas 成本会比“复制粘贴”模式**略高一点点**。

### 总结与实际使用场景

这是一个典型的**空间换时间**的权衡，但在智能合约的世界里，我们换的是**部署成本 vs. 运行时成本**。

| 方法                           | 部署成本 (合约体积)     | 运行时成本 (单次调用 Gas) |
| ------------------------------ | ----------------------- | ------------------------- |
| **直接写在 `modifier` 里**     | **高** (代码被多次复制) | **最低** (线性执行)       |
| **重构为 `internal function`** | **低** (代码只有一份)   | **略高** (有 JUMP 的开销) |

#### 那么，什么时候应该使用这个技巧呢？

**规则很简单**：当你的**修饰符逻辑很复杂**并且/或者**被大量函数复用**时，这个技巧就非常有价值。

- **推荐使用场景**:
  - 你的 `modifier` 里包含了多个 `require` 语句、复杂的计算逻辑，或者读取了多个状态变量。
  - 这个复杂的 `modifier` 被 5个、10个甚至更多的函数所使用。
  - 在这种情况下，通过重构为 `internal` 函数，你**节省下来的高昂部署费用**，将远远超过每次调用时多付出的那一点点 `JUMP` 的 Gas 成本。
- **不推荐使用场景**:
  - 对于像 `onlyOwner` 这样**极其简单**（只有一行 `require`）且可能只被两三个函数使用的 `modifier`。
  - 在这种情况下，直接写在 `modifier` 内部通常更清晰，并且节省的部署 Gas 也微乎其微，反而增加了运行时的成本。

## **9. 使用索引事件，因为与非索引事件相比，它们的成本更低**

对 uint、bool 和 address 等值类型使用 `indexed` 关键字可以节省 gas 成本，如下例所示。然而，这仅适用于值类型，而对字节和字符串进行索引比未使用索引的版本更昂贵。

Before: 前：

```solidity
event Withdraw(uint256, address);

function withdraw(uint256 amount) public {
    emit Withdraw(amount, msg.sender);
}
```

After: 后：

```solidity
event Withdraw(uint256 indexed, address indexed);

function withdraw(uint256 amount) public {
    emit Withdraw(amount, msg.sender);
}
```

### 核心原理：事件日志的两个“存放区”



首先，你必须理解当一个事件被 `emit` 时，它的数据被存放在了两个完全不同的地方：

1. **日志数据区 (Log Data Section)**：这是一个成本**低廉**、只能追加、**不可搜索**的数据区域。你可以把它想象成一本书的**正文内容**。
2. **日志主题区 (Log Topics Section)**：这是一个成本**较高**、但**可以被高效搜索**的索引区域。你可以把它想象成一本书的**目录**或**索引页**。

`indexed` 关键字的作用，就是告诉 EVM：“**请把这个参数放到可搜索的‘索引页’（Topics）上，而不是放到‘正文’（Data）里。**”

------

### 第一问：为什么对 `uint`, `address` 等类型使用 `indexed` “成本更低”？

你截图中的这句话“与非索引事件相比，它们的成本更低”其实**有一点点误导性**，需要更精确地解读。

- **从单次交易的 Gas 成本来看**: 将一个 `uint256` 或 `address` (它们都是 32 字节) 标记为 `indexed`，并不会显著降低**交易本身**的 Gas 消耗。实际上，写入 Topics 的成本甚至可能比写入 Data 区域略高一点点。
- **真正的“成本更低”指的是链下查询的成本**:
  - **不使用 `indexed`**: 如果 `address` 没有被索引，那么一个 DApp 前端或 Etherscan 想要查找“所有发送给 Alice 的 `Transfer` 事件”时，它必须下载**所有区块**的**所有** `Transfer` 事件的“正文内容”，然后一个一个地去检查接收方是不是 Alice。这是一个极其缓慢和昂贵的操作。
  - **使用 `indexed`**: 如果 `address` 被索引了，DApp 就可以直接向以太坊节点发出一个高效的查询：“请直接把‘索引页’上，接收方是 Alice 的所有 `Transfer` 事件都给我。” 节点可以利用其内部的索引数据库，在瞬间返回结果。

**所以，原理是**： 对于 `uint`、`address` 等值类型，你支付了**几乎相同（甚至略高）的链上 Gas 成本**，却换来了**极其高效的链下可搜索性**。这种可搜索性为整个生态系统（浏览器、钱包、分析工具）节省了巨大的计算资源和时间成本。从这个角度看，它的综合“成本”确实是更低的。

------

### 第二问：为什么对 `string` 或 `bytes` 使用 `indexed` 会更昂贵？

这个问题触及了 `Topics` 区域的一个**核心限制**：**Topics 只能存放固定为 32 字节长度的数据**。

`string` 和动态 `bytes` 数组的长度是可变的，它们可能很短，也可能非常长，无法直接塞进一个 32 字节的“索引卡片”里。

那么，当你强制要索引一个 `string` 时，EVM 会怎么做呢？

**EVM 的解决方案是：不存储字符串本身，而是存储它的哈希值！**

1. 当 `emit` 一个事件，并且其中一个 `string` 参数被标记为 `indexed` 时，EVM 会先对这个字符串的内容执行一次 **`keccak256` 哈希运算**。
2. `keccak256` 的输出结果永远是一个 32 字节的哈希值。
3. EVM 将这个 **32 字节的哈希值**存放到 `Topics`（索引页）中。
4. （通常）字符串的原文依然会被存放在 `Data`（正文）区域。

**昂贵的原因就在于**：这个额外的 **`keccak256` 哈希运算**本身是一个计算密集型操作，需要消耗**大量额外的 Gas**。

**还有一个缺点**：链下的应用只能根据这个字符串的**哈希值**来搜索，而无法直接根据字符串的内容来搜索。这使得它的实用性大大降低。

------

### 总结与最佳实践

| 参数类型                        | 是否 `indexed`？ | 存放在哪里？                          | 链上 Gas 成本               | 是否可被高效搜索？        |
| ------------------------------- | ---------------- | ------------------------------------- | --------------------------- | ------------------------- |
| `uint`, `address`, `bytes32` 等 | 否               | 日志数据区 (Data)                     | 基础成本                    | 否 (极慢)                 |
| `uint`, `address`, `bytes32` 等 | **是**           | **日志主题区 (Topics)**               | 约等于基础成本              | ✅ **是 (高效)**           |
| `string`, `bytes`, `struct` 等  | 否               | 日志数据区 (Data)                     | 基础成本                    | 否                        |
| `string`, `bytes`, `struct` 等  | **是**           | **其哈希值**存放在**主题区 (Topics)** | **高得多** (因为有哈希计算) | ✅ **是 (但只能按哈希搜)** |

Export to Sheets 导出至表格

**给你的开发建议 (最佳实践)**：

- **应该索引 (DO use `indexed`)**: 那些你希望能够快速筛选和查找的关键参数。每个事件最多可以有 3 个 `indexed` 参数。
  - **`address`**: 比如 `Transfer` 事件的 `_from` 和 `_to`。
  - **`uint256`**: 比如 `Transfer` 事件的 `_tokenId`。
  - **`bool` 或 `enum`**: 用来表示状态。
- **不应该索引 (DO NOT use `indexed`)**:
  - **`string`**, **动态 `bytes`**, **`struct`**。这些数据应该作为非索引参数存放在事件的 `Data` 部分，以节省 Gas 并保留原文内容。如果你确实需要按它们的内容搜索，通常会由 The Graph 这样的链下索引服务来处理。

## **10. 处理不同的输入数组时使用 struct 来强制数组长度匹配**

当所有输入数组的长度需要相同时，使用 `struct` 来组合多个输入数组，这样您就不必手动验证它们的长度。

Before: 前：

```solidity
function vote(uint8[] calldata v, bytes[32] calldata r,  bytes[32] calldata s) public {
		require(v.length == r.length == s.length, "not matching");
}
```

After: 后：

```solidity
struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

function vote(Signature[] calldata sig) public {
    // no need for length check
}
```

## **11.提供批量操作的方法**

如果适用，为用户提供批量操作的方法，降低总体天然气成本。

例如：在以下情况下，如果用户想要针对 10 个不同的输入调用 `doSomething()` 。在优化版本中，用户只需支付一次交易的固定 Gas 费用和 `msg.sender check` 的 Gas 费用。

Before: 前：

```solidity
function doSomething(uint256 x, uint256 y, uint256 z) public {
		require msg.sender == registeredUser
		....
}
```

After: 后：

```solidity
function batchDoSomething(uint256[] x, uint256[] y, uint256[] z) public {
		require msg.sender == registeredUser
    loop
			_doSomething(x[i], y[i], z[i])
}
function doSomething(uint256 x, uint256 y, uint256 z) public {
		require msg.sender == registeredUser
		_doSomething(x, y, z);
}
function _doSomething(uint256 x, uint256 y, uint256 z) internal {
		....
}
```

**核心原理在于：将多次交易的固定成本（基础手续费）分摊到单次交易中，从而显著降低总成本。**

为了让你彻底理解，我们用一个非常简单的比喻：**网上购物的运费**。

------



### 比喻：单独下单 vs. 使用购物车

1. **“Before” 的方式 (一次只做一件事)**
   - 这就像你在网上购物，想买 10 件不同的商品，但你**下了 10 个独立的订单**。
   - 每一笔订单，你都需要支付一次**固定的运费**（比如 10 元）。
   - 最后，你总共支付了 **10 次运费**，总计 100 元，外加 10 件商品的价钱。
2. **“After” 的方式 (批量操作)**
   - 这就像你把这 10 件商品**放进同一个购物车，一次性下单**。
   - 你只需要支付**一次运费**（可能因为包裹变重，运费略微上涨到 15 元，但仍然远低于 100 元），外加 10 件商品的价钱。

------



### 技术层面的原理分解



在以太坊中，每一笔交易的 Gas 成本主要由三部分组成：

1. **基础交易费 (Fixed Cost)**：
   - **这是最关键的部分！** 每一笔交易，无论它多么简单，都有一笔**固定的基础 Gas 成本，目前是 21,000 Gas**。这笔费用用于验证交易签名、记录交易等基础操作。
   - 这就是我们比喻中的**“固定运费”**。
2. **Calldata 成本 (Variable Cost)**：
   **Calldata 成本（可变成本）** ：
   - 交易中包含的数据（如函数参数）越多，需要支付的 Gas 越多。
3. **执行成本 (Variable Cost)**：
   **执行成本(Variable Cost)** ：
   - 合约在 EVM 中执行每一个操作码（计算、读写存储等）都需要支付 Gas。
   - 这就是我们比喻中的**“商品本身的价格”**。

现在我们来对比一下两种方式的总成本：

#### “Before” 方式的总成本

如果你想调用 10 次 `DoSomething()`：

- 你需要发送 **10 笔独立的交易**。
- **总成本** = **10 \* (基础交易费)** + 10 * (Calldata 成本) + 10 * (执行成本)
- 仅仅是基础交易费，你就支付了 `10 * 21,000 = 210,000` Gas。

#### “After” 方式的总成本

你只需要调用 1 次 `batchDoSomething()`：

- 你只需要发送 **1 笔交易**。
- **总成本** = **1 \* (基础交易费)** + 1 * (更大的 Calldata 成本) + 10 * (执行成本) + (循环的额外成本)
- 基础交易费，你只支付了 `1 * 21,000 = 21,000` Gas。

**结论**： 通过将 10 次操作打包进一笔交易，你**节省了 9 次昂贵的基础交易费 (21,000 \* 9 = 189,000 Gas)**。虽然批量操作的 Calldata 成本和循环的执行成本会略高一些，但这点增加的成本与节省下来的基础费用相比，简直是九牛一毛。

------

### 实际使用场景

这个模式在实际开发中非常常见且极其有用：

- **NFT 批量铸造 (Batch Minting)**：提供一个 `mint(uint256 quantity)` 函数，让用户可以在一笔交易中铸造多个 NFT，而不是让他们重复调用 10 次 `mint()`。
- **空投 (Airdrops)**：项目方需要向 1000 个地址空投代币。他们会写一个 `airdrop(address[] memory recipients, uint256 amount)` 函数，在一个或几个批量交易中完成，而不是发送 1000 笔独立的交易。
- **DeFi 协议的组合操作**：允许用户在一个交易中完成“从 A 池提取流动性 -> 在 Uniswap 交易 -> 将新代币存入 B 池”等一系列操作。

## **12. 使用 || 和 && 实现短路**

For || and && operators, the second case is not checked if the first case gives the result of the logical expression.  Put the lower-cost expression first so the higher-cost expression may be skipped (short-circuit).
对于 || 和 && 运算符，如果第一种情况给出了逻辑表达式的结果，则不会检查第二种情况。将成本较低的表达式放在最前面，以便可以跳过成本较高的表达式（短路）。

Before: 前：

```solidity
case 1: 100 gas
case 2: 50 gas

if(case1 && case2) revert 
if(case1 || case2) revert 
```

After: 后：

```solidity
if(case2 && case1) revert 
if(case2 || case1) revert 
```

## **Optimize For 优化**

**1. 常见情况 >> 罕见情况**

应该针对常见情况进行优化。针对罕见情况进行优化可能会增加所有其他情况下的 Gas 成本。例如，在转账金额为 0 的情况下跳过余额更新。

由于 0 金额转移并不常见，因此为所有其他情况添加一种条件的成本是没有意义的。

但是，如果情况很常见，例如无限额津贴情况下的转移，就应该这样做。

**2. 运行时成本 >> 部署成本**

Deployment costs are one-time, so always optimize for runtime costs.
部署成本是一次性的，因此始终要优化运行时成本。
If you are constrained by bytecode size, then optimize for deployment cost.
如果您受到字节码大小的限制，则需要优化部署成本。

3. 用户交互>>管理员交互**

As user interaction is most common, prioritize optimizing for it compared to admin actions.
由于用户交互最为常见，因此与管理员操作相比，优先对其进行优化。

