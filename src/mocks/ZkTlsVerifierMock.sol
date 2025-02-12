// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IZkTLSVerifier.sol";

contract ZkTlsVerifierMock is IZkTLSVerifier {
    bool public shouldVerify;

    constructor() {
        shouldVerify = true;
    }

    function setShouldVerify(bool _shouldVerify) external {
        shouldVerify = _shouldVerify;
    }

    function verifyProof(
        bytes calldata, 
        bytes32, 
        bytes32[] calldata
    ) external view override returns (bool) {
        return shouldVerify;
    }
}
