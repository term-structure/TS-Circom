import fs from 'fs';
import { TsRollupConfigType } from '../../lib/ts-rollup/ts-rollup';
import { utils } from 'ethers';
import { toHex } from './commitment.helper';
import { dpPoseidonHash, TsSystemAccountAddress, TsTokenId, TsTxType } from 'term-structure-sdk';
import { arrayChunkToHexString } from '../../lib/ts-rollup/ts-rollup-helper';
export type StateType = {
  oriStateRoot: string,
  newStateRoot: string,
  oriTsRoot: string,
  newTsRoot: string,
  pubdata: string
  newBlockTimestamp: number,
};

export class CircuitInputsExporter {

  config: any;
  mainSuffix: any;
  registerSuffix: any;
  outputPath: any;
  circuitMainPath: any;
  // circuitRegisterPath: any;
  mainCircuitName: any;
  // registerCircuitName: any;
  constructor(
    _mainCircuitName: any,
    // _registerCircuitName: any,
    _config: any,
    _mainSuffix: any,
    _outputPath: any,
    _circuitMainPath: any,
    // _circuitRegisterPath: any,
  ) {
    this.mainCircuitName = _mainCircuitName;
    // this.registerCircuitName = _registerCircuitName;
    this.config = _config;
    this.mainSuffix = _mainSuffix;
    this.outputPath = _outputPath;
    this.circuitMainPath = _circuitMainPath;
    // this.circuitRegisterPath = _circuitRegisterPath;

    deleteFolderRecursive(this.outputPath);
    fs.mkdirSync(this.outputPath, { recursive: true });
  }
  fileLogs: Array<{
    circuitName: string;
    name: string;
    path: string;
  }> = [];
  exportInputs(_name: string, rawInputs: any, newInputs: any, inputs: any, circuitName: string, stateLogGlobal: any) {
    const name = `${this.fileLogs.length}_${_name}`;
    const path = `${this.outputPath}/${name}-inputs.json`;
    const keyPath = `${this.outputPath}/${name}-inputs-key.json`;
    const oldPath = `${this.outputPath}/${name}-input-old.json`;
    const commitPath = `${this.outputPath}/${name}-commitment.json`;
    
    writeFileSync(path, JSON.stringify(newInputs, null, 2));
    writeFileSync(keyPath, JSON.stringify(rawInputs, null, 2));
    writeFileSync(oldPath, JSON.stringify(inputs, null, 2));

    const {oriTsRoot, oriStateRoot} = getOriTsRoot(inputs);
    const {newTsRoot, newStateRoot, newAccountRoot} = getNewTsRoot(inputs);
    stateLogGlobal.oriTsRoot = oriTsRoot;
    stateLogGlobal.oriStateRoot = oriStateRoot;
    stateLogGlobal.newTsRoot = newTsRoot;
    stateLogGlobal.newStateRoot = newStateRoot;
    stateLogGlobal.newAccountRoot = toHex(newAccountRoot);
    stateLogGlobal.isCriticalChunk = arrayChunkToHexString(inputs?.isCriticalChunk as any, 1);
    stateLogGlobal.o_chunk = arrayChunkToHexString(inputs?.o_chunks as any);
    const pubdata = utils.solidityPack([
      'bytes', 'bytes', 
    ], [
      stateLogGlobal.isCriticalChunk, stateLogGlobal.o_chunk
    ]);
    stateLogGlobal.pubdata = pubdata;
    stateLogGlobal.newBlockTimestamp = inputs.currentTime;

    writeFileSync(commitPath, JSON.stringify(stateLogGlobal, null, 2));
    this.fileLogs.push({
      circuitName,
      name,
      path
    });

    return stateLogGlobal;
  }

  exportOthers(name: string, data: object) {
    writeFileSync(`${this.outputPath}/${name}.json`, JSON.stringify(data, null, 2));
  }

  exportInfo(data: any = {}) {
    const info = {
      mainCircuitName: this.mainCircuitName,
      // registerCircuitName: this.registerCircuitName,
      config: this.config,
      mainSuffix: this.mainSuffix,
      registerSuffix: this.registerSuffix,
      outputPath: this.outputPath,
      circuitMainPath: this.circuitMainPath,
      // circuitRegisterPath: this.circuitRegisterPath,
      fileLogs: this.fileLogs,
      metadata: {
        TsSystemAccountAddress: TsSystemAccountAddress,
        TsTokenId: TsTokenId,
        TsTxType: TsTxType,
      },
      ...data,
    };
    writeFileSync(`${this.outputPath}/info.json`, JSON.stringify(info, null, 2));
  }
}


function getNewTsRoot(inputs: any) {
  const accountTreeRoot = inputs.accountRootFlow[inputs.accountRootFlow.length - 1];
  const orderTreeRoot = inputs.orderRootFlow[inputs.orderRootFlow.length - 1];
  const bondTreeRoot = inputs.bondTokenRootFlow[inputs.bondTokenRootFlow.length - 1];
  const feeTreeRoot = inputs.feeRootFlow[inputs.feeRootFlow.length - 1];
  const adminTsAddr = inputs.adminTsAddrFlow[inputs.adminTsAddrFlow.length - 1];

  const nullifierTreeRoot = dpPoseidonHash([
    inputs.nullifierRootFlow[0][inputs.nullifierRootFlow[0].length - 1],
    inputs.epochFlow[0][inputs.epochFlow[0].length - 1],
    inputs.nullifierRootFlow[1][inputs.nullifierRootFlow[1].length - 1],
    inputs.epochFlow[1][inputs.epochFlow[1].length - 1],
  ]);

  const txId = BigInt(inputs.oriTxNum) + BigInt(inputs.reqData.length);
  const newTsRoot = '0x' + dpPoseidonHash([
    BigInt(adminTsAddr),
    BigInt(bondTreeRoot),
    BigInt(feeTreeRoot),
    BigInt(nullifierTreeRoot),
    BigInt(orderTreeRoot),
    txId
  ]).toString(16).padStart(64, '0');

  const newStateRoot = '0x' + dpPoseidonHash([
    BigInt(newTsRoot), BigInt(accountTreeRoot)
  ]).toString(16).padStart(64, '0');
  
  return {newTsRoot, newStateRoot, newAccountRoot: accountTreeRoot};
}

function getOriTsRoot(inputs: any) {
  const accountTreeRoot = inputs.accountRootFlow[0];
  const orderTreeRoot = inputs.orderRootFlow[0];
  const bondTreeRoot = inputs.bondTokenRootFlow[0];
  const feeTreeRoot = inputs.feeRootFlow[0];
  const adminTsAddr = inputs.adminTsAddrFlow[0];

  const nullifierTreeRoot = dpPoseidonHash([
    inputs.nullifierRootFlow[0][0],
    inputs.epochFlow[0][0],
    inputs.nullifierRootFlow[1][0],
    inputs.epochFlow[1][0],
  ]);

  const txId = BigInt(inputs.oriTxNum);
  const oriTsRoot = '0x' + dpPoseidonHash([
    BigInt(adminTsAddr),
    BigInt(bondTreeRoot),
    BigInt(feeTreeRoot),
    BigInt(nullifierTreeRoot),
    BigInt(orderTreeRoot),
    txId
  ]).toString(16).padStart(64, '0');

  const oriStateRoot = '0x' + dpPoseidonHash([
    BigInt(oriTsRoot), BigInt(accountTreeRoot)
  ]).toString(16).padStart(64, '0');
  
  return {oriTsRoot, oriStateRoot, accountTreeRoot};
}


export const TX_TYPES = {
  REGISTER: 'register',
  DEPOSIT: 'deposit',
  WITHDRAW: 'withdraw',
  TRANSFER: 'transfer',
  AUCTION_LEND: 'auctionLend',
  AUCTION_BORROW: 'auctionBorrow',
  AUCTION_CANCEL: 'auctionCancel',
};

export const authTypedData = {
  domain: {
    name: 'Term Structure',
    version: '1',
    chainId: 1,
    verifyingContract: '0x0000000000000000000000000000000000000000'
  },
  types: {
    Main: [
      { name: 'Authentication', type: 'string' },
      { name: 'Action', type: 'string' },
    ],
  },
  value: {
    Authentication: 'Term Structure',
    Action: 'Authenticate on Term Structure',
  },
};

export const getWdTypedData = (L2AddrFrom: string, L2AddrTo: string, L2TokenAddr: string, amount: string, nonce: string) => {
  return {
    domain: {
      name: 'Term Structure',
      version: '1',
      chainId: 1,
      verifyingContract: '0x0000000000000000000000000000000000000000'
    },
    types: {
      Main: [
        { name: 'Authentication', type: 'string' },
        { name: 'Action', type: 'string' },
        { name: 'Sender', type: 'string' },
        { name: 'Receiver', type: 'string' },
        { name: 'Token', type: 'string' },
        { name: 'Amount', type: 'string' },
        { name: 'Nonce', type: 'string' },
      ],
    },
    value: {
      Authentication: 'Term Structure',
      Action: 'Withdraw Request',
      Sender: L2AddrFrom,
      Receiver: L2AddrTo,
      Token: L2TokenAddr,
      Amount: amount,
      Nonce: nonce,
    }
  };
};

export const getTrfTypedData = (L2AddrFrom: string, L2AddrTo: string, L2TokenAddr: string, amount: string, nonce: string) => {
  return {
    domain: {
      name: 'Term Structure',
      version: '1',
      chainId: 1,
      verifyingContract: '0x0000000000000000000000000000000000000000'
    },
    types: {
      Main: [
        { name: 'Authentication', type: 'string' },
        { name: 'Action', type: 'string' },
        { name: 'Sender', type: 'string' },
        { name: 'Receiver', type: 'string' },
        { name: 'Token', type: 'string' },
        { name: 'Amount', type: 'string' },
        { name: 'Nonce', type: 'string' },
      ],
    },
    value: {
      Authentication: 'Term Structure',
      Action: 'Transfer Request',
      Sender: L2AddrFrom,
      Receiver: L2AddrTo,
      Token: L2TokenAddr,
      Amount: amount,
      Nonce: nonce,
    }
  };
};

export const getAuctionLendTypedData = (L2AddrFrom: string, L2TokenAddrLending: string, lendingAmt: string, nonce: string, maturityDate: string, expiredTime: string, interest: string) => {
  return {
    domain: {
      name: 'Term Structure',
      version: '1',
      chainId: 1,
      verifyingContract: '0x0000000000000000000000000000000000000000'
    },
    types: {
      Main: [
        { name: 'Authentication', type: 'string' },
        { name: 'Action', type: 'string' },
        { name: 'L2AddrSender', type: 'string' },
        { name: 'L2AddrReceiver', type: 'string' },
        { name: 'L2TokenAddrLending', type: 'string' },
        { name: 'LendingAmount', type: 'string' },
        { name: 'Nonce', type: 'string' },
        { name: 'MaturityDate', type: 'string' },
        { name: 'ExpiredTime', type: 'string' },
        { name: 'Interest', type: 'string' },
      ],
    },
    value: {
      Authentication: 'Term Structure',
      Action: 'Place Auction Lend Request',
      L2AddrSender: L2AddrFrom,
      L2AddrReceiver: TsSystemAccountAddress.BURN_ADDR,
      L2TokenAddrLending: L2TokenAddrLending,
      LendingAmount: lendingAmt,
      Nonce: nonce,
      MaturityDate: maturityDate,
      ExpiredTime: expiredTime,
      Interest: interest,
    }
  };
};

export const getAuctionBorrowTypedData = (L2AddrFrom: string, L2TokenAddrCollateral: string, collateralAmt: string, nonce: string, maturityDate: string, expiredTime: string, interest: string, L2TokenAddrBorrowing: string, borrowingAmt: string) => {
  return {
    domain: {
      name: 'Term Structure',
      version: '1',
      chainId: 1,
      verifyingContract: '0x0000000000000000000000000000000000000000'
    },
    types: {
      Main: [
        { name: 'Authentication', type: 'string' },
        { name: 'Action', type: 'string' },
        { name: 'L2AddrSender', type: 'string' },
        { name: 'L2AddrReceiver', type: 'string' },
        { name: 'L2TokenAddrCollateral', type: 'string' },
        { name: 'CollateralAmount', type: 'string' },
        { name: 'Nonce', type: 'string' },
        { name: 'MaturityDate', type: 'string' },
        { name: 'ExpiredTime', type: 'string' },
        { name: 'Interest', type: 'string' },
        { name: 'L2TokenAddrBorrowing', type: 'string' },
        { name: 'BorrowingAmount', type: 'string' },
      ],
    },
    value: {
      Authentication: 'Term Structure',
      Action: 'Place Auction Borrow Request',
      L2AddrSender: L2AddrFrom,
      L2AddrReceiver: TsSystemAccountAddress.BURN_ADDR,
      L2TokenAddrCollateral: L2TokenAddrCollateral,
      CollateralAmount: collateralAmt,
      Nonce: nonce,
      MaturityDate: maturityDate,
      ExpiredTime: expiredTime,
      Interest: interest,
      L2TokenAddrBorrowing: L2TokenAddrBorrowing,
      BorrowingAmount: borrowingAmt,
    }
  };
};

export const getAuctionCancelTypedData = (L2AddrTo: string, L2TokenAddrRefunded: string, amount: string, nonce: string, orderLeafId: string) => {
  return {
    domain: {
      name: 'Term Structure',
      version: '1',
      chainId: 1,
      verifyingContract: '0x0000000000000000000000000000000000000000'
    },
    types: {
      Main: [
        { name: 'Authentication', type: 'string' },
        { name: 'Action', type: 'string' },
        { name: 'L2AddrSender', type: 'string' },
        { name: 'L2AddrReceiver', type: 'string' },
        { name: 'L2TokenAddrRefunded', type: 'string' },
        { name: 'Amount', type: 'string' },
        { name: 'Nonce', type: 'string' },
        { name: 'OrderId', type: 'string' },
      ],
    },
    value: {
      Authentication: 'Term Structure',
      Action: 'Cancel Auction Order Request',
      L2AddrSender: TsSystemAccountAddress.BURN_ADDR,
      L2AddrReceiver: L2AddrTo,
      L2TokenAddrRefunded: L2TokenAddrRefunded,
      Amount: amount,
      Nonce: nonce,
      OrderId: orderLeafId,
    }
  };
};


export function createMainCircuit(circuitMainPath: string, config: TsRollupConfigType, name: string, metadata: any) {
  console.log('createMainCircuit', circuitMainPath);

  const pathArr = circuitMainPath.split('/');
  pathArr.pop();
  if(!fs.existsSync(circuitMainPath)) {
    console.log({
      circuitMainPath,
      pathArr
    });
    fs.mkdirSync(pathArr.join('/'), { recursive: true });
  }

  createSpecCircuit(`${pathArr.join('/')}/spec.circom`, config, metadata);
  writeFileSync(circuitMainPath, 
    `pragma circom 2.1.2;
include "spec.circom";
include "../../circuits/${name}/normal.circom";

component main = Normal();
`);
  return circuitMainPath;
}

function createSpecCircuit(specPath: string, config: TsRollupConfigType, metadata: any) {
  writeFileSync(specPath, 
    `pragma circom 2.1.2;
function OrderTreeHeight(){
  return ${config.order_tree_height};
}
function AccTreeHeight(){
  return ${config.account_tree_height};
}
function TokenTreeHeight(){
  return ${config.token_tree_height};
}
function NullifierTreeHeight(){
  return ${config.nullifier_tree_height};
}
function FeeTreeHeight(){
  return ${config.fee_tree_height};
}
function NumOfReqs(){
  return ${config.numOfReqs};
}
function NumOfChunks(){
  return ${config.numOfChunks};
}

function DefaultNullifierRoot(){
  return ${metadata.defaultNulliferRoot};
}

function BondTreeHeight(){
  return ${config.bond_tree_height};
}

function MinChunksPerReq(){
  return 5;
}
function MaxOrderUnitsPerReq(){
  return 1;
}
function MaxAccUnitsPerReq(){
  return 2;
}
function MaxTokenUnitsPerReq(){
  return 2;
}
function MaxNullifierUnitsPerReq(){
  return 1;
}
function MaxFeeUnitsPerReq(){
  return 1;
}
function MaxBondUnitsPerReq(){
  return 1;
}
function MaxChunksPerReq(){
  return 9;
}

function NumOfOrderUnits(){
  return NumOfReqs() * MaxOrderUnitsPerReq();
}
function NumOfAccUnits(){
  return NumOfReqs() * MaxAccUnitsPerReq();
}
function NumOfTokenUnits(){
  return NumOfReqs() * MaxTokenUnitsPerReq();
}
function NumOfFeeUnits(){
  return NumOfReqs() * MaxFeeUnitsPerReq();
}
function NumOfBondUnits(){
  return NumOfReqs() * MaxBondUnitsPerReq();
}
function NumOfOuts(){
  return (NumOfChunks() + 5) \\ 6;
}
  `);
}

export function writeFileSync(path: string, data: any) {
  if(!fs.existsSync(path)) {
    const pathArr = path.split('/');
    pathArr.pop();
    fs.mkdirSync(pathArr.join('/'), { recursive: true });
  }
  fs.writeFileSync(path, data);
}

function deleteFolderRecursive(path: string) {
  if( fs.existsSync(path) ) {
    fs.readdirSync(path).forEach(function(file) {
      const curPath = path + '/' + file;
      if(fs.lstatSync(curPath).isDirectory()) { // recurse
        deleteFolderRecursive(curPath);
      } else { // delete file
        fs.unlinkSync(curPath);
      }
    });
    fs.rmdirSync(path);
  }
}