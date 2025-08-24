// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./NFTMetadataLib.sol";
import "./FinanceLib.sol";
import "./MembershipLib.sol";
import "./TokenLib.sol";
import "./ContractErrors.sol";
import "./GrowthCommissionLib.sol";
import "./AdminLib.sol";
import "./ViewLib.sol";

contract CryptoMembershipNFT is ERC721Enumerable, Ownable, ReentrancyGuard {
    using TokenLib for IERC20;
    using GrowthCommissionLib for GrowthCommissionLib.GrowthCommissionState;

    struct ContractState {
        uint256 tokenIdCounter;
        uint256 planCount;
        uint256 ownerBalance;
        uint256 feeSystemBalance;
        uint256 fundBalance;
        uint256 totalCommissionPaid;
        bool firstMemberRegistered;
        bool paused;
        uint256 emergencyWithdrawRequestTime;
    }

    struct NFTImage {
        string imageURI;
        string name;
        string description;
        uint256 planId;
        uint256 createdAt;
    }

    ContractState private state;
    GrowthCommissionLib.GrowthCommissionState private growthCommission;
    IERC20 public immutable usdtToken;
    uint8 private immutable _tokenDecimals;
    address public priceFeed;
    string private _baseTokenURI;

    uint256 public constant MAX_MEMBERS_PER_CYCLE = 4;
    uint256 public constant TIMELOCK_DURATION = 2 days;

    mapping(uint256 => MembershipLib.MembershipPlan) public plans;
    mapping(address => MembershipLib.Member) public members;
    mapping(uint256 => MembershipLib.CycleInfo) public planCycles;
    mapping(uint256 => NFTImage) public tokenImages;
    mapping(uint256 => string) public planDefaultImages;
    mapping(address => address[]) private _referralChain;
    bool private _inTransaction;

    // Essential events only
    event PlanCreated(uint256 planId, string name, uint256 price, uint256 membersPerCycle);
    event MemberRegistered(address indexed member, address indexed upline, uint256 planId);
    event ReferralPaid(address indexed from, address indexed to, uint256 amount);
    event PlanUpgraded(address indexed member, uint256 oldPlanId, uint256 newPlanId);
    event NewCycleStarted(uint256 planId, uint256 cycleNumber);
    event EmergencyWithdraw(address indexed to, uint256 amount);
    event ContractPaused(bool status);
    event FundsDistributed(uint256 ownerAmount, uint256 feeAmount, uint256 fundAmount);
    event MemberExited(address indexed member, uint256 refundAmount);
    event EmergencyWithdrawRequested(uint256 timestamp);

    modifier whenNotPaused() {
        if (state.paused) revert ContractErrors.Paused();
        _;
    }

    modifier onlyMember() {
        if (balanceOf(msg.sender) == 0) revert ContractErrors.NotMember();
        _;
    }

    modifier noReentrantTransfer() {
        if (_inTransaction) revert ContractErrors.ReentrantTransfer();
        _inTransaction = true;
        _;
        _inTransaction = false;
    }

    modifier validAddress(address _addr) {
        if (_addr == address(0)) revert ContractErrors.ZeroAddress();
        _;
    }

    constructor(address _usdtToken, address initialOwner)
        ERC721("Chainsx", "CSX")
        Ownable(initialOwner)
    {
        usdtToken = IERC20(_usdtToken);
        _tokenDecimals = IERC20Metadata(_usdtToken).decimals();
        if (_tokenDecimals == 0) revert ContractErrors.InvalidDecimals();
        
        _createDefaultPlans();
        _setupDefaultImages();
        _baseTokenURI = "ipfs://";
        
        GrowthCommissionLib.initialize(growthCommission);
        _createOwnerRootMembership(initialOwner);
    }

    function _createOwnerRootMembership(address ownerAddress) internal {
        uint256 tokenId = state.tokenIdCounter++;
        _safeMint(ownerAddress, tokenId);
        _setTokenImage(tokenId, state.planCount);
        members[ownerAddress] = MembershipLib.Member(address(0), 0, 0, 0, 1, block.timestamp);
        state.firstMemberRegistered = true;
        emit MemberRegistered(ownerAddress, address(0), 0);
    }

    function _setupDefaultImages() internal {
        string[16] memory images = [
            "bafybeignaodj5a2bmtt6ccz3mmf7dx5iseib3orllgf4ed4tdnfijnxfrq",
            "bafybeifymsrfkqzlmr2jetihb4cd7siro3vhq5s7xjjecshq3yoewxbbmy",
            "bafybeib36tixhjirirdq2hotmb6os5lgln66m4dseyhp353mqbbn5ubrzq",
            "bafybeihmyvmywvecl5x2idguejduw2bsy4kynplhnas37ji7qnir5y4k2i",
            "bafybeibkna2uzb5irusxczngkxdbijcpfed5lilsqa4yamkdzfrcbplyqy",
            "bafybeias7xs36rcrq64uswehgqfiqb5hkosjfmwya2jdmkt67fwqxybxk4",
            "bafybeihbrva37xflvzcqb3axouyd5kndshtldqooqgdcuniuahngjcxf2e",
            "bafybeiamlxlrejlvtbrwg7crgobz5wvanclef2uf7lrijw55hlhipnk4fu",
            "bafybeihsomjcfbqbb7uk27bxbgfooba7g4ggywnenleq442vr5rw3o3ygy",
            "bafybeiezl6kslyy7cmm2c5wdtpyj2awdzjuwqkp726owhx5x6llg4s2kwa",
            "bafybeigxtlrnxjm4gtkxobkg4mro5benoogrqtphqvewag6mcnqakcw7hm",
            "bafybeibi7daxnplgosboky33p3uvmhw3gg6bg5uojikdnhfaqryp6tb64y",
            "bafybeia7u3oblw32wh5e725tmxc47szss32ydbbc42pzserqky3dqt7ira",
            "bafybeicawcal7gklqjaorir7n6y3iewgzk3linc2srf4pj26pqcuypm5o4",
            "bafybeihqv3763mh2csw2vwhzluppejds6ahr7qyd7ejo5epyy5nnqmjvx4",
            "bafybeiav5pvrydstsr3ffjdscinlklhmjy3trhs6qglnilltbvxews5omm"
        ];
        
        for (uint256 i = 0; i < 16; i++) {
            planDefaultImages[i + 1] = images[i];
        }
    }

    function _createDefaultPlans() internal {
        uint256 decimal = 10**_tokenDecimals;
        string[16] memory planNames = [
            "Starter", "Basic", "Bronze", "Silver", "Gold", "Platinum", "Diamond", "Elite",
            "Master", "Grand Master", "Champion", "Legend", "Supreme", "Ultimate", "Apex", "Infinity"
        ];

        for (uint256 i = 0; i < 16; i++) {
            uint256 price = (i + 1) * decimal;
            uint256 membersPerCycle = i >= 12 ? 5 : 4;
            _createPlan(price, planNames[i], membersPerCycle);
        }
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) {
            revert ContractErrors.NonTransferable();
        }
        return super._update(to, tokenId, auth);
    }

    function _createPlan(uint256 _price, string memory _name, uint256 _membersPerCycle) internal {
        state.planCount++;
        plans[state.planCount] = MembershipLib.MembershipPlan(_price, _name, _membersPerCycle, true);
        planCycles[state.planCount] = MembershipLib.CycleInfo(1, 0);
        emit PlanCreated(state.planCount, _name, _price, _membersPerCycle);
    }

    function registerMember(uint256 _planId, address _upline) external nonReentrant whenNotPaused validAddress(_upline) {
        if (msg.sender == owner()) revert ContractErrors.AlreadyMember();
        if (_planId != 1 || _planId > state.planCount) revert ContractErrors.Plan1Only();
        if (!plans[_planId].isActive) revert ContractErrors.InactivePlan();
        if (balanceOf(msg.sender) > 0) revert ContractErrors.AlreadyMember();
        if (bytes(planDefaultImages[_planId]).length == 0) revert ContractErrors.NoPlanImage();

        address finalUpline = _determineUpline(_upline);
        usdtToken.safeTransferFrom(msg.sender, address(this), plans[_planId].price);

        uint256 tokenId = state.tokenIdCounter++;
        _safeMint(msg.sender, tokenId);
        _setTokenImage(tokenId, _planId);

        _updateCycleInfo(_planId);
        _createMember(finalUpline, _planId);
        _distributeFundsAndCommission(_planId, finalUpline);

        emit MemberRegistered(msg.sender, finalUpline, _planId);
    }

    function _updateCycleInfo(uint256 _planId) internal {
        MembershipLib.CycleInfo storage cycleInfo = planCycles[_planId];
        cycleInfo.membersInCurrentCycle++;
        if (cycleInfo.membersInCurrentCycle >= plans[_planId].membersPerCycle) {
            cycleInfo.currentCycle++;
            cycleInfo.membersInCurrentCycle = 0;
            emit NewCycleStarted(_planId, cycleInfo.currentCycle);
        }
    }

    function _createMember(address finalUpline, uint256 _planId) internal {
        members[msg.sender] = MembershipLib.Member(
            finalUpline, 0, 0, _planId, planCycles[_planId].currentCycle, block.timestamp
        );
    }

    function _distributeFundsAndCommission(uint256 _planId, address finalUpline) internal {
        (uint256 ownerShare, uint256 feeShare, uint256 fundShare, uint256 uplineShare) = 
            FinanceLib.distributeFunds(plans[_planId].price, _planId);

        state.ownerBalance += ownerShare;
        state.feeSystemBalance += feeShare;
        state.fundBalance += fundShare;

        _handleUplinePayment(finalUpline, uplineShare);

        GrowthCommissionLib.CommissionParams memory params = GrowthCommissionLib.CommissionParams({
            newMember: msg.sender,
            planId: _planId,
            ownerBalance: state.ownerBalance,
            owner: owner()
        });
        
        (, uint256 newOwnerBalance) = GrowthCommissionLib.processCommission(
            growthCommission, members, plans, params, usdtToken
        );
        state.ownerBalance = newOwnerBalance;

        emit FundsDistributed(ownerShare, feeShare, fundShare);
    }

    function _determineUpline(address _upline) internal returns (address) {
        if (_upline == address(0) || _upline == msg.sender) {
            return owner();
        }
        
        if (_upline == owner()) {
            return _upline;
        }
        
        if (balanceOf(_upline) == 0) {
            revert ContractErrors.UplineNotMember();
        }
        
        if (members[_upline].planId < 1) {
            revert ContractErrors.UplinePlanLow();
        }
        
        _referralChain[msg.sender] = new address[](1);
        _referralChain[msg.sender][0] = _upline;
        return _upline;
    }

    function upgradePlan(uint256 _newPlanId) external nonReentrant whenNotPaused onlyMember {
        bool isOwnerUpgrading = msg.sender == owner();
        if (_newPlanId == 0 || _newPlanId > state.planCount) revert ContractErrors.InvalidPlanID();
        if (!plans[_newPlanId].isActive) revert ContractErrors.InactivePlan();

        MembershipLib.Member storage member = members[msg.sender];
        uint256 oldPlanId = member.planId;

        if (isOwnerUpgrading && member.planId == 0) {
            _completeOwnerUpgrade(_newPlanId);
            return;
        }

        if (!isOwnerUpgrading && _newPlanId != member.planId + 1) {
            revert ContractErrors.NextPlanOnly();
        }
        
        if (isOwnerUpgrading && _newPlanId <= member.planId) {
            revert ContractErrors.InvalidPlanID();
        }

        address upline = member.upline;
        uint256 priceDifference = plans[_newPlanId].price - plans[oldPlanId].price;

        if (!isOwnerUpgrading) {
            usdtToken.safeTransferFrom(msg.sender, address(this), priceDifference);
        }

        _completeUpgradePlan(_newPlanId, oldPlanId, upline, priceDifference, isOwnerUpgrading);
    }

    function _completeOwnerUpgrade(uint256 _newPlanId) private {
        uint256 tokenId = tokenOfOwnerByIndex(msg.sender, 0);
        NFTImage storage image = tokenImages[tokenId];
        image.planId = _newPlanId;
        image.name = plans[_newPlanId].name;
        image.description = string(abi.encodePacked("Crypto Membership NFT - ", image.name, " Plan (ROOT ACCESS)"));
        image.imageURI = planDefaultImages[_newPlanId];
    }

    function _completeUpgradePlan(
        uint256 _newPlanId,
        uint256 oldPlanId,
        address upline,
        uint256 priceDifference,
        bool isOwnerUpgrading
    ) private {
        MembershipLib.CycleInfo storage cycleInfo = planCycles[_newPlanId];
        cycleInfo.membersInCurrentCycle++;
        if (cycleInfo.membersInCurrentCycle >= plans[_newPlanId].membersPerCycle) {
            cycleInfo.currentCycle++;
            cycleInfo.membersInCurrentCycle = 0;
            emit NewCycleStarted(_newPlanId, cycleInfo.currentCycle);
        }

        members[msg.sender].cycleNumber = cycleInfo.currentCycle;
        members[msg.sender].planId = _newPlanId;

        uint256 tokenId = tokenOfOwnerByIndex(msg.sender, 0);
        NFTImage storage image = tokenImages[tokenId];
        image.planId = _newPlanId;
        image.name = plans[_newPlanId].name;
        image.description = string(abi.encodePacked("Crypto Membership NFT - ", image.name, " Plan"));
        image.imageURI = planDefaultImages[_newPlanId];

        if (!isOwnerUpgrading) {
            (uint256 ownerShare, uint256 feeShare, uint256 fundShare, uint256 uplineShare) = 
                FinanceLib.distributeFunds(priceDifference, _newPlanId);

            state.ownerBalance += ownerShare;
            state.feeSystemBalance += feeShare;
            state.fundBalance += fundShare;

            _handleUplinePayment(upline, uplineShare);
            
            GrowthCommissionLib.CommissionParams memory upgradeParams = GrowthCommissionLib.CommissionParams({
                newMember: msg.sender,
                planId: _newPlanId,
                ownerBalance: state.ownerBalance,
                owner: owner()
            });
            
            (, uint256 newOwnerBalance) = GrowthCommissionLib.processCommission(
                growthCommission, members, plans, upgradeParams, usdtToken
            );
            state.ownerBalance = newOwnerBalance;
            
            emit FundsDistributed(ownerShare, feeShare, fundShare);
        }

        emit PlanUpgraded(msg.sender, oldPlanId, _newPlanId);
    }

    function _setTokenImage(uint256 tokenId, uint256 planId) private {
        string memory name = plans[planId].name;
        string memory description = msg.sender == owner() && members[msg.sender].planId == 0
            ? string(abi.encodePacked("Crypto Membership NFT - ", name, " Plan (ROOT ACCESS)"))
            : string(abi.encodePacked("Crypto Membership NFT - ", name, " Plan"));
        
        tokenImages[tokenId] = NFTImage(planDefaultImages[planId], name, description, planId, block.timestamp);
    }

    function _handleUplinePayment(address _upline, uint256 _uplineShare) internal {
        if (_upline == address(0)) {
            state.ownerBalance += _uplineShare;
            return;
        }
        
        if (_upline == owner() && members[_upline].planId == 0) {
            _payReferralCommission(msg.sender, _upline, _uplineShare);
            members[_upline].totalReferrals++;
            return;
        }
        
        if (members[_upline].planId < members[msg.sender].planId) {
            state.ownerBalance += _uplineShare;
            return;
        }
        
        _payReferralCommission(msg.sender, _upline, _uplineShare);
        members[_upline].totalReferrals++;
    }

    function _payReferralCommission(address _from, address _to, uint256 _amount) internal noReentrantTransfer {
        usdtToken.safeTransfer(_to, _amount);
        members[_to].totalEarnings += _amount;
        state.totalCommissionPaid += _amount;
        emit ReferralPaid(_from, _to, _amount);
    }

    function exitMembership() external nonReentrant whenNotPaused onlyMember {
        if (msg.sender == owner()) revert ContractErrors.InvalidRequest();
        
        MembershipLib.Member storage member = members[msg.sender];
        if (block.timestamp <= member.registeredAt + 30 days) revert ContractErrors.ThirtyDayLock();

        uint256 refundAmount = (plans[member.planId].price * 30) / 100;
        if (state.fundBalance < refundAmount) revert ContractErrors.LowFundBalance();

        state.fundBalance -= refundAmount;
        uint256 tokenId = tokenOfOwnerByIndex(msg.sender, 0);
        delete tokenImages[tokenId];
        _burn(tokenId);
        delete members[msg.sender];

        usdtToken.safeTransfer(msg.sender, refundAmount);
        emit MemberExited(msg.sender, refundAmount);
    }

    // Growth Commission Functions
    function getGrowthCommissionStats(address leader) external view returns (GrowthCommissionLib.GrowthCommissionStats memory) {
        return growthCommission.stats[leader];
    }

    function checkMilestoneEligibility(address member) external view returns (bool eligible, address milestoneLeader) {
        milestoneLeader = GrowthCommissionLib.findMilestoneLeader(members, member, owner());
        eligible = milestoneLeader != address(0);
    }

    function setGrowthCommissionRate(uint256 planId, uint256 rate) external onlyOwner {
        GrowthCommissionLib.setRate(growthCommission, planId, rate);
    }

    function updateGrowthCommissionStatus(bool enabled) external onlyOwner {
        GrowthCommissionLib.setStatus(growthCommission, enabled);
    }

    // Admin Functions (using AdminLib)
    function withdrawOwnerBalance(uint256 amount) external onlyOwner nonReentrant noReentrantTransfer {
        if (amount > state.ownerBalance) revert ContractErrors.LowOwnerBalance();
        state.ownerBalance -= amount;
        usdtToken.safeTransfer(owner(), amount);
    }

    function withdrawFeeSystemBalance(uint256 amount) external onlyOwner nonReentrant noReentrantTransfer {
        if (amount > state.feeSystemBalance) revert ContractErrors.LowFeeBalance();
        state.feeSystemBalance -= amount;
        usdtToken.safeTransfer(owner(), amount);
    }

    function batchWithdraw(AdminLib.WithdrawalRequest[] calldata requests) external onlyOwner nonReentrant noReentrantTransfer {
        (uint256 newOwnerBalance, uint256 newFeeBalance, uint256 newFundBalance) = AdminLib.processBatchWithdraw(
            usdtToken, requests, state.ownerBalance, state.feeSystemBalance, state.fundBalance
        );
        
        state.ownerBalance = newOwnerBalance;
        state.feeSystemBalance = newFeeBalance;
        state.fundBalance = newFundBalance;
    }

    function emergencyWithdraw() external onlyOwner nonReentrant noReentrantTransfer {
        uint256 withdrawnAmount = AdminLib.processEmergencyWithdraw(
            usdtToken, owner(), state.emergencyWithdrawRequestTime, TIMELOCK_DURATION
        );
        
        state.ownerBalance = 0;
        state.feeSystemBalance = 0;
        state.fundBalance = 0;
        state.emergencyWithdrawRequestTime = 0;
        
        emit EmergencyWithdraw(owner(), withdrawnAmount);
    }

    function requestEmergencyWithdraw() external onlyOwner {
        state.emergencyWithdrawRequestTime = block.timestamp;
        emit EmergencyWithdrawRequested(block.timestamp);
    }

    function setPaused(bool _paused) external onlyOwner {
        state.paused = _paused;
        emit ContractPaused(_paused);
    }

    // View Functions (using ViewLib)
    function getSystemStats() external view returns (uint256 totalMembers, uint256 totalRevenue, uint256 totalCommission, uint256 ownerFunds, uint256 feeFunds, uint256 fundFunds) {
        return ViewLib.getSystemStats(
            totalSupply(),
            state.ownerBalance,
            state.feeSystemBalance,
            state.fundBalance,
            state.totalCommissionPaid,
            growthCommission.totalPaid
        );
    }

    function getContractStatus() external view returns (bool isPaused, uint256 totalBalance, uint256 memberCount, uint256 currentPlanCount, bool hasEmergencyRequest, uint256 emergencyTimeRemaining) {
        return ViewLib.getContractStatus(
            state.paused,
            usdtToken,
            totalSupply(),
            state.planCount,
            state.emergencyWithdrawRequestTime,
            TIMELOCK_DURATION
        );
    }

    function getPlanInfo(uint256 _planId) external view returns (uint256 price, string memory name, uint256 membersPerCycle, bool isActive, string memory imageURI) {
        return ViewLib.getPlanInfo(plans, planDefaultImages, _planId, state.planCount);
    }

    function validateContractBalance() public view returns (bool, uint256, uint256) {
        return ViewLib.validateContractBalance(usdtToken, state.ownerBalance, state.feeSystemBalance, state.fundBalance);
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        if (!_exists(_tokenId)) revert ContractErrors.NonexistentToken();
        NFTImage memory image = tokenImages[_tokenId];
        
        address tokenOwner = ownerOf(_tokenId);
        string memory displayPlanId = tokenOwner == owner() && members[tokenOwner].planId == 0 
            ? "ROOT (All Plans)" 
            : NFTMetadataLib.uint2str(image.planId);
        
        return string(abi.encodePacked(
            "data:application/json;base64,",
            NFTMetadataLib.base64Encode(abi.encodePacked(
                '{"name":"', image.name,
                '","description":"', image.description, " Non-transferable NFT.",
                '","image":"', image.imageURI,
                '","attributes":[{"trait_type":"Plan Level","value":"', displayPlanId,
                '"},{"trait_type":"Transferable","value":"No"}]}'
            ))
        ));
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }
}
