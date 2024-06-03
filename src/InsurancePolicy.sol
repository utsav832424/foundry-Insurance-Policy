// SPDX-License-Identifier: MIT
pragma solidity >0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {console} from "forge-std/console.sol";

contract InsurancePolicy is ReentrancyGuard {
    error InsurancePolicy__TransferFailed();
    error InsurancePolicy__NotAuthorized();
    error InsurancePolicy__InvalidClaimStatus();
    error InsurancePolicy__PolicyExpired();

    address public immutable insurer;
    address private s_policyHolder;
    uint256 private s_premium;
    uint256 private s_policyEndDate;

    enum ClaimStatus {
        NotFilled,
        Pending,
        Approved,
        Rejected
    }

    ClaimStatus private s_claimStatus;
    bool public isActive;
    bool public claimSubmit;
    mapping(address => uint256) private s_policies;
    mapping(address => uint256) private claims;

    event PolicyCreated(address indexed policyHolder, uint256 indexed amount);
    event PayPolicy(address indexed policyHolder, uint256 indexed premiumAmount);
    event ClaimSubmitted(address indexed policyHolder, uint256 indexed claimAmount);
    event ApproveClaim(address indexed policyHolder, uint256 indexed approveAmount);
    event RejectClaim(address indexed policyHolder, uint256 indexed rejectAmount);
    event PolicyExpired(address indexed policyHolder);

    modifier onlyPolicyHolder() {
        if (msg.sender != s_policyHolder) {
            revert InsurancePolicy__NotAuthorized();
        }
        _;
    }

    modifier onlyInsurer() {
        if (msg.sender != insurer) {
            revert InsurancePolicy__NotAuthorized();
        }
        _;
    }

    modifier isPolicyActive() {
        if (!isActive || block.timestamp > s_policyEndDate) {
            revert InsurancePolicy__PolicyExpired();
        }
        _;
    }

    modifier ClaimNotSubmited() {
        require(!claimSubmit, "Claim has already submitted");
        _;
    }

    constructor() {
        insurer = msg.sender;
    }

    function registerPolicyholder(uint256 _premium, uint256 _duration) public {
        s_policyHolder = msg.sender;
        s_premium = _premium;
        s_policyEndDate = block.timestamp + _duration;
        isActive = true;
        claimSubmit = false;
        s_claimStatus = ClaimStatus.NotFilled;
        emit PolicyCreated(s_policyHolder, s_premium);
    }

    function payPremium() public payable onlyPolicyHolder isPolicyActive nonReentrant {
        require(msg.value == s_premium, "Amount is same as Premium");
        s_policies[msg.sender] += msg.value;
        emit PayPolicy(s_policyHolder, msg.value);
    }

    function fileClaim(uint256 amount) public onlyPolicyHolder isPolicyActive ClaimNotSubmited nonReentrant {
        require(amount <= s_policies[msg.sender], "Invalid Amount");
        claimSubmit = true;
        claims[msg.sender] += amount;
        s_claimStatus = ClaimStatus.Pending;
        emit ClaimSubmitted(s_policyHolder, amount);
    }

    function verifyClaim(address policyholder, bool _isValid) public onlyInsurer nonReentrant {
        require(claims[policyholder] > 0, "Policyholder has no Claims amount");
        if (s_claimStatus != ClaimStatus.Pending) {
            revert InsurancePolicy__InvalidClaimStatus();
        }
        if (block.timestamp > s_policyEndDate) {
            revert InsurancePolicy__PolicyExpired();
        }

        if (_isValid) {
            s_claimStatus = ClaimStatus.Approved;
            payOutClaim(policyholder);
        } else {
            s_claimStatus = ClaimStatus.Rejected;
            emit RejectClaim(policyholder, claims[policyholder]);
            claims[policyholder] = 0;
        }
    }

    function payOutClaim(address policyholder) internal {
        require(s_claimStatus == ClaimStatus.Approved, "Claim is not approved");
        uint256 payoutAmount = claims[policyholder];
        s_policies[policyholder] -= payoutAmount;

        (bool success,) = payable(s_policyHolder).call{value: payoutAmount}("");
        if (!success) {
            revert InsurancePolicy__TransferFailed();
        }
        emit ApproveClaim(policyholder, claims[policyholder]);
        claims[policyholder] = 0;
        isActive = false;
    }

    function checkPolicyStatus() public returns (string memory) {
        if (block.timestamp > s_policyEndDate) {
            emit PolicyExpired(s_policyHolder);
            return "Policy has Expired";
        } else if (s_claimStatus == ClaimStatus.Pending) {
            return "Claim is Pending";
        } else if (s_claimStatus == ClaimStatus.Approved) {
            return "Claim has Approved";
        } else if (s_claimStatus == ClaimStatus.Rejected) {
            return "Claim has Rejected";
        } else {
            return "Policy is Active";
        }
    }

    function getPolicyHolder() external view returns (address) {
        return s_policyHolder;
    }

    function getPremium() external view returns (uint256) {
        return s_premium;
    }

    function getPolicyEndDate() external view returns (uint256) {
        return s_policyEndDate;
    }

    function getClaimStatus() external view returns (ClaimStatus) {
        return s_claimStatus;
    }

    function getPolicies(address user) external view returns (uint256) {
        return s_policies[user];
    }

    function getClaims(address user) external view returns (uint256) {
        return claims[user];
    }
}
