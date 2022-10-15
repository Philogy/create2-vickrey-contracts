const { createAlchemyWeb3 } = require('@alch/alchemy-web3')
const { GetProof } = require('eth-proof')
const ethers = require('ethers')
require('dotenv').config()

const getBlockHeader = (blockData) => {
  const retData = {};
  [
    'hash',
    'parentHash',
    'sha3Uncles',
    'miner',
    'stateRoot',
    'transactionsRoot',
    'receiptsRoot',
    'logsBloom',
    'difficulty',
    'number',
    'gasLimit',
    'gasUsed',
    'timestamp',
    'extraData',
    'mixHash',
    'nonce',
    'totalDifficulty',
    'baseFeePerGas',
  ].forEach((key) => (retData[key] = blockData[key]))
  return retData
}

const bufToHex = (b) => '0x' + b.toString('hex')

const expandAddrToKey = (addr) =>
  '0x' +
  Array.from(ethers.utils.solidityKeccak256(['address'], [addr]).slice(2))
    .map((char) => `0${char}`)
    .join('')

const getAccMPTProof = (
  { accountProof: rawAccountProof },
  { stateRoot },
  addr
) => {
  const hexProofNodes = Array.from(rawAccountProof).map((bufs) =>
    bufs.map(bufToHex)
  )

  return {
    expectedRoot: stateRoot,
    key: expandAddrToKey(addr),
    proof: hexProofNodes.map((node) => ethers.utils.RLP.encode(node)),
    keyIndex: 0,
    proofIndex: 0,
    expectedValue: hexProofNodes[hexProofNodes.length - 1][1],
  }
}

async function main() {
  const web3 = createAlchemyWeb3(process.env.GOERLI_RPC)

  const block = await web3.eth.getBlockNumber()
  console.log('block: ', block)
  const directBlock = await web3.eth.getBlock(block)
  const blockHeader = getBlockHeader(directBlock)
  console.log('directBlock: ', directBlock)
  console.log('blockHeader: ', blockHeader)
  const account = '0x97aEabe66E1e126358DF8b977D0F615A62173448'
  // const ethProof = await web3.eth.getProof(account, [], block)

  const getProof = new GetProof(process.env.GOERLI_RPC)

  const accountProof = getAccMPTProof(
    await getProof.accountProof(account, blockHeader.hash),
    blockHeader,
    account
  )
  console.log('accountProof: ', accountProof)
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('err:', err)
    process.exit(1)
  })
