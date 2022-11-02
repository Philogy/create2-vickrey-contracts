// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {IERC721} from "@openzeppelin/token/ERC721/IERC721.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {Auction} from "./Auction.sol";

/// @author philogy <https://github.com/philogy>
contract AuctionFactory is ERC721TokenReceiver, OwnableRoles {
    event AuctionCreated(
        address indexed auction,
        address indexed collection,
        uint256 indexed tokenId,
        uint256 revealStartBlock
    );

    error NotCallable();
    error InvalidERC721ReceiveData();

    address public immutable auctionImplementation;
    mapping(address => bool) public isAuction;

    constructor(address _auctionImplementation) {
        _initializeOwner(msg.sender);
        auctionImplementation = _auctionImplementation;
    }

    function innerCreateAuction(address, uint256) external {
        revert NotCallable();
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
        if (dataSelector != AuctionFactory.innerCreateAuction.selector)
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

        address newAuction = Clones.clone(auctionImplementation);
        bytes32 tokenCommit;
        assembly {
            mstore(0x00, caller())
            mstore(0x20, _tokenId)
            tokenCommit := keccak256(0x00, 0x40)
        }
        Auction(payable(newAuction)).initialize(
            beneficiary,
            revealStartBlock,
            tokenCommit
        );
        isAuction[newAuction] = true;
        emit AuctionCreated(newAuction, msg.sender, _tokenId, revealStartBlock);
        IERC721(msg.sender).transferFrom(address(this), newAuction, _tokenId);

        return ERC721TokenReceiver.onERC721Received.selector;
    }

    function withdraw() external onlyOwner {
        SafeTransferLib.safeTransferETH(owner(), address(this).balance);
    }

    receive() external payable {}
}
