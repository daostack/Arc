pragma solidity ^0.5.4;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";


/**
 * @title reputation allocation contract
 * This scheme can be used to allocate a pre define amount of reputation to whitelisted
 * beneficiaries.
 * this contract can be used as the rep mapping contract for  RepitationFromToken contract.
 */
contract RepAllocation is Ownable {


       // beneficiary -> amount
    mapping(address   =>   uint256) public reputationAllocations;
    mapping(bytes32 => bool) public reputationAllocationsRoots;
    bool public isFreeze;

    event BeneficiaryAddressAdded(address indexed _beneficiary, uint256 indexed _amount);

    /**
     * @dev addBeneficiary function
     * @param _beneficiary to be whitelisted
     */
    function addBeneficiary(address _beneficiary, uint256 _amount) public onlyOwner {
        require(!isFreeze, "can add beneficiary only if not disable");

        if (reputationAllocations[_beneficiary] == 0) {
            reputationAllocations[_beneficiary] = _amount;
            emit BeneficiaryAddressAdded(_beneficiary, _amount);
        }
    }

    /**
     * @dev add addBeneficiaries function
     * @param _beneficiaries addresses
     */
    function addBeneficiaries(address[] memory _beneficiaries, uint256[] memory _amounts) public onlyOwner {
        require(_beneficiaries.length == _amounts.length);
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            addBeneficiary(_beneficiaries[i], _amounts[i]);
        }
    }

    /**
     * @dev add addBeneficiariesRoot function
     * @param _root Merkle Tree root
     */
    function addBeneficiariesRoot(bytes32 _root) public onlyOwner {
        require(!reputationAllocationsRoots[_root]);
        reputationAllocationsRoots[_root] = true;
    }

    /**
     * @dev add addBeneficiariesRoot function
     * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/cryptography/MerkleProof.sol
     * @param _beneficiary user address
     * @param _amount allocation
     * @param _proof Merkle proof related to previously submitted Merkle root
     */
    function revealBeneficiary(address _beneficiary, uint256 _amount, bytes32[] memory _proof) public {
        bytes32 computedHash = keccak256(abi.encodePacked(_beneficiary, _amount));

        for (uint256 i = 0; i < _proof.length; i++) {
            bytes32 proofElement = _proof[i];

            if (computedHash < proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        require(reputationAllocationsRoots[computedHash], "Root does not exist");
        addBeneficiary(_beneficiary, _amount);
    }

    /**
     * @dev freeze function
     * cannot defreeze
     */
    function freeze() public onlyOwner {
        isFreeze = true;
    }

    /**
     * @dev get balanceOf _beneficiary function
     * @param _beneficiary addresses
     */
    function balanceOf(address _beneficiary) public view returns(uint256) {
        return reputationAllocations[_beneficiary];
    }

}