// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {BaseTest} from "./utils/BaseTest.sol";

/// @author philogy <https://github.com/philogy>
contract AuctionTest is BaseTest {
    uint256 internal constant TOTAL_USERS = 5;

    function setUp() public {
        initUsers(TOTAL_USERS);
    }

    function testAddr1() public {
        emit log_named_address("users[0]", users[0]);
    }
}
