// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;


interface IVault {
    function deposit()external payable  ;
}

/// @notice 模拟用户存款操作
contract user{
    
IVault immutable vault;
constructor(IVault _vault) {
    vault=_vault;
}

function depositToVault()external payable  {
    vault.deposit{value:msg.value}();
}




    
}