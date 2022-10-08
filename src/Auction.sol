// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {IERC721} from "@openzeppelin/token/ERC721/IERC721.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Multicallable} from "solady/utils/Multicallable.sol";

/// @author philogy <https://github.com/philogy>
contract Auction is Multicallable {
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event RevealStarted();
    event BidRevealed(
        address indexed topBidder,
        address indexed bidder,
        uint256 topBid,
        uint256 sndBid,
        uint256 bid
    );
    event AsyncSend(
        address indexed account,
        uint256 sendAmount,
        uint256 totalPendingAmount
    );
    event WinClaimed(address indexed winner, uint256 paidBid, uint256 refund);

    error AlreadyInitialized();
    error InvalidRevealStartBlock();
    error InvalidInitialOwner();

    error TransferOwnerToZero();
    error NotOwner();

    error RevealAlreadyStarted();
    error NotYetRevealBlock();
    error NotYetReveal();
    error RevealOver();
    error RevealNotOver();
    error InvalidTokenCommit();

    error InvalidProof();

    uint256 internal constant REVEAL_BLOCKS = 7200; // 24h worth of blocks
    uint256 internal constant BID_EXTRACTOR_CODE = 0x3d3d3d3d47335af1;
    uint256 internal constant BID_EXTRACTOR_CODE_SIZE = 0x8;
    uint256 internal constant BID_EXTRACTOR_CODE_OFFSET = 0x18;

    mapping(address => uint256) public pendingPulls;

    address public owner;
    uint96 public revealStartBlock;
    bytes32 public storedBlockHash;

    address public topBidder;
    uint128 public topBid;
    uint128 public sndBid;

    bytes32 public tokenCommit;

    // make core deployment uninitializable
    constructor() {
        owner = address(0x000000000000000000000000000000000000dEaD);
        revealStartBlock = type(uint96).max;
    }

    receive() external payable {}

    function initialize(
        address _initialOwner,
        uint256 _revealStartBlock,
        bytes32 _tokenCommit
    ) external {
        if (owner != address(0)) revert AlreadyInitialized();
        if (_initialOwner == address(0)) revert InvalidInitialOwner();
        if (_revealStartBlock <= block.number) revert InvalidRevealStartBlock();
        owner = _initialOwner;
        revealStartBlock = uint96(_revealStartBlock);
        emit OwnershipTransferred(address(0), _initialOwner);
        tokenCommit = _tokenCommit;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /*
     * @notice Transfers ownership to `_newOwner`.
     * @dev Does not use `onlyOwner` to save gas
     * */
    function transferOwnership(address _newOwner) external {
        if (_newOwner == address(0)) revert TransferOwnerToZero();
        address curOwner = owner;
        if (msg.sender != curOwner) revert NotOwner();
        emit OwnershipTransferred(curOwner, _newOwner);
        owner = _newOwner;
    }

    function startReveal() external {
        if (storedBlockHash != bytes32(0)) revert RevealAlreadyStarted();
        uint256 revealStartBlockCached = revealStartBlock;
        if (block.number <= revealStartBlockCached) revert NotYetRevealBlock();
        storedBlockHash = blockhash(
            max(block.number - 256, revealStartBlockCached)
        );
        // overwrite reveal start block
        revealStartBlock = uint96(block.number);
        emit RevealStarted();
    }

    function reveal(
        address _bidder,
        uint256 _bid,
        bytes32 _subSalt,
        uint256 _balAtSnapshot,
        bytes memory _proof
    ) external returns (address bidAddr) {
        uint256 totalBid;
        {
            if (revealStartBlock + 7200 < block.number) revert RevealOver();
            bytes32 storedBlockHashCached = storedBlockHash;
            if (storedBlockHashCached == bytes32(0)) revert NotYetReveal();
            (bytes32 salt, address depositAddr) = getBidDepositAddr(
                _bidder,
                _bid,
                _subSalt
            );

            if (
                !_verifyProof(
                    storedBlockHashCached,
                    depositAddr,
                    _balAtSnapshot,
                    _proof
                )
            ) revert InvalidProof();

            uint256 balBefore = address(this).balance;
            assembly {
                mstore(0x00, BID_EXTRACTOR_CODE)
                bidAddr := create2(
                    0,
                    BID_EXTRACTOR_CODE_OFFSET,
                    BID_EXTRACTOR_CODE_SIZE,
                    salt
                )
            }
            totalBid = address(this).balance - balBefore;
        }

        uint256 actualBid = min(_bid, _balAtSnapshot);
        uint256 bidderRefund = totalBid - actualBid;

        uint128 topBidCached = topBid;
        uint128 sndBidCached = sndBid;
        address topBidderCached = topBidder;
        if (actualBid > topBidCached) {
            _asyncSend(topBidderCached, topBidCached);
            topBidder = topBidderCached = _bidder;
            sndBid = sndBidCached = uint128(topBidCached);
            topBid = topBidCached = uint128(actualBid);
        } else {
            if (actualBid > sndBid) sndBid = sndBidCached = uint128(actualBid);
            bidderRefund += actualBid;
        }

        _asyncSend(_bidder, bidderRefund);

        emit BidRevealed(
            topBidderCached,
            _bidder,
            topBidCached,
            sndBidCached,
            actualBid
        );
    }

    function claimWin(address _collection, uint256 _tokenId) external {
        if (revealStartBlock + 7200 >= block.number) revert RevealNotOver();
        bytes32 passedTokenCommit;
        assembly {
            mstore(0x00, _collection)
            mstore(0x20, _tokenId)
            passedTokenCommit := keccak256(0x00, 0x40)
        }
        if (passedTokenCommit != tokenCommit) revert InvalidTokenCommit();
        IERC721(_collection).safeTransferFrom(
            address(this),
            topBidder,
            _tokenId
        );
        tokenCommit = bytes32(0);
        address topBidderCached = topBidder;
        uint256 paidBid = sndBid;
        uint256 refund = topBid - paidBid;
        _asyncSend(topBidderCached, refund);
        _asyncSend(owner, paidBid);
        emit WinClaimed(topBidderCached, paidBid, refund);
    }

    function pull(address _addr) external returns (uint256 totalPull) {
        if ((totalPull = pendingPulls[_addr]) > 0) {
            pendingPulls[_addr] = 0;
            SafeTransferLib.safeTransferETH(_addr, totalPull);
        }
    }

    function getBidDepositAddr(
        address _bidder,
        uint256 _bid,
        bytes32 _subSalt
    ) public view returns (bytes32 salt, address depositAddr) {
        assembly {
            mstore(0x00, BID_EXTRACTOR_CODE)
            let bidExtractorInitHash := keccak256(
                BID_EXTRACTOR_CODE_OFFSET,
                BID_EXTRACTOR_CODE_SIZE
            )
            let freeMem := mload(0x40)

            mstore(freeMem, _bidder)
            mstore(add(freeMem, 0x20), _bid)
            mstore(add(freeMem, 0x40), _subSalt)
            salt := keccak256(freeMem, 0x60)

            mstore(add(freeMem, 0x14), address())
            mstore(freeMem, 0xff)
            mstore(add(freeMem, 0x34), salt)
            mstore(add(freeMem, 0x54), bidExtractorInitHash)

            depositAddr := keccak256(add(freeMem, 0x1f), 0x55)
        }
    }

    function _verifyProof(
        bytes32,
        address,
        uint256,
        bytes memory
    ) internal view returns (bool) {
        return true;
    }

    function _asyncSend(address _addr, uint256 _amount) internal {
        if (_amount > 0) {
            if (_addr == address(0)) _addr = owner;
            uint256 totalPending = pendingPulls[_addr] + _amount;
            pendingPulls[_addr] = totalPending;
            emit AsyncSend(_addr, _amount, totalPending);
        }
    }

    function max(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a > _b ? _a : _b;
    }

    function min(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a < _b ? _a : _b;
    }
}
