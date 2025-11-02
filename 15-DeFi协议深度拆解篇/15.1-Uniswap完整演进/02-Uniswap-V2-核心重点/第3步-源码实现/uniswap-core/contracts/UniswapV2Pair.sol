// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./interfaces/IUniswapV2Pair.sol";

import "./UniswapV2ERC20.sol";
import "./libraries/UQ112x112.sol";
// import './interfaces/IERC20.sol';
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Callee.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract UniswapV2Pair is UniswapV2ERC20, IUniswapV2Pair {
    // 为其使用这个库，使得方便去进行小数位的计算
    using UQ112X112 for uint224;

    //为了方便去计算，会默认其中会有一些流动性。
    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;

    ///函数选择器，为了方便去调用这个函数
    bytes4 private constant SELECTOR =
        bytes4(keccak256(bytes("transfer(address,uint)")));

    address public factory;
    address public token0;
    address public token1;

    /// 这样排列可以去节省gas,刚好满足32字节的槽
    /// 官方账本,
    uint112 private reserve0; // uses single storage slot, accessible via getReserves
    uint112 private reserve1; // uses single storage slot, accessible via getReserves
    uint32 private blockTimestampLast; // uses single storage slot, accessible via getReserves

    /// 两个token在一段时间内累计的价格
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;

    ///k值
    ///kLast 的唯一目的就是为了计算那个 1/6 的手续费。
    // 重置为 0 是一种“清理”操作，它明确了“手续费跟踪”功能当前处于非激活状态。
    uint public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    uint256 unLocked = 1;

    ///防止重入攻击
    modifier lock() {
        require(unLocked == 1, "Pair: LOCKED");
        unLocked = 2;
        _;
        unLocked = 1;
    }
    /// 事件
    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(
        address indexed sender,
        uint amount0,
        uint amount1,
        address indexed to
    );

    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    ///强制同步这个代币
    event Sync(uint112 reserve0, uint112 reserve1);
    ///初始化
    constructor() {
        factory = msg.sender;
    }

    /// @notice 获取这个当前的时间戳以及合约中代币的数量

    function getReserve()
        public 
        view
        returns (
            uint112 _reserve0,
            uint112 _reserve1,
            uint32 _blockTimestampLast
        )
    {
        {
            _reserve0 = reserve0;
            _reserve1 = reserve1;
            _blockTimestampLast = blockTimestampLast;
        }
    }

/// @dev 初始化这个代币
/// @notice 只有这个factory能够去调用
/// @param _token0 代币0的地址
/// @param _token1 代币1的地址
function initialize(address _token0,address _token1)external  {
    
    require(msg.sender==factory, "ERROR :NOT THE FACTORY");
    token0=_token0;
    token1=_token1;

}

/// @dev 铸造lp代币

function mint(address to)external lock returns (uint256 liquidity) {
    
    /// 获取当前pair池中的代币0和代币1的数量，官方账本,

    (uint112 _reserve0,uint112 _reserve1,)=getReserve();

/// 获取这两个代币实际数量，其中还包括了一些没有被记录的代币

uint256 balance0=IERC20(token0).balanceOf(address(this));

uint256 balance1=IERC20(token1).balanceOf(address(this));

/// 获得这些增加的代币的数量，为了方便计算
uint256 amount0=balance0-_reserve0;
uint256 amount1=balance1-_reserve1;
 bool feeOn = _mintFee(_reserve0, _reserve1);
uin256 totalSupply=_totalSupply;
if (totalSupply==0) {
    liquidity=Math.sqrt(amount0*amount1)-MINIMUM_LIQUIDITY;
}else {

liquidity=Math.min(amount0*totalSupply/_reserve0,amount1*totalSupply/_reserve1);
}

require(liquidity>0, "UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED");

_mint(to,liquidity);

_update(balance0, balance1, _reserve0, _reserve1);
if (feeOn) klast=uint256(reserve0*reserve1);
emit  Mint(msg.sender, amount0, amount1);

}


/// 更新函数

function _update()internal  {
    // uint112(-1) 是 uint112 能表示的最大值。
    /// 这行代码确保池子中的“实际余额” (balance0, balance1)
    //  没有大到无法存入 uint112 类型的“官方账本” (reserve) 变量中。如果超过了，交易就失败。
    require(balance0 <= uint112(-1) && balance1 <= uint112(-1), 'UniswapV2: OVERFLOW');

/// blockTimestamp：block.timestamp 是一个 uint256，
// 这里把它压缩成 uint32 (节省 gas)。% 2**32 确保了这一点
     uint32 blockTimestamp = uint32(block.timestamp % 2**32);、
// 计算时间差
 uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired

if (timeElapsed>0&&_reserve0!=0&&_reserve1!=0) {
    ///累计的价格
     price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
}

reserve0 = uint112(balance0);
reserve1 = uint112(balance1);
blockTimestampLast = blockTimestamp;
emit Sync(reserve0, reserve1);

}


function _mintFee(uint112 _reserve0,uint112 _reserve1)internal returns (bool feeon) {
   
/// 对于这个官方来说，他设置了收取手续费的开开关，但是现在还没有打开

/// 手续费接收者的地址
address feeTo=IUniswapV2Factory(factory).feeTo();

feeon=feeTo!=address(0);
uint _kLast = kLast; // gas savings
if (feeon) {
    ///当前k价值
uint256 rootK=Math.sqrt(uint(_reserve0*_reserve1));
/// 之前k价值
uint256 rootLastK=Math.sqrt(uint256(_kLast));

if (rootK>rootLastK) {
    uint256 numerator=_totalSupply*(rootK-rootLastK);
    uint256 denominator=5*rootK+rootLastK;
    uint256 liquidity=numerator/denominator;
if (liquidity > 0) _mint(feeTo, liquidity);

}
}else if (_kLast != 0) {
    ///如果开关没有开，就说明不用去追踪了
            kLast = 0;
        }

}


function burn(address to)external lock returns (uint256 amount0,uint256 amount1) {
   
 (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        address _token0 = token0;                                // gas savings
        address _token1 = token1;                                // gas savings
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        uint liquidity = balanceOf[address(this)];

 bool feeOn = _mintFee(_reserve0, _reserve1);

uint256 totalSupply=_totalSupply;


amount0=liquidity*balance0/totalSupply;

amount1=liquidity*balance1/totalSupply;


 _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);



}

function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock {
        require(amount0Out > 0 || amount1Out > 0, 'UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'UniswapV2: INSUFFICIENT_LIQUIDITY');

        uint balance0;
        uint balance1;
        { // scope for _token{0,1}, avoids stack too deep errors
        address _token0 = token0;
        address _token1 = token1;
        require(to != _token0 && to != _token1, 'UniswapV2: INVALID_TO');
        if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
        if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
        if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'UniswapV2: INSUFFICIENT_INPUT_AMOUNT');
        { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
        uint balance0Adjusted = balance0*1000-amount0In*3;
        uint balance1Adjusted = balance1*1000-amount1In*3;
        require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(1000**2), 'UniswapV2: K');
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }



    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'UniswapV2: TRANSFER_FAILED');
    }

    // force balances to match reserves
    function skim(address to) external lock {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this))-(reserve0));
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this))-(reserve1));
    }


    // force reserves to match balances
    function sync() external lock {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }

    
}
