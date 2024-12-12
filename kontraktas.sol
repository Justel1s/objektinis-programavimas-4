// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AirplaneMaintenance {
    address public manager;
    uint256 public projectCount;

    struct Project {
        string airplaneModel;
        string description;
        uint256 cost;
        address client;
        address selectedBidder;
        bool isCompleted;
        bool isClosed;
        bool isPaid;
        mapping(address => uint256) bids;
        address[] bidders;
    }

    mapping(uint256 => Project) public projects;

    event ProjectCreated(uint256 projectId, string airplaneModel, uint256 cost);
    event BidPlaced(uint256 projectId, address bidder, uint256 amount);
    event BidderSelected(uint256 projectId, address bidder);
    event ProjectCompleted(uint256 projectId);
    event PaymentReleased(uint256 projectId, address bidder, uint256 amount);

    constructor() {
        manager = msg.sender;
    }

    modifier onlyManager() {
        require(msg.sender == manager, "Only manager can call this");
        _;
    }

    modifier projectExists(uint256 projectId) {
        require(projectId < projectCount, "Project does not exist");
        _;
    }

    function createProject(
        string memory _airplaneModel, 
        string memory _description, 
        uint256 _cost
    ) external onlyManager {
        Project storage newProject = projects[projectCount];
        newProject.airplaneModel = _airplaneModel;
        newProject.description = _description;
        newProject.cost = _cost;
        newProject.client = msg.sender;
        newProject.isCompleted = false;
        newProject.isClosed = false;
        newProject.isPaid = false;

        emit ProjectCreated(projectCount, _airplaneModel, _cost);
        projectCount++;
    }

    function placeBid(uint256 projectId) external payable projectExists(projectId) {
        Project storage project = projects[projectId];
        
        require(!project.isClosed, "Project is closed");
        require(msg.value > 0, "Bid must be greater than 0");
        require(msg.sender != manager, "Manager cannot place bids");

        if (project.bids[msg.sender] == 0) {
            project.bidders.push(msg.sender);
        }
        
        project.bids[msg.sender] = msg.value;
        emit BidPlaced(projectId, msg.sender, msg.value);
    }

    function selectBidder(uint256 projectId, address bidder) external projectExists(projectId) onlyManager {
        Project storage project = projects[projectId];
        
        require(!project.isClosed, "Project is already closed");
        require(project.bids[bidder] > 0, "Selected address has not placed a bid");

        project.selectedBidder = bidder;
        project.isClosed = true;

        // Refund other bidders
        for (uint i = 0; i < project.bidders.length; i++) {
            address currentBidder = project.bidders[i];
            if (currentBidder != bidder) {
                uint256 refundAmount = project.bids[currentBidder];
                if (refundAmount > 0) {
                    project.bids[currentBidder] = 0;
                    (bool success, ) = payable(currentBidder).call{value: refundAmount}("");
                    require(success, "Refund failed");
                }
            }
        }

        emit BidderSelected(projectId, bidder);
    }

    function completeProject(uint256 projectId) external projectExists(projectId) {
        Project storage project = projects[projectId];
        
        require(msg.sender == project.selectedBidder, "Only selected bidder can complete");
        require(!project.isCompleted, "Project already completed");
        require(project.isClosed, "Project must be closed first");

        project.isCompleted = true;
        emit ProjectCompleted(projectId);
    }

    function payBidder(uint256 projectId) external payable onlyManager projectExists(projectId) {
        Project storage project = projects[projectId];
        
        require(project.isCompleted, "Project must be completed first");
        require(!project.isPaid, "Payment already sent");
        require(project.selectedBidder != address(0), "No bidder selected");
        
        uint256 bidAmount = project.bids[project.selectedBidder];
        require(bidAmount > 0, "No bid amount found");

        project.isPaid = true;
        project.bids[project.selectedBidder] = 0;
        
        (bool success, ) = payable(project.selectedBidder).call{value: bidAmount}("");
        require(success, "Payment failed");

        emit PaymentReleased(projectId, project.selectedBidder, bidAmount);
    }

    function getProject(uint256 projectId) external view projectExists(projectId) returns (
        string memory airplaneModel,
        string memory description,
        uint256 cost,
        address client,
        address selectedBidder,
        bool isCompleted,
        bool isClosed,
        bool isPaid
    ) {
        Project storage project = projects[projectId];
        return (
            project.airplaneModel,
            project.description,
            project.cost,
            project.client,
            project.selectedBidder,
            project.isCompleted,
            project.isClosed,
            project.isPaid
        );
    }

    function getProjectBids(uint256 projectId) external view projectExists(projectId) returns (
        address[] memory bidders,
        uint256[] memory amounts
    ) {
        Project storage project = projects[projectId];
        uint256[] memory bidAmounts = new uint256[](project.bidders.length);
        
        for (uint i = 0; i < project.bidders.length; i++) {
            bidAmounts[i] = project.bids[project.bidders[i]];
        }
        
        return (project.bidders, bidAmounts);
    }

    receive() external payable {}
    fallback() external payable {}
}