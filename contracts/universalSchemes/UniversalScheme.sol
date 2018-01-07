pragma solidity ^0.4.15;

import "./UniversalSchemeInterface.sol";
import "../controller/ControllerInterface.sol";
import "../controller/Avatar.sol";
import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "zeppelin-solidity/contracts/token/StandardToken.sol";


contract UniversalScheme is Ownable, UniversalSchemeInterface { //
    StandardToken public nativeToken;
    uint public fee;
    address public beneficiary;
    bytes32 public hashedParameters; // For other parameters.

    // A mapping from the organization (Avatar) address to the rergistration boolean
    mapping(address=>bool) public organizations;

    event OrganizationRegistered (address _avatar);
    event LogNewProposal(bytes32 proposalId);

    modifier onlyRegisteredOrganization(address avatar) {
        require(organizations[avatar]);
        _;
    }

    function registerOrganization(Avatar _avatar) public {
        // Pay fees for using scheme:
        if ((fee > 0) && (! organizations[_avatar])) {
            nativeToken.transferFrom(_avatar, beneficiary, fee);
        }
        organizations[_avatar] = true;
        OrganizationRegistered(_avatar);
    }

    function isRegistered(address _avatar) public constant returns(bool) {
        return organizations[_avatar];
    }

    function updateParameters(
        StandardToken _nativeToken,
        uint _fee,
        address _beneficiary,
        bytes32 _hashedParameters
    )
        public
        onlyOwner
    {
        nativeToken = _nativeToken;
        fee = _fee;
        beneficiary = _beneficiary;
        hashedParameters = _hashedParameters;
    }

    /**
    *  @dev get the parameters for the current scheme from the controller
    */
    function getParametersFromController(Avatar _avatar) internal constant returns(bytes32) {
        return ControllerInterface(_avatar.owner()).getSchemeParameters(this,address(_avatar));
    }

}
