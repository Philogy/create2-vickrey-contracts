// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {EthereumDecoder} from "./EthereumDecoder.sol";
import {MPT} from "./MPT.sol";
import {RLPEncode} from "../rlp/RLPEncode.sol";

/// @author philogy <https://github.com/philogy>
library VerifyMPTBalance {
    using MPT for MPT.MerkleProof;

    uint256 internal constant _EMPTY_CODE_HASH =
        0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
    uint256 internal constant _EMPTY_STORAGE_HASH =
        0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421;
    uint256 internal constant _EMPTY_NONCE = 0;

    function isValidEmptyAccountBalanceProof(
        EthereumDecoder.BlockHeader memory _header,
        MPT.MerkleProof memory _accountDataProof,
        uint256 _balance
    ) internal pure returns (bool) {
        if (_header.stateRoot != _accountDataProof.expectedRoot) return false;

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
