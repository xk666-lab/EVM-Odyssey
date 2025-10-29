// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract MyReentrancyGuard {

/// 表示状态   
uint256 private   STATUS;

/// 初始化状态
uint256 constant STARAT_STATUS=1;
/// 已完成状态
uint256 constant END_STATUS=2;

constructor() {
     STATUS=STARAT_STATUS;
}
modifier ReentrancyGuard(){
   
    require(STATUS!=END_STATUS,"ReentrancyGuard: reentrant call");
    STATUS=END_STATUS;
    _;

  STATUS=STARAT_STATUS;


}

}