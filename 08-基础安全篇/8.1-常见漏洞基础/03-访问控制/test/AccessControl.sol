// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
/// 多权限控制
abstract contract AccessControl {
    /// 状态变量
bytes32 public  constant  ADMIN_ROLE=keccak256("ADMIN_ROLE");
bytes32 public  constant  MINTER_ROLE=keccak256("MINTER_ROLE");
bytes32 public  constant  PAUSER_ROLE=keccak256("PAUSER_ROLE");

// 角色-地址-是否拥有；
mapping (bytes32=>mapping (address=>bool)) private _roles;

 // 修饰符：只有拥有特定角色的用户
    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "AccessControl: unauthorized");
        _;
    }

/// 错误定义


error UnauthorizedAccount(address account, bytes32 role);

    error AuthorizedAccount(address account, bytes32 role);
/// @notice 检查是否有权限
/// @notice 如果有权限返回true
function hasRole (bytes32 role,address operator)public view returns (bool) {
return _roles[role][operator];
}
///授予权限
function grantRole(bytes32 role,address operator)public onlyRole(ADMIN_ROLE) {
    require(!hasRole(role,msg.sender),"you have get the access");   
    _roles[role][operator]=true;
}
/// 废除角色
/// @notice 并且只有这个管理员才能去进行销毁 
function revokeRole(bytes32 role,address operator) public onlyRole(ADMIN_ROLE) {
   _revokeRole(role, operator);

}

/// 废除自己的权限
function renounceRole(bytes32 role) public {
    _revokeRole(role, msg.sender);
}

function _revokeRole(bytes32 role,address operator )internal {

    if (hasRole(role, operator)) {
        _roles[role][msg.sender]=false;
    }else {
    revert UnauthorizedAccount(operator, role);
    }

}

function _grantRole(bytes32 role,address operator ) internal {
    if (!hasRole(role, operator)) {
        _roles[role][msg.sender]=true;
    }else {
revert AuthorizedAccount(operator, role);
    }
}



}