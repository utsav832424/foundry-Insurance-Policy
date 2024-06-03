// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DeployInsurancePolicy} from "../../script/DeployInsurancePolicy.s.sol";
import {InsurancePolicy} from "../../src/InsurancePolicy.sol";

contract InsurancePolicyTest is Test {
    event PolicyCreated(address indexed policyHolder, uint256 indexed amount);
    event ClaimSubmitted(address indexed policyHolder, uint256 indexed claimAmount);
    event ApproveClaim(address indexed policyHolder, uint256 indexed approveAmount);
    event RejectClaim(address indexed policyHolder, uint256 indexed rejectAmount);

    DeployInsurancePolicy deployer;
    InsurancePolicy insurancePolicy;
    uint256 premium = 2e18;
    uint256 duration = 20000;

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

    function testCanUserRegisterPolicyholder() public {
        bool isActive = true;

        vm.expectEmit(true, true, false, false, address(insurancePolicy));
        emit PolicyCreated(USER, premium);

        vm.startPrank(USER);
        insurancePolicy.registerPolicyholder(premium, duration);

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
        assertEq(premium, insurancePolicy.getClaims(USER));
        assertEq(true, insurancePolicy.isActive());
        vm.stopPrank();
        assertEq("Claim is Pending", insurancePolicy.checkPolicyStatus());
    }

    modifier registerAndFileClaim() {
        vm.startPrank(USER);
        insurancePolicy.registerPolicyholder(premium, duration);
        insurancePolicy.payPremium{value: premium}();
        insurancePolicy.fileClaim(premium);
        vm.stopPrank();
        _;
    }

    function testApproveClaim() public registerAndFileClaim {
        vm.expectEmit(true, true, false, false, address(insurancePolicy));
        emit ApproveClaim(USER, premium);

        vm.prank(insurancePolicy.insurer());
        insurancePolicy.verifyClaim(USER, true);

        assertEq(0, insurancePolicy.getClaims(USER));
        assertEq(2, uint256(insurancePolicy.getClaimStatus()));
        assertEq(false, insurancePolicy.isActive());
        assertEq(0, insurancePolicy.getPolicies(USER));
        assertEq("Claim has Approved", insurancePolicy.checkPolicyStatus());
    }

    function testRejectTheClaim() public registerAndFileClaim {
        vm.expectEmit(true, true, false, false, address(insurancePolicy));
        emit RejectClaim(USER, premium);

        vm.startPrank(insurancePolicy.insurer());
        insurancePolicy.verifyClaim(USER, false);
        vm.stopPrank();

        assertEq("Claim has Rejected", insurancePolicy.checkPolicyStatus());
        assertEq(3, uint256(insurancePolicy.getClaimStatus()));
    }

    function testRevertIfPolicyHasExpired() public registerAndFileClaim {
        vm.warp(block.timestamp + 400000);
        vm.prank(insurancePolicy.insurer());
        vm.expectRevert(InsurancePolicy.InsurancePolicy__PolicyExpired.selector);
        insurancePolicy.verifyClaim(USER, true);
    }
}
