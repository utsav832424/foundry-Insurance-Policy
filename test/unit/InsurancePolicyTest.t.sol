// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DeployInsurancePolicy} from "../../script/DeployInsurancePolicy.s.sol";
import {InsurancePolicy} from "../../src/InsurancePolicy.sol";

contract InsurancePolicyTest is Test {
    event PolicyCreated(address indexed policyHolder, uint256 indexed amount);
    event PayPolicy(address indexed policyHolder, uint256 indexed premiumAmount);
    event ClaimSubmitted(address indexed policyHolder, uint256 indexed claimAmount);

    DeployInsurancePolicy deployer;
    InsurancePolicy insurancePolicy;
    uint256 premium = 2e18;
    uint256 duration = 1717314780;

    address public USER = makeAddr("anmol");
    uint256 public STARTING_BALANCE = 10 ether;

    function setUp() external {
        deployer = new DeployInsurancePolicy();
        (insurancePolicy) = deployer.run();
        vm.deal(USER, STARTING_BALANCE);
    }

    modifier registerPolicyholder() {
        vm.startPrank(USER);
        insurancePolicy.registerPolicyholder(premium, duration);
        _;
    }

    function testCanUserRegisterPolicyholder() public registerPolicyholder {
        bool isActive = true;
        bool expectedAns = insurancePolicy.isActive();
        InsurancePolicy.ClaimStatus claimstatus = insurancePolicy.getClaimStatus();

        assertEq(premium, insurancePolicy.getPremium());
        assertEq(block.timestamp + duration, insurancePolicy.getPolicyEndDate());
        assertEq(0, uint256(claimstatus));
        assertEq(isActive, expectedAns);
        vm.stopPrank();
    }

    function testRevertIfEnoughPremiumIsnotPay() public registerPolicyholder {
        vm.expectRevert();
        insurancePolicy.payPremium{value: 1e18}();
        vm.stopPrank();
    }

    function testRevertIfAmountIsGrater() public registerPolicyholder {
        uint256 amount = 3e18;
        insurancePolicy.payPremium{value: premium}();
        vm.expectRevert();
        insurancePolicy.fileClaim(amount);
        vm.stopPrank();
    }

    function testUserFileClaim() public registerPolicyholder {
        uint256 amount = 2e18;
        insurancePolicy.payPremium{value: premium}();
        vm.expectEmit(true, true, false, false, address(insurancePolicy));
        emit ClaimSubmitted(USER, amount);
        insurancePolicy.fileClaim(amount);

        InsurancePolicy.ClaimStatus claimStatus = insurancePolicy.getClaimStatus();
        assertEq(1, uint256(claimStatus));
        vm.stopPrank();
    }
}
