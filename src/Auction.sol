// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {IERC721} from "@openzeppelin/token/ERC721/IERC721.sol";

/// @author philogy <https://github.com/philogy>
contract Auction {
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event RevealStarted();

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

    mapping(address => uint256) internal directETHRefunds;

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
        if (block.number < revealStartBlockCached) revert NotYetRevealBlock();
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
        uint256 totalBid = address(this).balance - balBefore;
        uint256 actualBid = min(_bid, _balAtSnapshot);
        uint256 bidderRefund = totalBid - actualBid;

        uint256 topBidCached = topBid;
        if (actualBid > topBidCached) {
            address prevTopBidder = topBidder;
            topBidder = _bidder;
            if (prevTopBidder != address(0) && topBidCached > 0)
                directETHRefunds[prevTopBidder] += topBidCached;
        } else {
            if (actualBid > sndBid) {
                sndBid = actualBid;
            }
            bidderRefund += actualBid;
        }

        if (bidderRefund > 0) directETHRefunds[_bidder] += bidderRefund;
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
        directETHRefunds[topBidder] += topBid - sndBid;
        directETHRefunds[owner] += sndBid;
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
        bytes memory
    ) internal view returns (bool) {
        return true;
    }

    function max(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a > _b ? _a : _b;
    }

    function min(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a < _b ? _a : _b;
    }
}
