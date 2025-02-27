// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity ^0.8.9;

contract RandomWalkNFT is ERC721Enumerable, Ownable {

    uint256 public saleTime;
    uint256 public price = 10**15; // Price starts at .001 eth

    // How long to wait until the last minter can withdraw
    uint256 public withdrawalWaitSeconds = 3600 * 24 * 30;

    // Seeds
    mapping(uint256 => bytes32) public seeds;

    mapping(uint256 => string) public tokenNames;

    // Entropy
    bytes32 public entropy;

    address public lastMinter = address(0);
    uint256 public lastMintTime = saleTime;

    string private _baseTokenURI;

    // IPFS link to the Python script that generates images and videos for each NFT based on seed.
    string public tokenGenerationScript = "ipfs://QmWEao2HjCvyHJSbYnWLyZj8HfFardxzuNh7AUk1jgyXTm";

    constructor(string memory baseURI, uint256 _saleTime) ERC721("RandomWalkNFT", "RWLK") {
        saleTime = _saleTime;
        setBaseURI(baseURI);
        entropy = keccak256(abi.encode(
            "A two-dimensional random walk will return to the point where it started, but a three-dimensional one may not.",
            block.timestamp, blockhash(block.number)));
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    // IMPORTANT: Remove this for the final deployment
    function setSaleTime(uint256 newSaleTime) public {
        saleTime = newSaleTime;
    }

    // IMPORTANT: Remove this for the final deployment
    function setWithdrawalWait(uint256 newTime) public {
        withdrawalWaitSeconds = newTime;
    }

    function setTokenName(uint256 tokenId, string memory name) public {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "setTokenName caller is not owner nor approved"
        );
        tokenNames[tokenId] = name;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function getMintPrice() public view returns (uint256) {
        return (price * 10011) / 10000;
    }

    function timeUntilSale() public view returns (uint256) {
        if (saleTime < block.timestamp) return 0;
        return saleTime - block.timestamp;
    }

    function timeUntilWithdrawal() public view returns (uint256) {
        uint256 withdrawalTime = lastMintTime + withdrawalWaitSeconds;
        if (withdrawalTime < block.timestamp) return 0;
        return withdrawalTime - block.timestamp;
    }

    function withdrawalAmount() public view returns (uint256) {
        return address(this).balance / 2;
    }

    /**
     * If there was no mint for withdrawalWaitSeconds, then the last minter can withdraw
     * half of the balance in the smart contract.
     */
    function withdraw() public {
        require(_msgSender() == lastMinter);
        require(timeUntilWithdrawal() == 0);
        lastMinter = address(0);
        // Transfer half of the balance to the last minter.
        (bool success, ) = lastMinter.call{value: withdrawalAmount()}("");
        require(success, "Transfer failed.");
    }

    function mint() public payable {
        uint256 newPrice = getMintPrice();
        require(
            msg.value >= newPrice,
            "The value submitted with this transaction is too low."
        );
        require(
            block.timestamp >= saleTime,
            "The sale is not open yet."
        );
        price = newPrice;
        entropy = keccak256(abi.encode(
            entropy,
            block.timestamp,
            blockhash(block.number),
            _msgSender()));
        uint256 tokenId = totalSupply();
        seeds[tokenId] = entropy;
        _safeMint(_msgSender(), tokenId);

        lastMinter = _msgSender();
        lastMintTime = block.timestamp;

        if (msg.value > newPrice) {
            // Return the extra money to the minter.
            (bool success, ) = _msgSender().call{value: msg.value - newPrice}("");
            require(success, "Transfer failed.");
        }
    }

    // Returns a list of token Ids owned by _owner.
    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 tokenCount = balanceOf(_owner);

        if (tokenCount == 0) {
            // Return an empty array
            return new uint256[](0);
        }

        uint256[] memory result = new uint256[](tokenCount);
        for (uint256 i; i < tokenCount; i++) {
            result[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return result;
    }

    // Returns a list of seeds owned by _owner.
    function seedsOfOwner(address _owner)
        public
        view
        returns (bytes32[] memory)
    {
        uint256 tokenCount = balanceOf(_owner);

        if (tokenCount == 0) {
            // Return an empty array
            return new bytes32[](0);
        }

        bytes32[] memory result = new bytes32[](tokenCount);
        for (uint256 i; i < tokenCount; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(_owner, i);
            result[i] = seeds[tokenId];
        }
        return result;
    }
}
