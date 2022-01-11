// SPDX-License-Identifier: MIT

pragma solidity >=0.7.5;
pragma abicoder v2;

import './DAFToken.sol';
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

contract DAFVoting {

    using EnumerableSet for EnumerableSet.UintSet;

    DAFToken daf;
    uint256 constant public PROPOSAL_EXPIRY = 1 days;

    mapping(uint256 => Proposal) public proposalMap;
    uint256 public proposalCount;

    struct Proposal {
        address creator; // Creator of this proposal
        uint256 endDate; // timestamp for when voting closes on proposal
        uint256 voteCount; // the current vote count in terms of num tokens for proposal
        uint256 snapshotId; // ID of the snapshot of balances for the token, taken at proposal creation
        DAFToken.Holding holding;
        bool executed;
        mapping (address => Vote) votesBySubmitter; // map of votes submitted for proposal by submitter
    }

    struct Vote {
        bool hasVoted; // to track whether a token holder has already voted
        uint256 voteCount; // amount this voter voted in favour of proposal
    }

    event ProposalCreated (
        uint256 proposalId
    );

    constructor(address _dafAddr) {
        daf = DAFToken(_dafAddr);
    }

    function createProposal(DAFToken.Holding memory _holding) external {
        require(daf.checkValidHoldingChange(_holding), "Proposed holding is invalid");
        proposalMap[proposalCount].creator = msg.sender;
        proposalMap[proposalCount].endDate = block.timestamp + PROPOSAL_EXPIRY;
        proposalMap[proposalCount].snapshotId = daf.snapshot();
        proposalMap[proposalCount].holding = _holding;

        emit ProposalCreated(proposalCount);

        proposalCount++;
    }

    //TODO: Look at a way to do this with signatures
    //'Dumb' voting for now, simply add to vote count, till majority to pass, assumed only 'for'
    function voteForProposal(uint256 _proposalId) external {
        require(proposalMap[_proposalId].endDate != 0, "Proposal does not exist");
        require(block.timestamp < proposalMap[_proposalId].endDate, "Proposal has expired");
        require(!proposalMap[_proposalId].votesBySubmitter[msg.sender].hasVoted, "Already voted on this proposal");
        uint256 bal = daf.balanceOfAt(msg.sender, proposalMap[_proposalId].snapshotId);
        require(bal > 0, "Sender had no tokens at proposal creation");

        proposalMap[_proposalId].votesBySubmitter[msg.sender].hasVoted = true;
        proposalMap[_proposalId].votesBySubmitter[msg.sender].voteCount = bal;
        proposalMap[_proposalId].voteCount += bal;
    }

    function senderHasVoted(uint256 _proposalId) external view returns (bool) {
        return proposalMap[_proposalId].votesBySubmitter[msg.sender].hasVoted;
    }

    function executeProposal(uint256 _proposalId) external {
        require(proposalMap[_proposalId].endDate != 0, "Proposal does not exist");
        require(!proposalMap[_proposalId].executed, "Proposal has already been executed");
        require(proposalMap[_proposalId].voteCount >= (daf.totalSupplyAt(proposalMap[_proposalId].snapshotId) / 2), "Proposal has not passed");
        require(daf.checkValidHoldingChange(proposalMap[_proposalId].holding), "Holding change is no longer valid");

        daf.changeHolding(proposalMap[_proposalId].holding);
        proposalMap[_proposalId].executed = true;
    }

    //TODO: Intended to be a way for the holders to express how they feel about each holding,
    //should then be used to buy more shares of the positive holdings and sell off some negative holdings
    //TODO: Look at a way to do this with signatures
    function giveHoldingFeedback() external {
        
    }
}