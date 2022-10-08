// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {ERC721} from "solmate/tokens/ERC721.sol";

/// @author philogy <https://github.com/philogy>
contract MockERC721 is ERC721 {
    uint256 public totalSupply;

    constructor() ERC721("De NFTs", "DN") {}

    function tokenURI(uint256) public view override returns (string memory) {
        return "";
    }

    function mint(address _recipient) external returns (uint256 tokenId) {
        _mint(_recipient, (tokenId = totalSupply++));
    }
}
