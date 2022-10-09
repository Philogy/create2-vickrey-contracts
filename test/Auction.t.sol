// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {BaseTest} from "./utils/BaseTest.sol";
import {Auction} from "../src/Auction.sol";
import {MockERC721} from "./mocks/MockERC721.sol";
import {Clones} from "@openzeppelin/proxy/Clones.sol";

/// @author philogy <https://github.com/philogy>
contract AuctionTest is BaseTest {
    uint256 internal constant TOTAL_USERS = 5;
    address payable internal baseAuction;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    function setUp() public {
        vm.roll(10000);
        initUsers(TOTAL_USERS);
        baseAuction = payable(new Auction());
    }

    function testCannotReinitialize() public {
        Auction auction = createAuction(
            users[0],
            block.number + 100,
            bytes32(0)
        );
        vm.expectRevert(Auction.AlreadyInitialized.selector);
        auction.initialize(users[0], block.number + 10, bytes32(0));
    }

    function testBidAddress() public {
        uint256 revealStartBlock = block.number + 100;
        Auction auction = createAuction(users[0], revealStartBlock, bytes32(0));
        bytes32 subSalt = genBytes32();
        uint256 bid = 0.05 ether;
        (, address bidAddr) = auction.getBidDepositAddr(users[1], bid, subSalt);
        vm.deal(bidAddr, bid);

        vm.roll(revealStartBlock + 1);
        auction.startReveal();

        address realBidAddr = auction.reveal(users[1], bid, subSalt, bid);
        assertEq(bidAddr, realBidAddr);
    }

    function testTransferOwnership() public {
        uint256 revealStartBlock = block.number + 100;
        Auction auction = createAuction(users[0], revealStartBlock, bytes32(0));
        assertEq(auction.owner(), users[0]);

        vm.expectRevert(Auction.NotOwner.selector);
        vm.prank(users[1]);
        auction.transferOwnership(users[2]);

        vm.expectEmit(true, true, true, true);
        emit OwnershipTransferred(users[0], users[2]);
        vm.prank(users[0]);
        auction.transferOwnership(users[2]);
        assertEq(auction.owner(), users[2]);
    }

    function testSimpleBids(uint256[4] memory bids) public {
        for (uint256 i; i < 4; i++) vm.assume(bids[i] <= 100 ether);

        // create auction
        uint256 revealStartBlock = block.number + 100;
        Auction auction = createAuction(users[4], revealStartBlock, bytes32(0));

        // create and fund bids
        bytes32[4] memory subSalts;
        for (uint256 i; i < 4; i++) {
            subSalts[i] = genBytes32();
            (, address bidAddr) = auction.getBidDepositAddr(
                users[i],
                bids[i],
                subSalts[i]
            );
            vm.deal(bidAddr, bids[i]);
        }

        vm.roll(revealStartBlock + 1);
        auction.startReveal();

        for (uint256 i; i < 4; i++) {
            auction.reveal(users[i], bids[i], subSalts[i], bids[i]);
        }

        // check final results
        uint256 topBidderId = 0;
        for (uint256 i; i < 4; i++) {
            if (bids[i] > bids[topBidderId]) topBidderId = i;
        }
        uint256 secondBidderId = (topBidderId + 1) % 4;
        for (uint256 i; i < 4; i++) {
            if (i == topBidderId) continue;
            if (bids[i] > bids[secondBidderId]) secondBidderId = i;
            assertEq(auction.pendingPulls(users[i]), bids[i], "pending pulls");
        }
        assertEq(auction.topBidder(), users[topBidderId]);
        assertEq(auction.topBid(), bids[topBidderId]);
        assertEq(auction.sndBid(), bids[secondBidderId]);
    }

    function testLateRevealStart() public {
        uint256 revealStartBlock = block.number + 100;
        Auction auction = createAuction(users[0], revealStartBlock, bytes32(0));
    }

    function createAuction(
        address _initialOwner,
        uint256 _revealStartBlock,
        bytes32 _tokenCommit
    ) internal returns (Auction a) {
        a = Auction(payable(Clones.clone(baseAuction)));
        a.initialize(_initialOwner, _revealStartBlock, _tokenCommit);
    }
}
