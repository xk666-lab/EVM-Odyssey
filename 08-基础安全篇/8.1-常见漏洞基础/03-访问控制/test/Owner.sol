// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;


/// Ownable 是最常见的访问控制模式，提供基本的单一所有者权限管理。
/// @notice 这是一个管理的合约，提供所有权权限的管理
/// @notice 继承之后可以获得权限管理，可以废除权限，可以转移权限，可以管理权限
 contract Owner {
    
/// 状态变量
address private  _owner;
/// 事件
event TransferOwner(address indexed previousOwner,address indexed currentOwner);


/// 构造函数
constructor(address owner_) {
    _owner=owner_;
    emit  TransferOwner(address(0), msg.sender);
}

modifier onlyOwner(){
    require(_owner==msg.sender, "you not have owner");

    _;
}

/// 函数

function owner()public view  returns (address)  {
    return _owner;
}

/// @notice 转移权限
function transferOwnership(address _newOwner)external onlyOwner {
    /// 如果转移的地址为非0地址的话，那么类似于销毁权限
    require(_newOwner != address(0), "Ownable: new owner is zero address");
    address previousOwner=_owner;
    _owner=_newOwner;
    emit  TransferOwner(previousOwner, _owner);
    
}

/// @notice 废除权限

function renounceOwnership()public  {
    emit  TransferOwner(_owner, address(0));
    _owner=address(0);
}

}