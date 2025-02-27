// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/SleepToken.sol";

contract SleepTokenTest is Test {
    SleepToken public token;

    function setUp() public {
        token = new SleepToken();
        // Set kontrak ini sendiri sebagai minter untuk keperluan test.
        token.setMinter(address(this));
    }

    function testMint() public {
        uint256 mintAmount = 100 * 1e18;
        token.mint(address(1), mintAmount);
        uint256 balance = token.balanceOf(address(1));
        assertEq(balance, mintAmount, "Minting SleepToken gagal");
    }
}


