// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./ERC721Common.sol";

contract Companion is ERC721Common, ReentrancyGuard, Ownable {
    uint256 public MAX_SUPPLY = 10000;
    uint256 public PRICE = 0.001 ether;
    uint256 public PRESALE_PRICE = 0.001 ether;
    address public withdrawAddress = 0xB4decde4c94Dc19978713D618BDf8fB6d2df6880;
    uint256 public MAX_MINT_PER_WALLET = 5;
    uint256 public MAX_MINT_PER_WALLET_PRESALE = 5;

    bool public publicActive = false;
    bool public presaleActive = false;
    bytes32 public preSaleRoot;

    mapping(address => uint256) public mintsPerWallet;
    mapping(address => uint256) public presaleMintsPerWallet;

    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI
    ) ERC721Common(name, symbol, baseURI) {}

    event Received(address, uint256);

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    // Setters
    function setActive(bool isActive) external onlyOwner {
        publicActive = isActive;
    }

    function setPresaleActive(bool isActive) external onlyOwner {
        presaleActive = isActive;
    }

    function setSupply(uint256 _supply) external onlyOwner {
        MAX_SUPPLY = _supply;
    }

    function setPrice(uint256 _price) external onlyOwner {
        PRICE = _price;
    }

    function setPresalePrice(uint256 _price) external onlyOwner {
        PRESALE_PRICE = _price;
    }

    function setWithdrawAddress(address _address) external onlyOwner {
        withdrawAddress = _address;
    }

    function setMaxMintPerWallet(uint256 _maxMint) external onlyOwner {
        MAX_MINT_PER_WALLET = _maxMint;
    }

    function setMaxMintPerWalletPresale(uint256 _maxMint) external onlyOwner {
        MAX_MINT_PER_WALLET_PRESALE = _maxMint;
    }

    function setPresaleRoot(bytes32 _root) external onlyOwner {
        preSaleRoot = _root;
    }

    // Internal mint for marketing, devs, etc.
    function internalMint(uint256 quantity, address to)
        external
        onlyOwner
        nonReentrant
    {
        require(
            totalSupply() + quantity <= MAX_SUPPLY,
            "Would exceed max supply"
        );
        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(to, totalSupply() + 1);
        }
    }

    // Airdrop
    function airdrop(address[] calldata _addresses) external onlyOwner {
        require(totalSupply() + _addresses.length <= MAX_SUPPLY, "Would exceed max supply");
        for (uint256 i = 0; i < _addresses.length; i++) {
            require(_addresses[i] != address(0), "Cannot send to 0 address");
            _safeMint(_addresses[i], totalSupply() + 1);
        }
    }

    // Public mint
    function publicMint(uint8 quantity, address to)
        external
        payable
        nonReentrant
    {
        require(quantity > 0, "Must mint more than 0 tokens");
        require(publicActive, "Public sale has not begun yet");
        require(totalSupply() + quantity <= MAX_SUPPLY, "Reached max supply");
        require(PRICE * quantity == msg.value, "Incorrect funds");
        require(mintsPerWallet[to] + quantity <= MAX_MINT_PER_WALLET, "Minting exceeds wallet limit");

        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(to, totalSupply() + 1);
        }

        mintsPerWallet[to] += quantity;
    }

    // Presale mint
    function presaleMint(
        uint8 quantity,
        bytes32[] calldata _merkleProof
    ) external payable nonReentrant {
        require(presaleActive, "Presale is not active");
        require(quantity > 0, "Must mint more than 0 tokens");
        require(totalSupply() + quantity <= MAX_SUPPLY, "Purchase would exceed max supply of Tokens");
        require(PRESALE_PRICE * quantity == msg.value, "Incorrect funds");
        require(presaleMintsPerWallet[msg.sender] + quantity <= MAX_MINT_PER_WALLET_PRESALE, "Minting exceeds presale wallet limit");

        // Check proof & mint
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(
            MerkleProof.verify(_merkleProof, preSaleRoot, leaf),
            "Invalid MerkleProof"
        );

        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(msg.sender, totalSupply() + 1);
        }

        presaleMintsPerWallet[msg.sender] += quantity;
    }

    // Withdraw to owner wallet
    function withdraw() external {
        uint256 balance = address(this).balance;
        require(balance > 0, "Insufficient balance in the contract");
        require(
            withdrawAddress !=
                address(0x0000000000000000000000000000000000000000),
            "Withdraw address not set"
        );
        payable(withdrawAddress).transfer(balance);
    }

    function withdrawToContract() external {
        uint256 balance = address(this).balance;
        require(balance > 0, "Insufficient balance in the contract");
        require(
            withdrawAddress !=
                address(0x0000000000000000000000000000000000000000),
            "Withdraw address not set"
        );
        (bool sent, ) = withdrawAddress.call{value: balance}("");
        require(sent, "Failed to send Ether");
    }
}
