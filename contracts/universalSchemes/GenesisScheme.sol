pragma solidity ^0.4.18;

import "../controller/DAOToken.sol";
import "../controller/Reputation.sol";
import "./UniversalScheme.sol";
import "../controller/UController.sol";
import "../controller/Controller.sol";


/**
 * @title Genesis Scheme that creates organizations
 */

contract GenesisScheme {

    mapping(address=>address) locks;

    event NewOrg (address _avatar);
    event InitialSchemesSet (address _avatar);

    address[] public addressArray = [address(this)];
    bytes32[] public bytes32Array = [bytes32(0)];
    //full permissions
    bytes4[]  public bytes4Array  = [bytes4(0xF)];

    function GenesisScheme() public {}


  /**
    * @dev Create a new organization
    * @param _orgName The name of the new organization
    * @param _tokenName The name of the token associated with the organization
    * @param _tokenSymbol The symbol of the token
    * @param _founders An array with the addresses of the founders of the organization
    * @param _foundersTokenAmount An array of amount of tokens that the founders
    *  receive in the new organization
    * @param _foundersReputationAmount An array of amount of reputation that the
    *   founders receive in the new organization
    * @param  _uController universal controller instance
    *         if _uController address equal to zero the organization will use none universal controller.
    * @return The address of the avatar of the controller
    */
    function forgeOrg (
        bytes32 _orgName,
        string _tokenName,
        string _tokenSymbol,
        address[] _founders,
        uint[] _foundersTokenAmount,
        int[] _foundersReputationAmount,
        UController _uController
      )
      external
      returns(address)
      {
        //The call for the private function is needed to bypass a deep stack issues
        return _forgeOrg(
            _orgName,
            _tokenName,
            _tokenSymbol,
            _founders,
            _foundersTokenAmount,
            _foundersReputationAmount,
            _uController);
    }

    /**
     * @dev Create a new organization
     * @param _orgName The name of the new organization
     * @param _tokenName The name of the token associated with the organization
     * @param _tokenSymbol The symbol of the token
     * @param _founders An array with the addresses of the founders of the organization
     * @param _foundersTokenAmount An array of amount of tokens that the founders
     *  receive in the new organization
     * @param _foundersReputationAmount An array of amount of reputation that the
     *   founders receive in the new organization
     * @param  _uController universal controller instance
     *         if _uController address equal to zero the organization will use none universal controller.
     * @return The address of the avatar of the controller
     */
    function _forgeOrg (
        bytes32 _orgName,
        string _tokenName,
        string _tokenSymbol,
        address[] _founders,
        uint[] _foundersTokenAmount,
        int[] _foundersReputationAmount,
        UController _uController
    ) private returns(address)
    {
        // Create Token, Reputation and Avatar:
        DAOToken  nativeToken = new DAOToken(_tokenName, _tokenSymbol);
        Reputation  nativeReputation = new Reputation();
        Avatar  avatar = new Avatar(_orgName, nativeToken, nativeReputation);
        ControllerInterface  controller;

        // Create Controller:
        if (UController(0) == _uController) {
            controller = new Controller(avatar,addressArray, bytes32Array, bytes4Array);
        } else {
            controller = _uController;
            _uController.newOrganization(avatar,addressArray, bytes32Array, bytes4Array);
        }
        // Transfer ownership:
        avatar.transferOwnership(controller);
        nativeToken.transferOwnership(controller);
        nativeReputation.transferOwnership(controller);

        // Mint token and reputation for founders:
        for (uint i = 0 ; i < _founders.length ; i++ ) {
            if (!controller.mintTokens(_foundersTokenAmount[i], _founders[i],address(avatar))) {
                revert();
            }
            if (!controller.mintReputation(_foundersReputationAmount[i], _founders[i],address(avatar))) {
                revert();
            }
        }

        locks[avatar] = msg.sender;

        NewOrg (address(avatar));
        return (address(avatar));
    }

     /**
      * @dev Set initial schemes for the organization.
      * @param _avatar organization avatar (returns from forgeOrg)
      * @param _schemes the schemes to register for the organization
      * @param _params the schemes's params
      * @param _permissions the schemes permissions.
      *        BIT_31 (0x80000000) indicate if this scheme is a universal scheme.
      */
    function setSchemes (
        Avatar _avatar,
        address[] _schemes,
        bytes32[] _params,
        bytes4[] _permissions
    )
        external
    {
        // this action can only be executed by the account that holds the lock
        // for this controller
        require(locks[address(_avatar)] == msg.sender);

        // register initial schemes:
        ControllerInterface controller = ControllerInterface(_avatar.owner());
        for ( uint i = 0 ; i < _schemes.length ; i++ ) {
            if ((_permissions[i]&0x80000000) == 0x80000000) {
                uint fee = UniversalScheme(_schemes[i]).fee();
                if (fee != 0) {
                    StandardToken token = UniversalScheme(_schemes[i]).nativeToken();
                    controller.externalTokenIncreaseApproval(token, _schemes[i], fee,address(_avatar));
                  }
                UniversalScheme(_schemes[i]).registerOrganization(_avatar);
                }
            controller.registerScheme(_schemes[i], _params[i], _permissions[i],address(_avatar));
        }

        // Unregister self:
        controller.unregisterScheme(this,address(_avatar));

        // Remove lock:
        delete locks[_avatar];

        InitialSchemesSet(address(_avatar));
    }
}
