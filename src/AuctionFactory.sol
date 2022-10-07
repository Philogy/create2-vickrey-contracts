// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {IERC721} from "@openzeppelin/token/ERC721/IERC721.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {Auction} from "./Auction.sol";

/// @author philogy <https://github.com/philogy>
contract AuctionFactory is ERC721TokenReceiver {
    event AuctionCreated(
        address indexed auction,
        address indexed collection,
        uint256 indexed tokenId,
        uint256 revealStartBlock
    );

    error DirectAuctionCreate();
    error InvalidERC721ReceiveData();

    address public immutable auctionImplementation;
    mapping(address => bool) public isAuction;

    constructor() {
        auctionImplementation = address(new Auction());
    }

    function internalCreateAuction(address, uint256) external {
        revert DirectAuctionCreate();
    }

    function createAuction(
        address _beneficiary,
        address _collection,
        uint256 _tokenId,
        uint256 _revealStartBlock
    ) external {
        if (msg.sender != address(this)) revert DirectAuctionCreate();
        address newAuction = Clones.clone(auctionImplementation);
        bytes32 tokenCommit;
        assembly {
            mstore(0x00, _collection)
            mstore(0x20, _tokenId)
            tokenCommit := keccak256(0x00, 0x40)
        }
        Auction(payable(newAuction)).initialize(
            _beneficiary,
            _revealStartBlock,
            tokenCommit
        );
        isAuction[newAuction] = true;
        emit AuctionCreated(
            newAuction,
            _collection,
            _tokenId,
            _revealStartBlock
        );
        IERC721(_collection).transferFrom(address(this), newAuction, _tokenId);
    }

    function onERC721Received(
        address,
        address,
        uint256 _tokenId,
        bytes memory _data
    ) external override returns (bytes4) {
        bytes4 dataSelector;
        assembly {
            dataSelector := mload(add(_data, 0x20))
        }
        if (dataSelector != AuctionFactory.internalCreateAuction.selector)
            revert InvalidERC721ReceiveData();

        // remove first 4 bytes from `_data`
        assembly {
            mstore(add(_data, 0x04), sub(mload(_data), 0x04))
            _data := add(_data, 0x04)
        }

        (address beneficiary, uint256 revealStartBlock) = abi.decode(
            _data,
            (address, uint256)
        );

        try
            this.createAuction(
                beneficiary,
                msg.sender,
                _tokenId,
                revealStartBlock
            )
        {} catch (bytes memory errorData) {
            assembly {
                revert(add(errorData, 0x20), mload(errorData))
            }
        }

        return ERC721TokenReceiver.onERC721Received.selector;
    }
}
