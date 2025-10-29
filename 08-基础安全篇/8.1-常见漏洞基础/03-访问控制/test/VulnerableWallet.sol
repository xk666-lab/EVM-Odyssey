// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.26;
import "./Owner.sol";
contract VulnerableWallet is Owner {

address private _owner;

constructor()Owner(msg.sender){
    _owner = msg.sender;
}

function withdraw(address payable to, uint256 amount) public onlyOwner {
    require(tx.origin == _owner, "Not owner");
    to.transfer(amount);
}

function deposit() public payable {}

function getBalance() public view returns (uint256) {
    return address(this).balance;
}



}