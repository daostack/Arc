pragma solidity ^0.5.17;

import "@daostack/infra-experimental/contracts/votingMachines/IntVoteInterface.sol";
import "@daostack/infra-experimental/contracts/votingMachines/ProposalExecuteInterface.sol";
import "../votingMachines/VotingMachineCallbacks.sol";

/**
 * @title A scheme to manage the upgrade of an organization.
 * @dev The scheme is used to upgrade the controller of an organization to a new controller.
 */

contract ControllerUpgradeScheme is VotingMachineCallbacks, ProposalExecuteInterface {

    event NewControllerUpgradeProposal(
        address indexed _avatar,
        bytes32 indexed _proposalId,
        address indexed _intVoteInterface,
        address _newController,
        string _descriptionHash
    );

    event ChangeControllerUpgradeSchemeProposal(
        address indexed _avatar,
        bytes32 indexed _proposalId,
        address indexed _intVoteInterface,
        address _newControllerUpgradeScheme,
        string _descriptionHash
    );

    event ProposalExecuted(address indexed _avatar, bytes32 indexed _proposalId, int256 _param);
    event ProposalDeleted(address indexed _avatar, bytes32 indexed _proposalId);

    // Details of an upgrade proposal:
    struct UpgradeProposal {
        address upgradeContract; // Either the new controller we upgrade to, or the new upgrading scheme.
        uint256 proposalType; // 1: Upgrade controller, 2: change upgrade scheme.
    }

    mapping(bytes32=>UpgradeProposal) public organizationProposals;

    IntVoteInterface public votingMachine;
    bytes32 public voteParamsHash;

    /**
     * @dev initialize
     * @param _avatar the avatar this scheme referring to.
     * @param _votingMachine the voting machines address to
     * @param _votingParams genesisProtocol parameters - valid only if _voteParamsHash is zero
     * @param _voteOnBehalf genesisProtocol parameter - valid only if _voteParamsHash is zero
     * @param _voteParamsHash voting machine parameters.
     */
    function initialize(
        Avatar _avatar,
        IntVoteInterface _votingMachine,
        uint256[11] calldata _votingParams,
        address _voteOnBehalf,
        bytes32 _voteParamsHash
    )
    external
    {
        super._initialize(_avatar);
        votingMachine = _votingMachine;
        if (_voteParamsHash == bytes32(0)) {
            //genesisProtocol
            GenesisProtocol genesisProtocol = GenesisProtocol(address(_votingMachine));
            voteParamsHash = genesisProtocol.getParametersHash(_votingParams, _voteOnBehalf);
            (uint256 queuedVoteRequiredPercentage, , , , , , , , , , , ,) =
            genesisProtocol.parameters(voteParamsHash);
            if (queuedVoteRequiredPercentage == 0) {
               //params not set already
                genesisProtocol.setParameters(_votingParams, _voteOnBehalf);
            }
        } else {
            //for other voting machines
            voteParamsHash = _voteParamsHash;
        }
    }

    /**
    * @dev execution of proposals, can only be called by the voting machine in which the vote is held.
    * @param _proposalId the ID of the voting in the voting machine
    * @param _param a parameter of the voting result, 1 yes and 2 is no.
    */
    function executeProposal(bytes32 _proposalId, int256 _param) external onlyVotingMachine(_proposalId) returns(bool) {
        UpgradeProposal memory proposal = organizationProposals[_proposalId];
        require(proposal.proposalType != 0);
        delete organizationProposals[_proposalId];
        emit ProposalDeleted(address(avatar), _proposalId);
        // Check if vote was successful:
        if (_param == 1) {

        // Define controller and get the params:
            Controller controller = Controller(avatar.owner());
        // Upgrading controller:
            if (proposal.proposalType == 1) {
                require(controller.upgradeController(proposal.upgradeContract));
            }

        // Changing upgrade scheme:
            if (proposal.proposalType == 2) {
                bytes4 permissions = controller.schemesPermissions(address(this));
                require(
                controller.registerScheme(proposal.upgradeContract, permissions)
                );
                if (proposal.upgradeContract != address(this)) {
                    require(controller.unregisterSelf());
                }
            }
        }
        emit ProposalExecuted(address(avatar), _proposalId, _param);
        return true;
    }

    /**
    * @dev propose an upgrade of the organization's controller
    * @param _newController address of the new controller that is being proposed
    * @param _descriptionHash proposal description hash
    * @return an id which represents the proposal
    */
    function proposeUpgrade(address _newController, string memory _descriptionHash)
        public
        returns(bytes32)
    {
        bytes32 proposalId = votingMachine.propose(2, voteParamsHash, msg.sender, address(avatar));
        UpgradeProposal memory proposal = UpgradeProposal({
            proposalType: 1,
            upgradeContract: _newController
        });
        organizationProposals[proposalId] = proposal;
        emit NewControllerUpgradeProposal(
        address(avatar),
        proposalId,
        address(votingMachine),
        _newController,
        _descriptionHash
        );

        proposalsBlockNumber[address(votingMachine)][proposalId] = block.number;

        return proposalId;
    }

    /**
    * @dev propose to replace this scheme by another controller upgrading scheme
    * @param _scheme address of the new upgrading scheme
    * @param _descriptionHash proposal description hash
    * @return an id which represents the proposal
    */
    function proposeChangeControllerUpgradingScheme(
        address _scheme,
        string memory _descriptionHash
    )
        public
        returns(bytes32)
    {
        bytes32 proposalId = votingMachine.propose(2, voteParamsHash, msg.sender, address(avatar));
        require(organizationProposals[proposalId].proposalType == 0);

        UpgradeProposal memory proposal = UpgradeProposal({
            proposalType: 2,
            upgradeContract: _scheme
        });
        organizationProposals[proposalId] = proposal;

        emit ChangeControllerUpgradeSchemeProposal(
            address(avatar),
            proposalId,
            address(votingMachine),
            _scheme,
            _descriptionHash
        );

        proposalsBlockNumber[address(votingMachine)][proposalId] = block.number;

        return proposalId;
    }
}
