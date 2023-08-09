// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    
    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}

    function transfer(address receiver, uint256 tokenId) public {
        safeTransferFrom(msg.sender, receiver, tokenId);
    }

    function mint(address receiver, uint256 tokenId) public {
        _safeMint(receiver, tokenId);
    }
    
}