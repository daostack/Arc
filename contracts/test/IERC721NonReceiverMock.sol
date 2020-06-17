pragma solidity  ^0.5.17;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC721/IERC721Receiver.sol";

contract IERC721NonReceiverMock is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes memory)
    public returns (bytes4)
    {
        return bytes4(keccak256("Don't Receive ERC721"));
    }
}