// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {BaseTest} from "./utils/BaseTest.sol";
import {Auction} from "../src/Auction.sol";
import {MockERC721} from "./mocks/MockERC721.sol";
import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {EthereumDecoder} from "../src/mpt/EthereumDecoder.sol";
import {MPT} from "../src/mpt/MPT.sol";

address public constant auctionFactory = address(0x69);

contract NoVerifyTestAuction is Auction {
    constructor() Auction(auctionFactory) {}

    function _verifyProof(
        EthereumDecoder.BlockHeader memory,
        MPT.MerkleProof memory,
        uint256,
        address,
        bytes32
    ) internal override returns (bool) {
        return true;
    }
}

/// @author philogy <https://github.com/philogy>
contract AuctionTest is BaseTest {
    uint256 internal constant TOTAL_USERS = 5;
    address payable internal baseAuction;

    EthereumDecoder.BlockHeader internal emptyHeader;
    MPT.MerkleProof internal emptyProof;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    function setUp() public {
        vm.roll(10000);
        initUsers(TOTAL_USERS);
        baseAuction = payable(new NoVerifyTestAuction());
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

        address realBidAddr = auction.reveal(
            users[1],
            bid,
            subSalt,
            bid,
            emptyHeader,
            emptyProof
        );
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
            auction.reveal(
                users[i],
                bids[i],
                subSalts[i],
                bids[i],
                emptyHeader,
                emptyProof
            );
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

    function testLateReveal() public {
        // create auction
        uint256 revealStartBlock = block.number + 100;
        Auction auction = createAuction(users[4], revealStartBlock, bytes32(0));

        uint256[] memory bids = new uint256[](5);
        bids[0] = 10e18; // bidder will reveal on time
        bids[1] = 12e18; // bidder will reveal on time
        bids[2] = 11e18; // bidder will not reveal on time
        bids[3] = 17e18; // bidder will not reveal on time
        bids[4] = 7e18; // bidder will not reveal on time

        // create and fund bids
        bytes32[5] memory subSalts;
        for (uint256 i; i < 5; i++) {
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

        // reveal for users[0]
        auction.reveal(
            users[0],
            bids[0],
            subSalts[0],
            bids[0],
            emptyHeader,
            emptyProof
        );

        // reveal for users[1]
        auction.reveal(
            users[1],
            bids[1],
            subSalts[1],
            bids[1],
            emptyHeader,
            emptyProof
        );

        // assert users[1] is top bidder
        assertEq(auction.topBidder(), users[1]);
        assertEq(auction.topBid(), bids[1]);

        // assert users[0] bid is second top bid
        assertEq(auction.sndBid(), bids[0]);

        // roll pass the reveal time, not more bids can be revealed
        vm.roll(revealStartBlock + 7201);

        // late reveal bidders that did not reveal in the correct reveal phase
        // should be slashed
        for (uint256 i; i < 5; i++) {
            auction.lateReveal(users[i], bids[i], subSalts[i]);
        }

        // pull funds
        for (uint256 i; i < 5; i++) {
            auction.pull(users[i]);
        }

        // should get full refund as they did not win the auction
        assertEq(users[0].balance, 10e18);

        // should be 0 since they won the auction
        assertEq(users[1].balance, 0);

        // this person would've affected the auction if they revealed on time
        /// should be get slashed since they revealed late, bid - sndBid
        assertEq(users[2].balance, 10e18);

        // this bidder would have won but they revealed late,
        // should be get slashed significantly
        assertEq(users[3].balance, 10.72e18);

        // this bidder would not have affected auction even if they revealed on time
        // no slashing
        assertEq(users[4].balance, 7e18);

        // assert slashed funds go to factory
        assertEq(address(auctionFactory).balance, 7.28e18);
    }
}
