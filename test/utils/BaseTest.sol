// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {Test} from "forge-std/Test.sol";
import {LibString} from "solady/utils/LibString.sol";

/// @author philogy <https://github.com/philogy>
abstract contract BaseTest is Test {
    using LibString for uint256;

    bytes32 private lastRandSeed = keccak256("some start seed");

    address[] internal users;

    function initUsers(uint256 _totalUsers) internal {
        users = new address[](_totalUsers);
        for (uint256 i; i < _totalUsers; i++) {
            users[i] = genAddr();
            vm.label(users[i], string(abi.encodePacked("user", i.toString())));
        }
    }

    function genAddr() internal returns (address) {
        return genAddr("");
    }

    function genAddr(bytes memory _extraEntropy)
        internal
        returns (address newAddr)
    {
        newAddr = address(
            bytes20(
                keccak256(abi.encode(_nextRandSeed(), _extraEntropy, "genAddr"))
            )
        );
    }

    function genBytes32() internal returns (bytes32) {
        return genBytes32("");
    }

    function genBytes32(bytes memory _extraEntropy) internal returns (bytes32) {
        return
            keccak256(abi.encode(_nextRandSeed(), _extraEntropy, "genBytes32"));
    }

    function _nextRandSeed() private returns (bytes32 randSeed) {
        randSeed = lastRandSeed;
        lastRandSeed = keccak256(abi.encode(lastRandSeed));
    }
}
