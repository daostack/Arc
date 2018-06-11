pragma solidity ^0.4.24;

import "../controller/Reputation.sol";
import "./IntVoteInterface.sol";


contract AbsoluteVote is IntVoteInterface {
    using SafeMath for uint;


    struct Parameters {
        Reputation reputationSystem; // the reputation system that is being used
        uint precReq; // how many percentages required for the proposal to be passed
        bool allowOwner; // does this proposal has an owner who has owner rights?
    }

    struct Voter {
        uint vote; // 0 - 'abstain'
        uint reputation; // amount of voter's reputation
    }

    struct Proposal {
        address owner; // the proposal's owner
        address avatar; // the avatar of the organization that owns the proposal
        uint numOfChoices;
        ExecutableInterface executable; // will be executed if the proposal will pass
        bytes32 paramsHash; // the hash of the parameters of the proposal
        uint totalVotes;
        mapping(uint=>uint) votes;
        mapping(address=>Voter) voters;
        bool open; // voting open flag
    }

    event VoteProposal(bytes32 indexed _proposalId, address indexed _avatar, address indexed _voter, uint _vote, uint _reputation, bool _isOwnerVote);
    event RefreshReputation(bytes32 indexed _proposalId, address indexed _avatar, address indexed _voter,uint _reputation);


    mapping(bytes32=>Parameters) public parameters;  // A mapping from hashes to parameters
    mapping(bytes32=>Proposal) public proposals; // Mapping from the ID of the proposal to the proposal itself.

    uint public constant MAX_NUM_OF_CHOICES = 10;
    uint public proposalsCnt; // Total amount of proposals

  /**
   * @dev Check that there is owner for the proposal and he sent the transaction
   */
    modifier onlyProposalOwner(bytes32 _proposalId) {
        require(msg.sender == proposals[_proposalId].owner);
        _;
    }

  /**
   * @dev Check that the proposal is votable (open and not executed yet)
   */
    modifier votable(bytes32 _proposalId) {
        require(proposals[_proposalId].open);
        _;
    }

    /**
     * @dev register a new proposal with the given parameters. Every proposal has a unique ID which is being
     * generated by calculating keccak256 of a incremented counter.
     * @param _numOfChoices number of voting choices
     * @param _paramsHash defined the parameters of the voting machine used for this proposal
     * @param _avatar an address to be sent as the payload to the _executable contract.
     * @param _executable This contract will be executed when vote is over.
     * @return proposal's id.
     */
    function propose(uint _numOfChoices, bytes32 _paramsHash, address _avatar, ExecutableInterface _executable,address)
        external
        returns(bytes32)
    {
        // Check valid params and number of choices:
        require(parameters[_paramsHash].reputationSystem != address(0));
        require(_numOfChoices > 0 && _numOfChoices <= MAX_NUM_OF_CHOICES);
        // Generate a unique ID:
        bytes32 proposalId = keccak256(abi.encodePacked(this, proposalsCnt));
        proposalsCnt++;
        // Open proposal:
        Proposal memory proposal;
        proposal.numOfChoices = _numOfChoices;
        proposal.paramsHash = _paramsHash;
        proposal.avatar = _avatar;
        proposal.executable = _executable;
        proposal.owner = msg.sender;
        proposal.open = true;
        proposals[proposalId] = proposal;
        emit NewProposal(proposalId, _avatar, _numOfChoices, msg.sender, _paramsHash);
        return proposalId;
    }

  /**
   * @dev Cancel a proposal, only the owner can call this function and only if allowOwner flag is true.
   * @param _proposalId the proposal ID
   */
    function cancelProposal(bytes32 _proposalId) external onlyProposalOwner(_proposalId) votable(_proposalId) returns(bool) {
        if (! parameters[proposals[_proposalId].paramsHash].allowOwner) {
            return false;
        }
        address avatar = proposals[_proposalId].avatar;
        deleteProposal(_proposalId);
        emit CancelProposal(_proposalId, avatar);
        return true;
    }

  /**
   * @dev voting function
   * @param _proposalId id of the proposal
   * @param _vote a value between 0 to and the proposal number of choices.
   * @return bool true - the proposal has been executed
   *              false - otherwise.
   */
    function vote(bytes32 _proposalId, uint _vote) external votable(_proposalId) returns(bool) {
        return internalVote(_proposalId, msg.sender, _vote, 0);
    }

  /**
   * @dev voting function with owner functionality (can vote on behalf of someone else)
   * @param _proposalId id of the proposal
   * @param _vote a value between 0 to and the proposal number of choices.
   * @param _voter will be voted with that voter's address
   * @return bool true - the proposal has been executed
   *              false - otherwise.
   */
    function ownerVote(bytes32 _proposalId, uint _vote, address _voter)
        external
        onlyProposalOwner(_proposalId)
        votable(_proposalId)
        returns(bool)
    {
        if (! parameters[proposals[_proposalId].paramsHash].allowOwner) {
            return false;
        }
        return  internalVote(_proposalId, _voter, _vote, 0);
    }

    function voteWithSpecifiedAmounts(bytes32 _proposalId,uint _vote,uint _rep,uint) external votable(_proposalId) returns(bool) {
        return internalVote(_proposalId,msg.sender,_vote,_rep);
    }

  /**
   * @dev Cancel the vote of the msg.sender: subtract the reputation amount from the votes
   * and delete the voter from the proposal struct
   * @param _proposalId id of the proposal
   */
    function cancelVote(bytes32 _proposalId) external votable(_proposalId) {
        cancelVoteInternal(_proposalId, msg.sender);
    }

  /**
   * @dev getNumberOfChoices returns the number of choices possible in this proposal
   * @param _proposalId the ID of the proposal
   * @return uint that contains number of choices
   */
    function getNumberOfChoices(bytes32 _proposalId) external view returns(uint) {
        return proposals[_proposalId].numOfChoices;
    }

  /**
   * @dev voteInfo returns the vote and the amount of reputation of the user committed to this proposal
   * @param _proposalId the ID of the proposal
   * @param _voter the address of the voter
   * @return uint vote - the voters vote
   *        uint reputation - amount of reputation committed by _voter to _proposalId
   */
    function voteInfo(bytes32 _proposalId, address _voter) external view returns(uint, uint) {
        Voter memory voter = proposals[_proposalId].voters[_voter];
        return (voter.vote, voter.reputation);
    }

    /**
     * @dev voteStatus returns the reputation voted for a proposal for a specific voting choice.
     * @param _proposalId the ID of the proposal
     * @param _choice the index in the
     * @return voted reputation for the given choice
     */
    function voteStatus(bytes32 _proposalId,uint _choice) external view returns(uint) {
        return proposals[_proposalId].votes[_choice];
    }

    /**
      * @dev isVotable check if the proposal is votable
      * @param _proposalId the ID of the proposal
      * @return bool true or false
    */
    function isVotable(bytes32 _proposalId) external view returns(bool) {
        return  proposals[_proposalId].open;
    }

    /**
     * @dev isAbstainAllow returns if the voting machine allow abstain (0)
     * @return bool true or false
     */
    function isAbstainAllow() external pure returns(bool) {
        return true;
    }

    /**
     * @dev refreshReputation refresh the reputation for a given voters list
     * @param _proposalId the ID of the proposal
     * @param _voters list to be refreshed
     * @return bool true or false
     */
    function refreshReputation(bytes32 _proposalId, address[] _voters) external returns(bool) {
        Proposal storage proposal = proposals[_proposalId];
        Parameters memory params = parameters[proposal.paramsHash];

        for (uint i = 0; i < _voters.length; i++) {
            Voter storage voter = proposal.voters[_voters[i]];
             //check that the voters already votes.
            if (voter.reputation > 0) {
                //update only if there is a mismatch between the voter's system reputation
                //and the reputation stored in the voting machine for the voter.
                uint rep = params.reputationSystem.reputationOf(_voters[i]);
                if (rep > voter.reputation) {
                    proposal.votes[voter.vote] = proposal.votes[voter.vote].add(rep - voter.reputation);
                    proposal.totalVotes = (proposal.totalVotes).add(rep - voter.reputation);
                  } else if (rep < voter.reputation) {
                    proposal.votes[voter.vote] = proposal.votes[voter.vote].sub(voter.reputation - rep);
                    proposal.totalVotes = (proposal.totalVotes).sub(voter.reputation - rep);
                  }
                if (rep != voter.reputation) {
                    voter.reputation = rep;
                    emit RefreshReputation(_proposalId, proposal.avatar, _voters[i],rep);
                }
             }
        }
        return true;
    }

    /**
     * @dev getAllowedRangeOfChoices returns the allowed range of choices for a voting machine.
     * @return min - minimum number of choices
               max - maximum number of choices
     */
    function getAllowedRangeOfChoices() external pure returns(uint min,uint max) {
        return (1,MAX_NUM_OF_CHOICES);
    }

    /**
      * @dev execute check if the proposal has been decided, and if so, execute the proposal
      * @param _proposalId the id of the proposal
      * @return bool true - the proposal has been executed
      *              false - otherwise.
     */
    function execute(bytes32 _proposalId) public votable(_proposalId) returns(bool) {
        Proposal storage proposal = proposals[_proposalId];
        Reputation reputation = parameters[proposal.paramsHash].reputationSystem;
        require(reputation != address(0));
        uint totalReputation = reputation.totalSupply();
        uint precReq = parameters[proposal.paramsHash].precReq;
        // Check if someone crossed the bar:
        for (uint cnt = 0; cnt <= proposal.numOfChoices; cnt++) {
            if (proposal.votes[cnt] > totalReputation*precReq/100) {
                Proposal memory tmpProposal = proposal;
                deleteProposal(_proposalId);
                emit ExecuteProposal(_proposalId, tmpProposal.avatar, cnt, totalReputation);
                (tmpProposal.executable).execute(_proposalId, tmpProposal.avatar, int(cnt));
                return true;
            }
        }
        return false;
    }

    /**
     * @dev hash the parameters, save them if necessary, and return the hash value
    */
    function setParameters(Reputation _reputationSystem, uint _precReq, bool _allowOwner) public returns(bytes32) {
        require(_precReq <= 100 && _precReq > 0);
        bytes32 hashedParameters = getParametersHash(_reputationSystem, _precReq, _allowOwner);
        parameters[hashedParameters] = Parameters({
            reputationSystem: _reputationSystem,
            precReq: _precReq,
            allowOwner: _allowOwner
        });
        return hashedParameters;
    }

    /**
     * @dev hashParameters returns a hash of the given parameters
     */
    function getParametersHash(Reputation _reputationSystem, uint _precReq, bool _allowOwner) public pure returns(bytes32) {
        return keccak256(abi.encodePacked(_reputationSystem, _precReq, _allowOwner));
    }

    function cancelVoteInternal(bytes32 _proposalId, address _voter) internal {
        Proposal storage proposal = proposals[_proposalId];
        Voter memory voter = proposal.voters[_voter];
        proposal.votes[voter.vote] = (proposal.votes[voter.vote]).sub(voter.reputation);
        proposal.totalVotes = (proposal.totalVotes).sub(voter.reputation);
        delete proposal.voters[_voter];
        emit CancelVoting(_proposalId, proposal.avatar, _voter);
    }

    function deleteProposal(bytes32 _proposalId) internal {
        Proposal storage proposal = proposals[_proposalId];
        for (uint cnt = 0; cnt <= proposal.numOfChoices; cnt++) {
            delete proposal.votes[cnt];
        }
        delete proposals[_proposalId];
    }

    /**
     * @dev Vote for a proposal, if the voter already voted, cancel the last vote and set a new one instead
     * @param _proposalId id of the proposal
     * @param _voter used in case the vote is cast for someone else
     * @param _vote a value between 0 to and the proposal's number of choices.
     * @return true in case of proposal execution otherwise false
     * throws if proposal is not open or if it has been executed
     * NB: executes the proposal if a decision has been reached
     */
    function internalVote(bytes32 _proposalId, address _voter, uint _vote, uint _rep) private returns(bool) {
        Proposal storage proposal = proposals[_proposalId];
        Parameters memory params = parameters[proposal.paramsHash];
        // Check valid vote:
        require(_vote <= proposal.numOfChoices);
        // Check voter has enough reputation:
        uint reputation = params.reputationSystem.reputationOf(_voter);
        require(reputation >= _rep);
        uint rep = _rep;
        if (rep == 0) {
            rep = reputation;
        }
        // If this voter has already voted, first cancel the vote:
        if (proposal.voters[_voter].reputation != 0) {
            cancelVoteInternal(_proposalId, _voter);
        }
        // The voting itself:
        proposal.votes[_vote] = rep.add(proposal.votes[_vote]);
        proposal.totalVotes = rep.add(proposal.totalVotes);
        proposal.voters[_voter] = Voter({
            reputation: rep,
            vote: _vote
        });
        // Event:
        emit VoteProposal(_proposalId, proposal.avatar, _voter, _vote, reputation, (_voter != msg.sender));
        // execute the proposal if this vote was decisive:
        return execute(_proposalId);
    }
}
