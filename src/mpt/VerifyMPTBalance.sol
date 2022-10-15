// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {EthereumDecoder} from "./EthereumDecoder.sol";
import {MPT} from "./MPT.sol";
import {RLPEncode} from "../rlp/RLPEncode.sol";

/// @author philogy <https://github.com/philogy>
library VerifyMPTBalance {
    using MPT for MPT.MerkleProof;

    uint256 internal constant _EMPTY_NONCE = 0;
    uint256 internal constant _EMPTY_STORAGE_HASH =
        0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421;
    uint256 internal constant _EMPTY_CODE_HASH =
        0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

    function expandAddrToKey(address _addr)
        internal
        pure
        returns (bytes memory key)
    {
        assembly {
            mstore(0x00, _addr)
            let hashedAddr := keccak256(0x0c, 0x14)

            // alloc bytes
            key := mload(0x40)
            mstore(0x40, add(key, 0x60))

            // store length
            mstore(key, 0x40)

            // add zeros
            let keyOffset := add(key, 0x20)
            // prettier-ignore
            for { let i := 0x40 } i { } {
                i := sub(i, 1) 
                mstore8(add(keyOffset, i), and(hashedAddr, 0xf))
                hashedAddr := shr(4, hashedAddr)
            }
        }
    }

    function isValidEmptyAccountBalanceProof(
        EthereumDecoder.BlockHeader memory _header,
        MPT.MerkleProof memory _accountDataProof,
        uint256 _balance,
        address _addr
    ) internal pure returns (bool) {
        if (_header.stateRoot != _accountDataProof.expectedRoot) return false;
        if (
            keccak256(_accountDataProof.key) !=
            keccak256(expandAddrToKey(_addr))
        ) return false;

        bytes[] memory accountTuple = new bytes[](4);
        accountTuple[0] = RLPEncode.encodeUint(_EMPTY_NONCE);
        accountTuple[1] = RLPEncode.encodeUint(_balance);
        accountTuple[2] = RLPEncode.encodeUint(_EMPTY_STORAGE_HASH);
        accountTuple[3] = RLPEncode.encodeUint(_EMPTY_CODE_HASH);

        if (
            keccak256(RLPEncode.encodeList(accountTuple)) !=
            keccak256(_accountDataProof.expectedValue)
        ) return false;

        return _accountDataProof.verifyTrieProof();
    }
}
