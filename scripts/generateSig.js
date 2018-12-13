const ethUtil = require('ethereumjs-util');
const sigUtil = require('eth-sig-util');
const utils = sigUtil.TypedDataUtils;

//Our lad Cal wants to relay 2 dai to del, paying a 1 dai fee to msg.sender

const calprivKeyHex = '4af1bceebf7f3634ec3cff8a2c38e51178d5d4ce585c52d6043e5e2cc3418bb0'
const calprivKey = new Buffer(calprivKeyHex, 'hex')
const cal = ethUtil.privateToAddress(calprivKey);
const del = new Buffer('dd2d5d3f7f1b35b7a0601d6a00dbb7d44af58479', 'hex');
const dai = new Buffer('dadadadadadadadadadadadadadadadadadadada', 'hex');
console.log('cals address: ' + '0x' + cal.toString('hex'));
console.log('dels address: ' + '0x' + del.toString('hex'));
let typedData = {
  types: {
      EIP712Domain: [
          { name: 'name', type: 'string' },
          { name: 'version', type: 'string' },
          { name: 'chainId', type: 'uint256' },
          { name: 'verifyingContract', type: 'address' },
      ],
      Cheque: [
          { name: 'token', type: 'address' },
          { name: 'sender', type: 'address' },
          { name: 'receiver', type: 'address' },
          { name: 'amount', type: 'uint256' },
          { name: 'fee', type: 'uint256' },
          { name: 'nonce', type: 'uint256' },
      ],
  },
  primaryType: 'Cheque',
  domain: {
      name: 'Dai Automated Clearing House',
      version: '1',
      chainId: 1,
      verifyingContract: '0xdeadbeef',
  },
  message: {
      token: '0x'+dai.toString('hex'),
      sender: '0x'+cal.toString('hex'),
      sender: '0x'+cal.toString('hex'),
      receiver: '0x'+del.toString('hex'),
      amount: 2,
      fee: 1,
      nonce: 0,
  },
};

let hash = ethUtil.bufferToHex(utils.hashStruct('EIP712Domain', typedData.domain, typedData.types))
console.log('EIP712DomainHash: ' + hash);
hash = ethUtil.bufferToHex(utils.hashType('Cheque', typedData.types))
console.log('Cheque Typehash: ' + hash);
hash = ethUtil.bufferToHex(utils.hashStruct('Cheque', typedData.message, typedData.types))
console.log('Cheque (from cal to del) hash: ' + hash);
const sig = sigUtil.signTypedData(calprivKey, { data: typedData });
console.log('signed check: ' + sig);

let r = sig.slice(0,66);
let s = '0x'+ sig.slice(66,130);
let v = ethUtil.bufferToInt(ethUtil.toBuffer('0x'+sig.slice(130,132),'hex'));

console.log('r: ' + r)
console.log('s: ' + s)
console.log('v: ' + v)
