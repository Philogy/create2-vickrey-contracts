pragma solidity ^0.8.0;

import "../lib/EthereumDecoder.sol";
import "../lib/MPT.sol";

interface iProver {
  function verifyTrieProof(MPT.MerkleProof memory data) external view returns (bool);

  function verifyAccount(
    EthereumDecoder.BlockHeader memory header,
    MPT.MerkleProof memory accountdata,
    uint256 balance,
    uint256 codeHash,
    uint256 storageHash,
    address contractAddress
  ) external returns (bool valid, string memory reason);
}
