// Decentralised-Freelance-Platform/Project.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Project {
    
    enum JobStatus { Open, InProgress, Completed, Disputed }
    
    struct Job {
        address client;
        address freelancer;
        uint256 payment;
        uint256 deadline;
        JobStatus status;
        string jobHash; // IPFS hash for job details
        bool fundsDeposited;
    }
    
    struct FreelancerProfile {
        bytes32 skillHash; // Hash of skills for privacy
        uint256 completedJobs;
        uint256 totalEarned;
        bool isActive;
    }
    
    mapping(uint256 => Job) public jobs;
    mapping(address => FreelancerProfile) public freelancers;
    uint256 public jobCounter;
    
    event JobCreated(uint256 indexed jobId, address indexed client, uint256 payment);
    event JobAccepted(uint256 indexed jobId, address indexed freelancer);
    event JobCompleted(uint256 indexed jobId);
    event PaymentReleased(uint256 indexed jobId, address indexed freelancer, uint256 amount);
    event FreelancerRegistered(address indexed freelancer, bytes32 skillHash);
    
    modifier onlyClient(uint256 _jobId) {
        require(jobs[_jobId].client == msg.sender, "Only client can perform this action");
        _;
    }
    
    modifier onlyFreelancer(uint256 _jobId) {
        require(jobs[_jobId].freelancer == msg.sender, "Only assigned freelancer can perform this action");
        _;
    }
    
    // Core Function 1: Register Freelancer with Privacy-Preserving Profile
    function registerFreelancer(bytes32 _skillHash) external {
        require(!freelancers[msg.sender].isActive, "Already registered");
        
        freelancers[msg.sender] = FreelancerProfile({
            skillHash: _skillHash,
            completedJobs: 0,
            totalEarned: 0,
            isActive: true
        });
        
        emit FreelancerRegistered(msg.sender, _skillHash);
    }
    
    // Core Function 2: Create Job with Escrow Payment
    function createJob(string memory _jobHash, uint256 _deadline) external payable returns (uint256) {
        require(msg.value > 0, "Payment must be greater than 0");
        require(_deadline > block.timestamp, "Deadline must be in the future");
        
        jobCounter++;
        
        jobs[jobCounter] = Job({
            client: msg.sender,
            freelancer: address(0),
            payment: msg.value,
            deadline: _deadline,
            status: JobStatus.Open,
            jobHash: _jobHash,
            fundsDeposited: true
        });
        
        emit JobCreated(jobCounter, msg.sender, msg.value);
        return jobCounter;
    }
    
    // Core Function 3: Complete Job and Release Payment
    function completeJobAndRelease(uint256 _jobId) external onlyClient(_jobId) {
        Job storage job = jobs[_jobId];
        require(job.status == JobStatus.InProgress, "Job must be in progress");
        require(job.fundsDeposited, "No funds in escrow");
        
        job.status = JobStatus.Completed;
        
        // Update freelancer stats
        FreelancerProfile storage profile = freelancers[job.freelancer];
        profile.completedJobs++;
        profile.totalEarned += job.payment;
        
        // Release payment
        uint256 payment = job.payment;
        job.fundsDeposited = false;
        
        (bool success, ) = payable(job.freelancer).call{value: payment}("");
        require(success, "Payment transfer failed");
        
        emit JobCompleted(_jobId);
        emit PaymentReleased(_jobId, job.freelancer, payment);
    }
    
    // Helper Function: Accept Job (Freelancer applies)
    function acceptJob(uint256 _jobId) external {
        Job storage job = jobs[_jobId];
        require(job.status == JobStatus.Open, "Job not available");
        require(freelancers[msg.sender].isActive, "Must be registered freelancer");
        require(job.freelancer == address(0), "Job already accepted");
        
        job.freelancer = msg.sender;
        job.status = JobStatus.InProgress;
        
        emit JobAccepted(_jobId, msg.sender);
    }
    
    // View Function: Get Freelancer Reputation (Privacy-Preserved)
    function getFreelancerReputation(address _freelancer) external view returns (uint256 completedJobs, uint256 totalEarned) {
        FreelancerProfile memory profile = freelancers[_freelancer];
        return (profile.completedJobs, profile.totalEarned);
    }
    
    // View Function: Verify Freelancer Skills (Client can verify hash)
    function verifyFreelancerSkills(address _freelancer, string memory _skills) external view returns (bool) {
        bytes32 providedHash = keccak256(abi.encodePacked(_skills));
        return freelancers[_freelancer].skillHash == providedHash;
    }
}

