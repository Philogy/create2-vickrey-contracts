// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {BaseTest} from "./utils/BaseTest.sol";
import {AuctionFactory} from "../src/AuctionFactory.sol";

/// @author philogy <https://github.com/philogy>
contract AuctionFactoryTest is BaseTest {
    uint256 internal constant TOTAL_USERS = 5;

    AuctionFactory internal factory;

    function setUp() public {
        initUsers(TOTAL_USERS);
        factory = new AuctionFactory();
    }

    function testSelector() public {
        bytes4 createSelector = AuctionFactory.createAuction.selector;
        emit log_named_bytes32("createSelector", createSelector);
        factory.onERC721Received(
            address(0),
            address(0),
            0,
            abi.encodeCall(
                AuctionFactory.internalCreateAuction,
                (users[2], block.number + 2000)
            )
        );
    }
}
