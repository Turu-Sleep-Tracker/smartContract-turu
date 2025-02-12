// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IZkTLSVerifier {
    function verifyProof(
        bytes calldata proof,
        bytes32 root,
        bytes32[] calldata publicInputs
    ) external view returns (bool);
}
