// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./MyReentrancyGuard.sol";

contract Vault is MyReentrancyGuard {
     /// 状态变量
mapping (address=>uint256) public balances;

/// 事件
event Deposit(address  indexed  depositer,uint256 indexed  value);

event Withdraw(address indexed withdrawer,uint256 indexed value);
//// 自定义错误
error IsZeroValue();

error InsufficientBalance(uint256 balance,uint256 withdrawAmount);

error FailedToSendEther();
function deposit()external  payable  {
    /// 检查用户所存入的金额是否为0
if (msg.value==0) {
    revert IsZeroValue();
}

    /// 记录用户所存入的金额
balances[msg.sender]+=msg.value;
    /// 触发存款事件
emit Deposit(msg.sender, msg.value);
}


/// @notice 提取函数
/// @notice 这是一个有重入攻击的函数，不过可以去进行修复
function withdraw(uint256 amount)external ReentrancyGuard {
    /// 检查
    if (amount==0) {
        revert IsZeroValue();
    }
    /// 将状态变量储存到局部变量，可以减少gas
    uint256 currentBalance=balances[msg.sender];
    /// 判断余额是否足够
if (currentBalance<amount) {
    revert InsufficientBalance(currentBalance,amount);
}
/// 生效


///交互
///进行转账
(bool success,)=msg.sender.call{value:amount}("");
if (!success) {
    revert FailedToSendEther();
}

/// 更新余额

balances[msg.sender]=currentBalance-amount;

///触发Withdraw事件
emit  Withdraw(msg.sender,amount);

}

/// @notice 获取合约的余额

function getBalance()public view  returns (uint256) {
    return  address(this).balance;
}




}