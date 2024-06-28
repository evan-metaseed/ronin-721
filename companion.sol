// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract Companion is Ownable, ERC721Enumerable, ReentrancyGuard {
    uint256 public MAX_SUPPLY = 10000;
    uint256 public PRICE = 0.001 ether;
    address public withdrawAddress = 0xB4decde4c94Dc19978713D618BDf8fB6d2df6880;
    uint256 public MAX_MINT_PER_WALLET = 5;

    bool public publicActive = false;

    mapping(address => uint256) public mintsPerWallet;

    constructor(string memory name, string memory symbol)
        ERC721(name, symbol) Ownable(){} 

    event Received(address, uint256);

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    //setters
    function setActive(bool isActive) external onlyOwner {
        publicActive = isActive;
    }

    function setSupply(uint256 _supply) external onlyOwner {
        MAX_SUPPLY = _supply;
    }

    function setPrice(uint256 _price) external onlyOwner {
        PRICE = _price;
    }

    function setWithdrawAddress(address _address) external onlyOwner {
        withdrawAddress = _address;
    }

    function setMaxMintPerWallet(uint256 _maxMint) external onlyOwner {
        MAX_MINT_PER_WALLET = _maxMint;
    }

    // Internal for marketing, devs, etc
    function internalMint(uint256 quantity, address to)
        external
        onlyOwner
        nonReentrant
    {
        require(
            totalSupply() + quantity <= MAX_SUPPLY,
            "would exceed max supply"
        );
        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(to, totalSupply() + 1);
        }
    }

    // airdrop
    function airdrop(address[] calldata _addresses) external onlyOwner {
        require(totalSupply() + _addresses.length <= MAX_SUPPLY, "would exceed max supply");
        for (uint256 i = 0; i < _addresses.length; i++) {
            require(_addresses[i] != address(0), "cannot send to 0 address");
            _safeMint(_addresses[i], totalSupply() + 1);
        }
    }

    // metadata URI
    string private _baseTokenURI;

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        return
            string(abi.encodePacked(_baseTokenURI, Strings.toString(_tokenId)));
    }

    // public mint
    function publicMint(uint8 quantity, address to)
        external
        payable
        nonReentrant
    {
        require(quantity > 0, "Must mint more than 0 tokens");
        require(publicActive, "public sale has not begun yet");
        require(totalSupply() + quantity <= MAX_SUPPLY, "reached max supply");
        require(PRICE * quantity == msg.value, "Incorrect funds");
        require(mintsPerWallet[to] + quantity <= MAX_MINT_PER_WALLET, "Minting exceeds wallet limit");

        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(to, totalSupply() + 1);
        }

        mintsPerWallet[to] += quantity;
    }

    // withdraw to owner wallet
    function withdraw() external {
        uint256 balance = address(this).balance;
        require(balance > 0, "Insufficient balance in the contract");
        require(
            withdrawAddress !=
                address(0x0000000000000000000000000000000000000000),
            "withdraw address not set"
        );
        payable(withdrawAddress).transfer(balance);
    }

    function withdrawToContract() external {
        uint256 balance = address(this).balance;
        require(balance > 0, "Insufficient balance in the contract");
        require(
            withdrawAddress !=
                address(0x0000000000000000000000000000000000000000),
            "withdraw address not set"
        );
        (bool sent, ) = withdrawAddress.call{value: balance}("");
        require(sent, "Failed to send Ether");
    }
}
