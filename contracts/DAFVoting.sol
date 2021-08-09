// SPDX-License-Identifier: MIT

pragma solidity >=0.7.5;
pragma abicoder v2;

import './DAFToken.sol';
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

contract DAFVoting {

    using EnumerableSet for EnumerableSet.UintSet;

    DAFToken daf;
    uint256 constant public PROPOSAL_EXPIRY = 60; // Time in secs when a proposal expires

    EnumerableSet.UintSet private proposalSet;
    mapping(uint256 => Proposal) public proposalMap;

    struct NewHoldingProposal {
        DAFToken.Holding newHolding;
        Proposal prop;
    }

    struct LiquidateHoldingProposal {
        uint256 holdingId;
        Proposal prop;
    }

    enum ProposalType {
        newHolding,
        liquidateHolding
    }

    struct Proposal {
        address creator; // Creator of this proposal
        uint256 endDate; // timestamp for when voting closes on proposal, can be 0 (open ended)
        int16 voteCount; // the current vote count as a percent of supply
        uint256 snapshotId; // ID of the snapshot of balances for the token, taken at proposal creation
        mapping (address => Vote) votesBySubmitter; // map of votes submitted for proposal by submitter
        ProposalType propType;
        DAFToken.Holding holding;
        uint256 holdingId;
    }

    struct Vote {
        bool hasVoted; // to track whether a token holder has already voted
        int16 vote; // can be negative, represents token share (0 - 10000)
    }

    constructor(address _dafAddr) {
        daf = DAFToken(_dafAddr);
    }

    function proposeNewHolding(DAFToken.Holding memory _holding) external {
        // Proposal memory newProposal = Proposal({
        //     creator: msg.sender,
        //     endDate: block.timestamp + PROPOSAL_EXPIRY,
        //     voteCount: 0,
        //     snapshotId: snapshotId
        // });
    }

    function proposeLiquidateHolding(uint256 _holdingId) external {

    }

    //TODO: Look at a way to do this with signatures
    function voteOnProposal(uint256 _proposalId, bool _forProposal) external {

    }

    //TODO: Look at a way to do this with signatures
    function giveHoldingFeedback() external {
        
    }
}