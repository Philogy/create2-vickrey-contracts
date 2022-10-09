pragma solidity ^0.8.0;

import "../external_lib/RLPEncode.sol";
import "../external_lib/RLPDecode.sol";

library EthereumDecoder {
  using RLPDecode for RLPDecode.RLPItem;
  using RLPDecode for RLPDecode.Iterator;

  struct BlockHeader {
    bytes32 hash;
    bytes32 parentHash;
    bytes32 sha3Uncles; // ommersHash
    address miner; // beneficiary
    bytes32 stateRoot;
    bytes32 transactionsRoot;
    bytes32 receiptsRoot;
    bytes logsBloom;
    uint256 difficulty;
    uint256 number;
    uint256 gasLimit;
    uint256 gasUsed;
    uint256 timestamp;
    bytes extraData;
    bytes32 mixHash;
    uint64 nonce;
    uint256 totalDifficulty;
  }

  struct Account {
    uint256 nonce;
    uint256 balance;
    bytes32 storageRoot;
    bytes32 codeHash;
  }

  struct Transaction {
    uint256 nonce;
    uint256 gasPrice;
    uint256 gasLimit;
    address to;
    uint256 value;
    bytes data;
    uint8 v;
    bytes32 r;
    bytes32 s;
  }

  struct Log {
    address contractAddress;
    bytes32[] topics;
    bytes data;
  }

  struct TransactionReceipt {
    bytes32 transactionHash;
    uint256 transactionIndex;
    bytes32 blockHash;
    uint256 blockNumber;
    address from;
    address to;
    uint256 gasUsed;
    uint256 cummulativeGasUsed;
    address contractAddress;
    Log[] logs;
    uint256 status; // root?
    bytes logsBloom;
    uint8 v;
    bytes32 r;
    bytes32 s;
  }

  struct TransactionReceiptTrie {
    uint8 status;
    uint256 gasUsed;
    bytes logsBloom;
    Log[] logs;
  }

  function getBlockRlpData(BlockHeader memory header) internal pure returns (bytes memory data) {
    bytes[] memory list = new bytes[](15);

    list[0] = RLPEncode.encodeBytes(abi.encodePacked(header.parentHash));
    list[1] = RLPEncode.encodeBytes(abi.encodePacked(header.sha3Uncles));
    list[2] = RLPEncode.encodeAddress(header.miner);
    list[3] = RLPEncode.encodeBytes(abi.encodePacked(header.stateRoot));
    list[4] = RLPEncode.encodeBytes(abi.encodePacked(header.transactionsRoot));
    list[5] = RLPEncode.encodeBytes(abi.encodePacked(header.receiptsRoot));
    list[6] = RLPEncode.encodeBytes(header.logsBloom);
    list[7] = RLPEncode.encodeUint(header.difficulty);
    list[8] = RLPEncode.encodeUint(header.number);
    list[9] = RLPEncode.encodeUint(header.gasLimit);
    list[10] = RLPEncode.encodeUint(header.gasUsed);
    list[11] = RLPEncode.encodeUint(header.timestamp);
    list[12] = RLPEncode.encodeBytes(header.extraData);
    list[13] = RLPEncode.encodeBytes(abi.encodePacked(header.mixHash));
    list[14] = RLPEncode.encodeBytes(abi.encodePacked(header.nonce));

    data = RLPEncode.encodeList(list);
  }

  function toBlockHeader(bytes memory rlpHeader) internal pure returns (BlockHeader memory header) {
    RLPDecode.Iterator memory it = RLPDecode.toRlpItem(rlpHeader).iterator();
    uint256 idx;
    while (it.hasNext()) {
      if (idx == 0) header.parentHash = bytes32(it.next().toUint());
      else if (idx == 1) header.sha3Uncles = bytes32(it.next().toUint());
      else if (idx == 2) header.miner = it.next().toAddress();
      else if (idx == 3) header.stateRoot = bytes32(it.next().toUint());
      else if (idx == 4) header.transactionsRoot = bytes32(it.next().toUint());
      else if (idx == 5) header.receiptsRoot = bytes32(it.next().toUint());
      else if (idx == 6) header.logsBloom = it.next().toBytes();
      else if (idx == 7) header.difficulty = it.next().toUint();
      else if (idx == 8) header.number = it.next().toUint();
      else if (idx == 9) header.gasLimit = it.next().toUint();
      else if (idx == 10) header.gasUsed = it.next().toUint();
      else if (idx == 11) header.timestamp = it.next().toUint();
      else if (idx == 12) header.extraData = it.next().toBytes();
      else if (idx == 13) header.mixHash = bytes32(it.next().toUint());
      else if (idx == 14)
        header.nonce = uint64(it.next().toUint());
        // else if ( idx == 13 ) header.nonce           = uint64(it.next().toUint());
      else it.next();
      idx++;
    }
    header.hash = keccak256(rlpHeader);
  }

  function getBlockHash(EthereumDecoder.BlockHeader memory header) internal pure returns (bytes32 hash) {
    return keccak256(getBlockRlpData(header));
  }

  function getLog(Log memory log) internal pure returns (bytes memory data) {
    bytes[] memory list = new bytes[](3);
    bytes[] memory topics = new bytes[](log.topics.length);

    for (uint256 i = 0; i < log.topics.length; i++) {
      topics[i] = RLPEncode.encodeBytes(abi.encodePacked(log.topics[i]));
    }

    list[0] = RLPEncode.encodeAddress(log.contractAddress);
    list[1] = RLPEncode.encodeList(topics);
    list[2] = RLPEncode.encodeBytes(log.data);
    data = RLPEncode.encodeList(list);
  }

  function getReceiptRlpData(TransactionReceiptTrie memory receipt) internal pure returns (bytes memory data) {
    bytes[] memory list = new bytes[](4);

    bytes[] memory logs = new bytes[](receipt.logs.length);
    for (uint256 i = 0; i < receipt.logs.length; i++) {
      logs[i] = getLog(receipt.logs[i]);
    }

    list[0] = RLPEncode.encodeUint(receipt.status);
    list[1] = RLPEncode.encodeUint(receipt.gasUsed);
    list[2] = RLPEncode.encodeBytes(receipt.logsBloom);
    list[3] = RLPEncode.encodeList(logs);
    data = RLPEncode.encodeList(list);
  }

  function toReceiptLog(bytes memory data) internal pure returns (Log memory log) {
    RLPDecode.Iterator memory it = RLPDecode.toRlpItem(data).iterator();

    uint256 idx;
    while (it.hasNext()) {
      if (idx == 0) {
        log.contractAddress = it.next().toAddress();
      } else if (idx == 1) {
        RLPDecode.RLPItem[] memory list = it.next().toList();
        log.topics = new bytes32[](list.length);
        for (uint256 i = 0; i < list.length; i++) {
          bytes32 topic = bytes32(list[i].toUint());
          log.topics[i] = topic;
        }
      } else if (idx == 2) log.data = it.next().toBytes();
      else it.next();
      idx++;
    }
  }

  function toReceipt(bytes memory data) internal pure returns (TransactionReceiptTrie memory receipt) {
    RLPDecode.Iterator memory it = RLPDecode.toRlpItem(data).iterator();

    uint256 idx;
    while (it.hasNext()) {
      if (idx == 0) receipt.status = uint8(it.next().toUint());
      else if (idx == 1) receipt.gasUsed = it.next().toUint();
      else if (idx == 2) receipt.logsBloom = it.next().toBytes();
      else if (idx == 3) {
        RLPDecode.RLPItem[] memory list = it.next().toList();
        receipt.logs = new Log[](list.length);
        for (uint256 i = 0; i < list.length; i++) {
          receipt.logs[i] = toReceiptLog(list[i].toRlpBytes());
        }
      } else it.next();
      idx++;
    }
  }

  function getTransactionRaw(Transaction memory transaction, uint256 chainId) internal pure returns (bytes memory data) {
    bytes[] memory list = new bytes[](9);

    list[0] = RLPEncode.encodeUint(transaction.nonce);
    list[1] = RLPEncode.encodeUint(transaction.gasPrice);
    list[2] = RLPEncode.encodeUint(transaction.gasLimit);
    list[3] = RLPEncode.encodeAddress(transaction.to);
    list[4] = RLPEncode.encodeUint(transaction.value);
    list[5] = RLPEncode.encodeBytes(transaction.data);
    list[6] = RLPEncode.encodeUint(chainId);
    list[7] = RLPEncode.encodeUint(0);
    list[8] = RLPEncode.encodeUint(0);
    data = RLPEncode.encodeList(list);
  }

  function toTransaction(bytes memory data) internal pure returns (Transaction memory transaction) {
    RLPDecode.Iterator memory it = RLPDecode.toRlpItem(data).iterator();

    uint256 idx;
    while (it.hasNext()) {
      if (idx == 0) transaction.nonce = it.next().toUint();
      else if (idx == 1) transaction.gasPrice = it.next().toUint();
      else if (idx == 2) transaction.gasLimit = it.next().toUint();
      else if (idx == 3) transaction.to = it.next().toAddress();
      else if (idx == 4) transaction.value = it.next().toUint();
      else if (idx == 5) transaction.data = it.next().toBytes();
      else if (idx == 6) transaction.v = uint8(it.next().toUint());
      else if (idx == 7) transaction.r = bytes32(it.next().toUint());
      else if (idx == 8) transaction.s = bytes32(it.next().toUint());
      else it.next();
      idx++;
    }
  }

  function toAccount(bytes memory data) internal pure returns (Account memory account) {
    RLPDecode.Iterator memory it = RLPDecode.toRlpItem(data).iterator();

    uint256 idx;
    while (it.hasNext()) {
      if (idx == 0) account.nonce = it.next().toUint();
      else if (idx == 1) account.balance = it.next().toUint();
      else if (idx == 2) account.storageRoot = toBytes32(it.next().toBytes());
      else if (idx == 3) account.codeHash = toBytes32(it.next().toBytes());
      else it.next();
      idx++;
    }
  }

  function toBytes32(bytes memory data) internal pure returns (bytes32 _data) {
    assembly {
      _data := mload(add(data, 32))
    }
  }
}
