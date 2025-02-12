// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/mocks/ZkTlsVerifierMock.sol";

contract ZkTlsVerifierTest is Test {
    ZkTlsVerifierMock public verifier;

    function setUp() public {
        verifier = new ZkTlsVerifierMock();
    }

    function testDefaultShouldVerifyTrue() public {
        bool result = verifier.verifyProof("0x1234", bytes32(0), new bytes32[](0));
        assertTrue(result, "Verifier harus mengembalikan true secara default");
    }

    function testSetShouldVerifyFalse() public {
        verifier.setShouldVerify(false);
        bool result = verifier.verifyProof("0x1234", bytes32(0), new bytes32[](0));
        assertFalse(result, "Verifier harus mengembalikan false setelah setShouldVerify(false)");
    }
}
