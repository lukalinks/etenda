// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Tender Contract
 * @dev Manages tender creation, bidding, and awarding process
 */
contract Tender {
    // Tender status enum
    enum Status { Open, Closed, Awarded }
    enum Visibility { Public, Private } // New enum for tender visibility
    enum BidStatus { Pending, Accepted, Rejected, Withdrawn }
    enum TenderType { Standard, ReverseAuction, MultiStage }
    
    // Tender structure
    struct TenderDetails {
        uint256 id;
        address owner;
        string title;
        string description;
        uint256 budget;
        uint256 deadline;
        Status status;
        string[] categories;
        uint256 minBidAmount;
        Visibility visibility;
        address[] allowedBidders; // For private tenders
        uint256 deposit; // Required deposit amount
        bool canBeExtended;
        uint256 maxBidRevisions;
        TenderType tenderType;
        uint256[] stageDurations; // For multi-stage tenders
        uint256[] stageMinBids;   // Minimum bids required per stage
        uint256 currentStage;     // Current stage for multi-stage tenders
        bool requiresKYC;         // Know Your Customer requirement
        mapping(address => bool) kycApproved; // KYC approved bidders
        string[] requiredDocuments; // Required document hashes
        uint256 maxParticipants;  // Maximum number of participants
        uint256 currentParticipants;
    }

    // Bid structure
    struct Bid {
        address bidder;
        uint256 amount;
        string proposal;
        bool selected;
        uint256 revisionCount;
        uint256 timestamp;
        BidStatus status;
        string[] documentHashes;   // IPFS hashes of submitted documents
        uint256 stage;            // Stage number for multi-stage tenders
        uint256 technicalScore;   // Technical evaluation score
        uint256 financialScore;   // Financial evaluation score
    }

    struct BidderReputation {
        uint256 totalBids;
        uint256 wonBids;
        uint256 completedBids;
        uint256 rating; // Out of 100
    }

    // State variables
    uint256 private tenderCounter;
    mapping(uint256 => TenderDetails) public tenders;
    mapping(uint256 => Bid[]) public bids;
    mapping(address => uint256[]) public userTenders;
    mapping(uint256 => uint256) public bidCounts;
    bool public paused;
    mapping(address => BidderReputation) public bidderReputations;
    mapping(uint256 => mapping(address => uint256)) public bidderDeposits;
    mapping(uint256 => mapping(address => bool)) private allowedBiddersList;
    mapping(address => bool) public kycVerified;
    mapping(uint256 => mapping(uint256 => uint256)) public stageWinners; // tender -> stage -> winning bid index
    mapping(address => uint256) public bidderCollateral; // Global bidder collateral
    
    // Events
    event TenderCreated(uint256 indexed tenderId, address indexed owner, string title, uint256 budget);
    event BidSubmitted(uint256 indexed tenderId, address indexed bidder, uint256 amount);
    event TenderAwarded(uint256 indexed tenderId, address indexed winner);
    event TenderClosed(uint256 indexed tenderId);
    event BidWithdrawn(uint256 indexed tenderId, address indexed bidder, uint256 amount);
    event TenderModified(uint256 indexed tenderId, string title, uint256 budget, uint256 deadline);
    event TenderExtended(uint256 indexed tenderId, uint256 newDeadline);
    event DepositReceived(uint256 indexed tenderId, address indexed bidder, uint256 amount);
    event DepositReturned(uint256 indexed tenderId, address indexed bidder, uint256 amount);
    event BidderRated(address indexed bidder, uint256 rating);
    event ContractPaused(address indexed by);
    event ContractUnpaused(address indexed by);
    event StageCompleted(uint256 indexed tenderId, uint256 stage);
    event KYCStatusUpdated(address indexed bidder, bool status);
    event TechnicalScoreUpdated(uint256 indexed tenderId, uint256 bidIndex, uint256 score);
    event CollateralDeposited(address indexed bidder, uint256 amount);
    event DocumentSubmitted(uint256 indexed tenderId, address indexed bidder, string documentHash);

    // Errors
    error InvalidDeadline();
    error InvalidBudget();
    error TenderNotExists();
    error NotTenderOwner();
    error TenderNotOpen();
    error DeadlinePassed();
    error OwnerCannotBid();
    error BidExceedsBudget();
    error InvalidBidIndex();
    error BidNotFound();
    error BidAmountTooLow();
    error DeadlineCannotBeReduced();
    error InsufficientDeposit();
    error UnauthorizedBidder();
    error MaxRevisionReached();
    error ContractPaused();
    error InvalidRating();
    error OnlyAdmin();
    error CannotExtendDeadline();
    error KYCRequired();
    error MaxParticipantsReached();
    error InvalidStage();
    error InsufficientCollateral();
    error DocumentsRequired();
    error InvalidDocumentHash();

    // Admin role
    address public admin;
    
    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) revert OnlyAdmin();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier onlyTenderOwner(uint256 tenderId) {
        if (msg.sender != tenders[tenderId].owner) revert NotTenderOwner();
        _;
    }

    modifier tenderExists(uint256 tenderId) {
        if (tenderId >= tenderCounter) revert TenderNotExists();
        _;
    }

    modifier tenderOpen(uint256 tenderId) {
        if (tenders[tenderId].status != Status.Open) revert TenderNotOpen();
        if (block.timestamp >= tenders[tenderId].deadline) revert DeadlinePassed();
        _;
    }

    /**
     * @dev Emergency pause functionality
     */
    function togglePause() external onlyAdmin {
        paused = !paused;
        if (paused) {
            emit ContractPaused(msg.sender);
        } else {
            emit ContractUnpaused(msg.sender);
        }
    }

    /**
     * @dev Posts a new tender with additional parameters
     */
    function postTender(
        string calldata title,
        string calldata description,
        uint256 budget,
        uint256 deadline,
        string[] calldata categories,
        uint256 minBidAmount,
        Visibility visibility,
        address[] calldata allowedBidders,
        uint256 deposit,
        bool canBeExtended,
        uint256 maxBidRevisions,
        TenderType tenderType,
        uint256[] calldata stageDurations,
        uint256[] calldata stageMinBids,
        bool requiresKYC,
        string[] calldata requiredDocuments,
        uint256 maxParticipants
    ) external whenNotPaused returns (uint256) {
        if (deadline <= block.timestamp) revert InvalidDeadline();
        if (budget == 0) revert InvalidBudget();
        if (minBidAmount > budget) revert InvalidBudget();
        
        uint256 tenderId = tenderCounter++;
        
        TenderDetails memory newTender = TenderDetails({
            id: tenderId,
            owner: msg.sender,
            title: title,
            description: description,
            budget: budget,
            deadline: deadline,
            status: Status.Open,
            categories: categories,
            minBidAmount: minBidAmount,
            visibility: visibility,
            allowedBidders: allowedBidders,
            deposit: deposit,
            canBeExtended: canBeExtended,
            maxBidRevisions: maxBidRevisions,
            tenderType: tenderType,
            stageDurations: stageDurations,
            stageMinBids: stageMinBids,
            currentStage: 0,
            requiresKYC: requiresKYC,
            kycApproved: mapping(address => bool)(allowedBidders),
            requiredDocuments: requiredDocuments,
            maxParticipants: maxParticipants,
            currentParticipants: 0
        });
        
        if (visibility == Visibility.Private) {
            for (uint256 i = 0; i < allowedBidders.length; i++) {
                allowedBiddersList[tenderId][allowedBidders[i]] = true;
            }
        }
        
        tenders[tenderId] = newTender;
        userTenders[msg.sender].push(tenderId);
        
        emit TenderCreated(tenderId, msg.sender, title, budget);
        return tenderId;
    }

    /**
     * @dev Modifies an existing tender
     */
    function modifyTender(
        uint256 tenderId,
        string calldata title,
        string calldata description,
        uint256 budget,
        uint256 deadline,
        string[] calldata categories,
        uint256 minBidAmount
    ) 
        external 
        tenderExists(tenderId) 
        onlyTenderOwner(tenderId) 
        tenderOpen(tenderId) 
    {
        TenderDetails storage tender = tenders[tenderId];
        
        // Cannot reduce deadline as it would be unfair to bidders
        if (deadline < tender.deadline) revert DeadlineCannotBeReduced();
        if (budget == 0) revert InvalidBudget();
        if (minBidAmount > budget) revert InvalidBudget();

        tender.title = title;
        tender.description = description;
        tender.budget = budget;
        tender.deadline = deadline;
        tender.categories = categories;
        tender.minBidAmount = minBidAmount;

        emit TenderModified(tenderId, title, budget, deadline);
    }

    /**
     * @dev Submit bid with deposit
     */
    function submitBid(
        uint256 tenderId,
        uint256 amount,
        string calldata proposal,
        string[] calldata documentHashes
    ) external payable whenNotPaused tenderExists(tenderId) tenderOpen(tenderId) {
        TenderDetails storage tender = tenders[tenderId];
        
        if (tender.visibility == Visibility.Private && !allowedBiddersList[tenderId][msg.sender]) {
            revert UnauthorizedBidder();
        }
        
        if (msg.value < tender.deposit) {
            revert InsufficientDeposit();
        }
        
        // Check bid revision limit
        uint256 revisionCount = 0;
        for (uint256 i = 0; i < bids[tenderId].length; i++) {
            if (bids[tenderId][i].bidder == msg.sender) {
                revisionCount = bids[tenderId][i].revisionCount + 1;
                if (revisionCount > tender.maxBidRevisions) {
                    revert MaxRevisionReached();
                }
                break;
            }
        }
        
        if (msg.sender == tenders[tenderId].owner) revert OwnerCannotBid();
        if (amount > tenders[tenderId].budget) revert BidExceedsBudget();
        if (amount < tenders[tenderId].minBidAmount) revert BidAmountTooLow();
        
        // Additional validations
        if (tender.requiresKYC && !kycVerified[msg.sender]) {
            revert KYCRequired();
        }
        
        if (tender.currentParticipants >= tender.maxParticipants) {
            revert MaxParticipantsReached();
        }
        
        if (tender.requiredDocuments.length > 0 && 
            documentHashes.length != tender.requiredDocuments.length) {
            revert DocumentsRequired();
        }
        
        bids[tenderId].push(Bid({
            bidder: msg.sender,
            amount: amount,
            proposal: proposal,
            selected: false,
            revisionCount: revisionCount,
            timestamp: block.timestamp,
            status: BidStatus.Pending,
            documentHashes: documentHashes,
            stage: tender.currentStage,
            technicalScore: 0,
            financialScore: 0
        }));
        
        bidCounts[tenderId]++;
        bidderDeposits[tenderId][msg.sender] = msg.value;
        emit DepositReceived(tenderId, msg.sender, msg.value);
        emit BidSubmitted(tenderId, msg.sender, amount);
        
        // Additional processing
        tender.currentParticipants++;
        
        Bid storage newBid = bids[tenderId][bids[tenderId].length - 1];
        newBid.status = BidStatus.Pending;
        newBid.documentHashes = documentHashes;
        newBid.stage = tender.currentStage;
    }

    /**
     * @dev Withdraws a bid from a tender
     */
    function withdrawBid(uint256 tenderId) 
        external 
        tenderExists(tenderId) 
        tenderOpen(tenderId) 
    {
        Bid[] storage tenderBids = bids[tenderId];
        bool bidFound = false;
        uint256 bidAmount;
        
        for (uint256 i = 0; i < tenderBids.length; i++) {
            if (tenderBids[i].bidder == msg.sender) {
                bidAmount = tenderBids[i].amount;
                // Remove bid by shifting subsequent elements
                for (uint256 j = i; j < tenderBids.length - 1; j++) {
                    tenderBids[j] = tenderBids[j + 1];
                }
                tenderBids.pop();
                bidCounts[tenderId]--;
                bidFound = true;
                break;
            }
        }
        
        if (!bidFound) revert BidNotFound();
        
        emit BidWithdrawn(tenderId, msg.sender, bidAmount);
    }

    /**
     * @dev Checks if a tender is still open
     */
    function isTenderOpen(uint256 tenderId) 
        external 
        view 
        tenderExists(tenderId) 
        returns (bool) 
    {
        TenderDetails memory tender = tenders[tenderId];
        return tender.status == Status.Open && block.timestamp < tender.deadline;
    }

    /**
     * @dev Gets the number of bids for a tender
     */
    function getBidCount(uint256 tenderId) 
        external 
        view 
        tenderExists(tenderId) 
        returns (uint256) 
    {
        return bidCounts[tenderId];
    }

    /**
     * @dev Awards the tender to a specific bid
     * @param tenderId ID of the tender
     * @param bidIndex Index of the winning bid
     */
    function awardTender(uint256 tenderId, uint256 bidIndex) 
        external 
        tenderExists(tenderId) 
        onlyTenderOwner(tenderId) 
        tenderOpen(tenderId)
    {
        if (bidIndex >= bids[tenderId].length) revert InvalidBidIndex();
        
        tenders[tenderId].status = Status.Awarded;
        bids[tenderId][bidIndex].selected = true;
        
        emit TenderAwarded(tenderId, bids[tenderId][bidIndex].bidder);
    }

    /**
     * @dev Closes a tender without awarding
     * @param tenderId ID of the tender
     */
    function closeTender(uint256 tenderId) 
        external 
        tenderExists(tenderId) 
        onlyTenderOwner(tenderId) 
        tenderOpen(tenderId)
    {
        tenders[tenderId].status = Status.Closed;
        emit TenderClosed(tenderId);
    }

    /**
     * @dev Gets tender details
     * @param tenderId ID of the tender
     * @return TenderDetails struct containing tender information
     */
    function getTenderDetails(uint256 tenderId) 
        external 
        view 
        tenderExists(tenderId) 
        returns (TenderDetails memory) 
    {
        return tenders[tenderId];
    }

    /**
     * @dev Gets all bids for a tender
     * @param tenderId ID of the tender
     * @return Array of Bid structs
     */
    function getTenderBids(uint256 tenderId) 
        external 
        view 
        tenderExists(tenderId) 
        returns (Bid[] memory) 
    {
        return bids[tenderId];
    }

    /**
     * @dev Gets all tenders created by a user
     * @param user Address of the user
     * @return Array of tender IDs
     */
    function getUserTenders(address user) external view returns (uint256[] memory) {
        return userTenders[user];
    }

    /**
     * @dev Gets most recent tenders
     * @param limit Maximum number of tenders to return
     * @return Array of TenderDetails structs
     */
    function getRecentTenders(uint256 limit) external view returns (TenderDetails[] memory) {
        uint256 count = tenderCounter < limit ? tenderCounter : limit;
        TenderDetails[] memory recentTenders = new TenderDetails[](count);
        
        for (uint256 i = 0; i < count; i++) {
            uint256 index = tenderCounter - 1 - i;
            recentTenders[i] = tenders[index];
        }
        
        return recentTenders;
    }

    /**
     * @dev Gets all bids made by a user
     * @param user Address of the user
     * @return Array of Bid structs
     */
    function getUserBids(address user) external view returns (Bid[] memory) {
        uint256 totalBids = 0;
        
        // First count total bids by user
        for (uint256 i = 0; i < tenderCounter; i++) {
            Bid[] memory tenderBids = bids[i];
            for (uint256 j = 0; j < tenderBids.length; j++) {
                if (tenderBids[j].bidder == user) {
                    totalBids++;
                }
            }
        }
        
        // Create array of user's bids
        Bid[] memory userBids = new Bid[](totalBids);
        uint256 currentIndex = 0;
        
        // Populate user's bids
        for (uint256 i = 0; i < tenderCounter; i++) {
            Bid[] memory tenderBids = bids[i];
            for (uint256 j = 0; j < tenderBids.length; j++) {
                if (tenderBids[j].bidder == user) {
                    userBids[currentIndex] = tenderBids[j];
                    currentIndex++;
                }
            }
        }
        
        return userBids;
    }

    /**
     * @dev Gets the total number of tenders
     * @return Current tender counter
     */
    function getTenderCount() external view returns (uint256) {
        return tenderCounter;
    }

    /**
     * @dev Extend tender deadline
     */
    function extendDeadline(uint256 tenderId, uint256 newDeadline) 
        external 
        tenderExists(tenderId) 
        onlyTenderOwner(tenderId) 
        tenderOpen(tenderId) 
    {
        TenderDetails storage tender = tenders[tenderId];
        if (!tender.canBeExtended) revert CannotExtendDeadline();
        if (newDeadline <= tender.deadline) revert InvalidDeadline();
        
        tender.deadline = newDeadline;
        emit TenderExtended(tenderId, newDeadline);
    }

    /**
     * @dev Rate a bidder's performance
     */
    function rateBidder(address bidder, uint256 rating) 
        external 
        onlyAdmin 
    {
        if (rating > 100) revert InvalidRating();
        
        BidderReputation storage reputation = bidderReputations[bidder];
        reputation.rating = rating;
        emit BidderRated(bidder, rating);
    }

    /**
     * @dev Return deposit to bidder
     */
    function returnDeposit(uint256 tenderId, address bidder) 
        external 
        tenderExists(tenderId) 
        onlyTenderOwner(tenderId) 
    {
        uint256 deposit = bidderDeposits[tenderId][bidder];
        if (deposit > 0) {
            bidderDeposits[tenderId][bidder] = 0;
            (bool success, ) = bidder.call{value: deposit}("");
            require(success, "Transfer failed");
            emit DepositReturned(tenderId, bidder, deposit);
        }
    }

    /**
     * @dev Get bidder reputation
     */
    function getBidderReputation(address bidder) 
        external 
        view 
        returns (BidderReputation memory) 
    {
        return bidderReputations[bidder];
    }

    /**
     * @dev Deposits global collateral for participating in tenders
     */
    function depositCollateral() external payable {
        bidderCollateral[msg.sender] += msg.value;
        emit CollateralDeposited(msg.sender, msg.value);
    }

    /**
     * @dev Updates KYC status for a bidder
     */
    function updateKYCStatus(address bidder, bool status) external onlyAdmin {
        kycVerified[bidder] = status;
        emit KYCStatusUpdated(bidder, status);
    }

    /**
     * @dev Submits required documents for a bid
     */
    function submitDocuments(
        uint256 tenderId,
        uint256 bidIndex,
        string[] calldata documentHashes
    ) external tenderExists(tenderId) {
        TenderDetails storage tender = tenders[tenderId];
        require(documentHashes.length == tender.requiredDocuments.length, "Invalid document count");
        
        Bid storage bid = bids[tenderId][bidIndex];
        require(bid.bidder == msg.sender, "Not bid owner");
        
        bid.documentHashes = documentHashes;
        
        for(uint256 i = 0; i < documentHashes.length; i++) {
            emit DocumentSubmitted(tenderId, msg.sender, documentHashes[i]);
        }
    }

    /**
     * @dev Updates technical and financial scores for a bid
     */
    function updateBidScores(
        uint256 tenderId,
        uint256 bidIndex,
        uint256 technicalScore,
        uint256 financialScore
    ) external onlyAdmin {
        require(technicalScore <= 100 && financialScore <= 100, "Invalid scores");
        
        Bid storage bid = bids[tenderId][bidIndex];
        bid.technicalScore = technicalScore;
        bid.financialScore = financialScore;
        
        emit TechnicalScoreUpdated(tenderId, bidIndex, technicalScore);
    }

    /**
     * @dev Advances a multi-stage tender to the next stage
     */
    function advanceStage(uint256 tenderId) 
        external 
        tenderExists(tenderId) 
        onlyTenderOwner(tenderId) 
    {
        TenderDetails storage tender = tenders[tenderId];
        require(tender.tenderType == TenderType.MultiStage, "Not multi-stage tender");
        require(tender.currentStage < tender.stageDurations.length - 1, "Final stage reached");
        
        // Validate minimum bids for current stage
        require(bidCounts[tenderId] >= tender.stageMinBids[tender.currentStage], "Insufficient bids");
        
        tender.currentStage++;
        emit StageCompleted(tenderId, tender.currentStage - 1);
    }

    /**
     * @dev Gets weighted score for a bid
     */
    function getBidScore(uint256 tenderId, uint256 bidIndex) 
        public 
        view 
        returns (uint256) 
    {
        Bid memory bid = bids[tenderId][bidIndex];
        // 60% technical, 40% financial weight
        return (bid.technicalScore * 60 + bid.financialScore * 40) / 100;
    }
} 