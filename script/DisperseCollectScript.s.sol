// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {DisperseCollect} from "../src/DisperseCollect.sol";

contract DisperseCollectDeploy is Script {
    function run() external {
        // Load the deployer's private key from the environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting the deployment transaction
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the DisperseCollect contract
        new DisperseCollect();

        // // Log the address of the deployed contract
        // console.log("DisperseCollect contract deployed at:", address(disperseCollect));

        // Stop broadcasting
        vm.stopBroadcast();
    }
}
