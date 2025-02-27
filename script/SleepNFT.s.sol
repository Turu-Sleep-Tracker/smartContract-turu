// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {SleepNFT} from "../src/SleepNFT.sol";

contract SleepNFTScript is Script {
    SleepNFT public sleepNFT;

    function setUp() public {}

    function run() public {
        vm.createSelectFork(vm.envString("RPC_URL"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // Gantilah alamat _zkTlsVerifier sesuai kebutuhan
        sleepNFT = new SleepNFT(address(0), 100 ether);
        console.log("SleepNFT deployed at", address(sleepNFT));

        vm.stopBroadcast();
    }
}
