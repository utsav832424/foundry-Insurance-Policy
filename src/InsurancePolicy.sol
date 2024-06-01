// SPDX-License-Identifier: MIT
pragma solidity >0.8.20;

contract InsurancePolicy {
    error InsurancePolicy__TransferFailed();
    error InsurancePolicy__NotAuthorized();
    error InsurancePolicy__InvalidClaimStatus();
    error InsurancePolicy__PolicyExpired();

    address public insurer;
    address public s_policyHolder;
    uint256 public s_premium;
    uint256 public s_policyEndDate;

    enum ClaimStatus {
        NotFilled,
        Pending,
        Approved,
        Rejected
    }

    ClaimStatus public claimStatus;
    bool public isActive;
    bool public claimSubmit;
    mapping(address => uint256) public policies;

    event PolicyCreated(address indexed policyHolder, uint256 indexed amount);
    event PayPolicy(address indexed policyHolder, uint256 indexed premiumAmount);
    event ClaimSubmitted(address indexed policyHolder);
    event VerifyClaim(address indexed policyHolder, bool indexed isValid);

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
        require(!claimSubmit, "Claim has already sibmitted");
        _;
    }

    constructor(address _policyHolder, uint256 _premium, uint256 _duration) {
        insurer = msg.sender;
        s_policyHolder = _policyHolder;
        s_premium = _premium;
        s_policyEndDate = block.timestamp + _duration;
        isActive = true;
        claimSubmit = false;
        claimStatus = ClaimStatus.NotFilled;
        emit PolicyCreated(s_policyHolder, s_premium);
    }

    function payPremium() public payable onlyPolicyHolder isPolicyActive {
        require(msg.value == s_premium, "Amount is same as Premium");
        policies[msg.sender] += msg.value;
        emit PayPolicy(s_policyHolder, msg.value);
    }

    function fileClaim() public onlyPolicyHolder isPolicyActive ClaimNotSubmited {
        claimStatus = ClaimStatus.Pending;
        claimSubmit = true;
        emit ClaimSubmitted(s_policyHolder);
    }

    function verifyClaim(bool _isValid, string memory rejectNote) public onlyInsurer {
        if (claimStatus != ClaimStatus.Pending) {
            revert InsurancePolicy__InvalidClaimStatus();
        }
        if (block.timestamp > s_policyEndDate) {
            revert InsurancePolicy__PolicyExpired();
        }

        emit VerifyClaim(s_policyHolder, _isValid);
        if (_isValid) {
            claimStatus = ClaimStatus.Approved;

            payOutClaim();
        } else {
            claimStatus = ClaimStatus.Rejected;
            rejectPolicy(rejectNote);
        }
    }

    function payOutClaim() internal {
        require(claimStatus == ClaimStatus.Approved, "Claim is not approved");
        uint256 payoutAmount = address(this).balance;
        policies[s_policyHolder] -= payoutAmount;

        (bool success,) = payable(s_policyHolder).call{value: payoutAmount}("");
        if (!success) {
            revert InsurancePolicy__TransferFailed();
        }
        isActive = false;
    }

    function rejectPolicy(string memory rejectNote) private returns (string memory) {
        claimStatus = ClaimStatus.NotFilled;
        return rejectNote;
    }
}
