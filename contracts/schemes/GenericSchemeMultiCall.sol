pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

import "@daostack/infra/contracts/votingMachines/IntVoteInterface.sol";
import "@daostack/infra/contracts/votingMachines/ProposalExecuteInterface.sol";
import "../votingMachines/VotingMachineCallbacks.sol";

/**
 * @title GenericSchemeMulticall.
 * @dev  A scheme for proposing and executing one/multiple calls to or or multiple arbitrary functions
 * on contracts on behalf of the organization avatar.
 */
contract GenericSchemeMulticall is VotingMachineCallbacks, ProposalExecuteInterface {
    event NewMultiCallProposal(
        address indexed _avatar,
        bytes32 indexed _proposalId,
        bytes[]   _callData,
        uint256[] _value,
        string  _descriptionHash,
        address[] _contractsToCall
    );

    event ProposalExecuted(
        address indexed _avatar,
        bytes32 indexed _proposalId
    );

    event ProposalCallExecuted(
        address indexed _avatar,
        bytes32 indexed _proposalId,
        address _contractToCall,
        bytes _callDataReturnValue
    );

    event ProposalExecutedByVotingMachine(
        address indexed _avatar,
        bytes32 indexed _proposalId,
        int256 _param
    );

    event ProposalDeleted(address indexed _avatar, bytes32 indexed _proposalId);

    // Details of a voting proposal:
    struct MultiCallProposal {
        address[] contractsToCall;
        bytes[] callData;
        uint256[] value;
        bool exist;
        bool passed;
    }

    mapping(bytes32=>MultiCallProposal) public proposals;

    IntVoteInterface public votingMachine;
    bytes32 public voteParams;
    Avatar public avatar;

    /**
     * @dev initialize
     * @param _avatar the avatar to mint reputation from
     * @param _votingMachine the voting machines address to
     * @param _voteParams voting machine parameters.
     */
    function initialize(
        Avatar _avatar,
        IntVoteInterface _votingMachine,
        bytes32 _voteParams
    )
    external
    {
        require(avatar == Avatar(0), "can be called only one time");
        require(_avatar != Avatar(0), "avatar cannot be zero");
        avatar = _avatar;
        votingMachine = _votingMachine;
        voteParams = _voteParams;
    }

    /**
    * @dev execution of proposals, can only be called by the voting machine in which the vote is held.
    * @param _proposalId the ID of the voting in the voting machine
    * @param _decision a parameter of the voting result, 1 yes and 2 is no.
    * @return bool success
    */
    function executeProposal(bytes32 _proposalId, int256 _decision)
    external
    onlyVotingMachine(_proposalId)
    returns(bool) {
        MultiCallProposal storage proposal = proposals[_proposalId];
        require(proposal.exist, "must be a live proposal");
        require(proposal.passed == false, "cannot execute twice");

        if (_decision == 1) {
            proposal.passed = true;
            execute(_proposalId);
        } else {
            delete proposals[_proposalId];
            emit ProposalDeleted(address(avatar), _proposalId);
        }

        emit ProposalExecutedByVotingMachine(address(avatar), _proposalId, _decision);
        return true;
    }

    /**
    * @dev execution of proposals after it has been decided by the voting machine
    * @param _proposalId the ID of the voting in the voting machine
    */
    function execute(bytes32 _proposalId) public {
        MultiCallProposal storage proposal = proposals[_proposalId];
        require(proposal.exist, "must be a live proposal");
        require(proposal.passed, "proposal must passed by voting machine");
        proposal.exist = false;
        bytes memory genericCallReturnValue;
        bool success;
        Controller controller = Controller(avatar.owner());

        for (uint i = 0; i < proposal.contractsToCall.length; i ++) {
            (success, genericCallReturnValue) =
            controller.genericCall(proposal.contractsToCall[i], proposal.callData[i], avatar, proposal.value[i]);
            /* All transactions must be successfull otherwise the whole proposal transaction will be reverted*/
            require(success, "Proposal call failed");
            emit ProposalCallExecuted(address(avatar), _proposalId, proposal.contractsToCall[i], genericCallReturnValue);
        }

        delete proposals[_proposalId];
        emit ProposalDeleted(address(avatar), _proposalId);
        emit ProposalExecuted(address(avatar), _proposalId);

    }

    /**
    * @dev propose to call one or multiple contracts on behalf of the _avatar
    *      The function trigger NewMultiCallProposal event
    * @param _contractsToCall the contracts to be called 
    * @param _callData - The abi encode data for the calls
    * @param _value value(ETH) to transfer with the calls
    * @param _descriptionHash proposal description hash
    * @return an id which represents the proposal
    */

    function proposeCalls(address[] memory _contractsToCall, bytes[] memory _callData, uint256[] memory _value, string memory _descriptionHash)
    public
    returns(bytes32 proposalId)
    {
        require(
            (_contractsToCall.length == _callData.length) && (_contractsToCall.length == _value.length),
            "Wrong length of _contractsToCall, _callData or _value arrays"
        );
        proposalId = votingMachine.propose(2, voteParams, msg.sender, address(avatar));

        proposals[proposalId] = MultiCallProposal({
            contractsToCall: _contractsToCall,
            callData: _callData,
            value: _value,
            exist: true,
            passed: false
        });
        proposalsInfo[address(votingMachine)][proposalId] = ProposalInfo({
            blockNumber:block.number,
            avatar:avatar
        });

        emit NewMultiCallProposal(address(avatar), proposalId, _callData, _value, _descriptionHash, _contractsToCall);

    }

}