// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ECDSA} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/utils/cryptography/ECDSA.sol";

contract ERC20PermitLike {
    // --- ERC20 最小状态 ---
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    string public name = "MyToken";
    string public symbol = "MTK";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    // --- EIP-712 状态 ---
    mapping(address => uint256) public nonces;

    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
    bytes32 private constant _EIP712_DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
    bytes32 private constant _PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    bytes32 private immutable _HASHED_NAME;
    bytes32 private immutable _HASHED_VERSION;
    bytes32 private immutable _CACHED_DOMAIN_SEPARATOR;
    uint256 private immutable _CACHED_CHAIN_ID;
    address private immutable _CACHED_THIS;

    constructor() {
        _HASHED_NAME = keccak256(bytes(name));
        _HASHED_VERSION = keccak256(bytes("1"));

        _CACHED_CHAIN_ID = block.chainid;
        _CACHED_THIS = address(this);

        _CACHED_DOMAIN_SEPARATOR = _buildDomainSeparator(
            _EIP712_DOMAIN_TYPEHASH,
            _HASHED_NAME,
            _HASHED_VERSION
        );

        // 给部署者铸一大堆，方便测试
        totalSupply = 1_000_000 ether;
        balanceOf[msg.sender] = totalSupply;
    }

    function _buildDomainSeparator(
        bytes32 typeHash,
        bytes32 nameHash,
        bytes32 versionHash
    ) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                typeHash,
                nameHash,
                versionHash,
                block.chainid,
                address(this)
            )
        );
    }

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        if (block.chainid == _CACHED_CHAIN_ID && address(this) == _CACHED_THIS) {
            return _CACHED_DOMAIN_SEPARATOR;
        }
        return
            _buildDomainSeparator(
                _EIP712_DOMAIN_TYPEHASH,
                _HASHED_NAME,
                _HASHED_VERSION
            );
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v, bytes32 r, bytes32 s
    ) external {
        require(block.timestamp <= deadline, "permit: expired");

        uint256 ownerNonce = nonces[owner];

        // 1. hashStruct
        bytes32 structHash = keccak256(
            abi.encode(
                _PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                ownerNonce,
                deadline
            )
        );

        // 2. digest = keccak256("\x19\x01", domainSeparator, structHash)
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                structHash
            )
        );

        // 3. 用ECDSA还原签名者
        address signer = ECDSA.recover(digest, v, r, s);
        require(signer == owner, "permit: invalid signature");

        // 4. 授权 + nonce++
        nonces[owner] = ownerNonce + 1;
        allowance[owner][spender] = value;
    }
}
