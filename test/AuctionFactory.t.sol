// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {BaseTest} from "./utils/BaseTest.sol";
import {AuctionFactory} from "../src/AuctionFactory.sol";
import {MockERC721} from "./mocks/MockERC721.sol";

/// @author philogy <https://github.com/philogy>
contract AuctionFactoryTest is BaseTest {
    uint256 internal constant TOTAL_USERS = 5;

    AuctionFactory internal factory;
    MockERC721 internal token;

    function setUp() public {
        initUsers(TOTAL_USERS);
        factory = new AuctionFactory();
        token = new MockERC721();
        vm.roll(block.number + 10000);
    }

    event AuctionCreated(
        address indexed auction,
        address indexed collection,
        uint256 indexed tokenId,
        uint256 revealStartBlock
    );

    function testAuctionCreation() public {
        uint256 tokenId = token.mint(users[0]);

        uint256 revealStartBlock = block.number + 1000;
        vm.prank(users[0]);
        vm.expectEmit(false, true, true, true);
        emit AuctionCreated(
            address(0),
            address(token),
            tokenId,
            revealStartBlock
        );
        token.safeTransferFrom(
            users[0],
            address(factory),
            tokenId,
            abi.encodeCall(
                AuctionFactory.innerCreateAuction,
                (users[0], revealStartBlock)
            )
        );
    }
}
