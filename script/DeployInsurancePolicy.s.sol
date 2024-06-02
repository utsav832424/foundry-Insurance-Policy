// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {InsurancePolicy} from "../src/InsurancePolicy.sol";

contract DeployInsurancePolicy is Script {
    function run() external returns (InsurancePolicy) {
        vm.startBroadcast();
        InsurancePolicy insurancePolicy = new InsurancePolicy();
        vm.stopBroadcast();
        return insurancePolicy;
    }
}
