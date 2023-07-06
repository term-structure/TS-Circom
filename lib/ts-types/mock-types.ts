import { dpPoseidonHash, TsTxRequestDataType, TsTxType, TsOrderLeafEncodeType, TsSignatureRequestType } from 'term-structure-sdk';
import { TsRollupAccount } from '../ts-rollup/ts-rollup-account';
import { toTreeLeaf } from '../ts-rollup/ts-rollup-helper';
import { TsBondLeafEncodeType, TsFeeLeafEncodeType, TsNullifierLeafEncodeType } from './ts-rollup-types';

export class TransactionInfo {
  txId!: string; 
  blockNumber!: string | null;
  reqType!: TsTxType;
  accountId!: string;
  tokenId!: string;
  amount!: string;
  nonce!: string;
  fee0!: string;
  fee1!: string;
  arg0!: string;
  arg1!: string;
  arg2!: string;
  arg3!: string;
  arg4!: string;
  arg5!: string;
  arg6!: string;
  arg7!: string;
  arg8!: string;
  arg9!: string;
  eddsaSig!: TsSignatureRequestType;
  ecdsaSig!: string;
  metadata!: {
    orderId?: string;
    orderTxId?: string,
    orderStatus?: string,
    matchedSellAmt?: string,
    matchedBuyAmt?: string,
    bondTokenId?: string,
    matchedCollateralAmt?: string,
    matchedLendAmt?: string,
    matchedBorrowAmt?: string,
    matchedBondAmt?: string,
    matchedDebtAmt?: string,
    tsPubKeyX?: string,
    tsPubKeyY?: string,
    feeTokenId?: string,
    feeAmt?: string,
    maturityTime?: string,
    lockedAmt?: string,
    matchedTime?: string,
  } | null;
  txStatus!: TS_STATUS;

  get tokenAddr() {
    return this.tokenId.toString();
  }

  encodeMessage(): TsTxRequestDataType {
    return [
      BigInt(this.reqType),
      BigInt(this.accountId),
      BigInt(this.tokenId),
      BigInt(this.amount),
      BigInt(this.nonce),
      BigInt(this.fee0),
      BigInt(this.fee1),
      BigInt(this.arg0),
      BigInt(this.arg1),
      BigInt(this.arg2),
      BigInt(this.arg3),
      BigInt(this.arg4),
      BigInt(this.arg5),
      BigInt(this.arg6),
      BigInt(this.arg7),
      BigInt(this.arg8),
      BigInt(this.arg9),
    ];
  }
}

export const getEmptyTx: () => TransactionInfo = () => {
  const info = new TransactionInfo();
  info.blockNumber = '0';
  info.reqType = TsTxType.NOOP;
  info.accountId = '0';
  info.tokenId = '0';
  info.amount = '0';
  info.nonce = '0';
  info.fee0 = '0';
  info.fee1 = '0';
  info.arg0 = '0';
  info.arg1 = '0';
  info.arg2 = '0';
  info.arg3 = '0';
  info.arg4 = '0';
  info.arg5 = '0';
  info.arg6 = '0';
  info.arg7 = '0';
  info.arg8 = '0';
  info.arg9 = '0';
  info.eddsaSig = {
    R8: ['0', '0'],
    S: '0'
  };
  info.ecdsaSig = '0';
  info.metadata = {
    orderId: '0',
  };
  return info;
};

export enum TS_STATUS {
  PENDING='PENDING',
  PROCESSING='PROCESSING',
  L2EXECUTED='L2EXECUTED',
  L2CONFIRMED='L2CONFIRMED',
  L1CONFIRMED='L1CONFIRMED',
  FAILED='FAILED',
  REJECTED='REJECTED'
}
export class OrderLeafNode {
  leafId!: string;
  reqType!: TsTxType;
  accountId!: string;
  tokenId!: string;
  amount!: string;
  nonce!: string;
  fee0!: string;
  fee1!: string;
  arg0!: string;
  arg1!: string;
  arg2!: string;
  arg3!: string;
  arg4!: string;
  arg5!: string;
  arg6!: string;
  arg7!: string;
  arg8!: string;
  arg9!: string;
  orderTxId!: string;
  acc1!: string;
  acc2!: string;
  lockAmt!: string;
  // metadata: {
  //   lockAmt?: string
  // } | undefined;

  setOrderLeafId(id: bigint) {
    this.leafId = id.toString();
  }

  encodeNullifierHash() {
    return dpPoseidonHash([
      BigInt(this.reqType),
      BigInt(this.accountId),
      BigInt(this.tokenId),
      BigInt(this.amount),
      BigInt(this.nonce),
      BigInt(this.fee0),
      BigInt(this.fee1),
      BigInt(this.arg0),
      BigInt(this.arg1),
      BigInt(this.arg2),
      BigInt(this.arg3),
      BigInt(this.arg4),
      BigInt(this.arg5),
      BigInt(this.arg6),
      BigInt(this.arg7),
      BigInt(this.arg8),
      BigInt(this.arg9),
    ]);
  }

  encodeLeafMessage(): TsOrderLeafEncodeType {
    return [
      BigInt(this.reqType),
      BigInt(this.accountId),
      BigInt(this.tokenId),
      BigInt(this.amount),
      BigInt(this.nonce),
      BigInt(this.fee0),
      BigInt(this.fee1),
      BigInt(this.arg0),
      BigInt(this.arg1),
      BigInt(this.arg2),
      BigInt(this.arg3),
      BigInt(this.arg4),
      BigInt(this.arg5),
      BigInt(this.arg6),
      BigInt(this.arg7),
      BigInt(this.arg8),
      BigInt(this.arg9),
      BigInt(this.orderTxId),
      BigInt(this.acc1),
      BigInt(this.acc2),
      BigInt(this.lockAmt),
    ];
  }

  encodeLeafHash() {
    return toTreeLeaf([
      BigInt(this.reqType),
      BigInt(this.accountId),
      BigInt(this.tokenId),
      BigInt(this.amount),
      BigInt(this.nonce),
      BigInt(this.fee0),
      BigInt(this.fee1),
      BigInt(this.arg0),
      BigInt(this.arg1),
      BigInt(this.arg2),
      BigInt(this.arg3),
      BigInt(this.arg4),
      BigInt(this.arg5),
      BigInt(this.arg6),
      BigInt(this.arg7),
      BigInt(this.arg8),
      BigInt(this.arg9),
      BigInt(this.orderTxId),
      BigInt(this.acc1),
      BigInt(this.acc2),
      BigInt(this.lockAmt),
    ]);
  }

  copyFromTx(orderId: string, tx: TransactionInfo) {
    this.leafId = orderId;
    this.reqType = tx.reqType;
    this.accountId = tx.accountId;
    this.tokenId = tx.tokenId;
    this.amount = tx.amount;
    this.nonce = tx.nonce;
    this.fee0 = tx.fee0;
    this.fee1 = tx.fee1;
    this.arg0 = tx.arg0;
    this.arg1 = tx.arg1;
    this.arg2 = tx.arg2;
    this.arg3 = tx.arg3;
    this.arg4 = tx.arg4;
    this.arg5 = tx.arg5;
    this.arg6 = tx.arg6;
    this.arg7 = tx.arg7;
    this.arg8 = tx.arg8;
    this.arg9 = tx.arg9;
  }

  setTxId(txId: string) {
    this.orderTxId = txId;
  }
  
}
export const getEmptyOrderLeaf: () => OrderLeafNode = () => {
  const order = new OrderLeafNode();
  order.leafId = '0';
  order.reqType = TsTxType.NOOP;
  order.accountId = '0';
  order.tokenId = '0';
  order.amount = '0';
  order.nonce = '0';
  order.fee0 = '0';
  order.fee1 = '0';
  order.arg0 = '0';
  order.arg1 = '0';
  order.arg2 = '0';
  order.arg3 = '0';
  order.arg4 = '0';
  order.arg5 = '0';
  order.arg6 = '0';
  order.arg7 = '0';
  order.arg8 = '0';
  order.arg9 = '0';
  order.orderTxId = '0';
  order.acc1 = '0';
  order.acc2 = '0';
  order.lockAmt = '0';
  return order;
};

export class FeeLeafEntity {
  leafId!: string;
  amount = '0';

  encodeLeafMessage(): TsFeeLeafEncodeType {
    return [
      BigInt(this.amount)
    ];
  }

  encodeLeafHash() {
    return dpPoseidonHash(this.encodeLeafMessage());
  }
}

export const getDefaultFeeLeaf = (leafId = '0') => {
  const fee = new FeeLeafEntity();
  fee.leafId = leafId;
  fee.amount = '0';
  return fee;
};

export class BondLeafEntity {
  leafId!: string;
  baseTokenId = '0';
  maturityTime = '0';

  encodeLeafMessage(): TsBondLeafEncodeType {
    return [
      BigInt(this.baseTokenId),
      BigInt(this.maturityTime),
    ];
  }

  encodeLeafHash() {
    return toTreeLeaf(this.encodeLeafMessage());
  }
}

export const getDefaultBondLeaf = (leafId = '0') => {
  const bond = new BondLeafEntity();
  bond.leafId = leafId;
  bond.maturityTime = '0';
  return bond;
};


export class NullifierLeafEntity {
  leafId!: string;
  cnt = 0;
  arg0!: string;
  arg1!: string;
  arg2!: string;
  arg3!: string;
  arg4!: string;
  arg5!: string;
  arg6!: string;
  arg7!: string;

  encodeLeafMessage(): TsNullifierLeafEncodeType {
    return [
      BigInt(this.arg0),
      BigInt(this.arg1),
      BigInt(this.arg2),
      BigInt(this.arg3),
      BigInt(this.arg4),
      BigInt(this.arg5),
      BigInt(this.arg6),
      BigInt(this.arg7),
    ];
  }

  encodeLeafHash() {
    return toTreeLeaf(this.encodeLeafMessage());
  }
}

export const getDefaultNullifierLeaf: () => NullifierLeafEntity = () => {
  const nullifier = new NullifierLeafEntity();
  nullifier.leafId = '0';
  nullifier.cnt = 0;
  nullifier.arg0 = '0';
  nullifier.arg1 = '0';
  nullifier.arg2 = '0';
  nullifier.arg3 = '0';
  nullifier.arg4 = '0';
  nullifier.arg5 = '0';
  nullifier.arg6 = '0';
  nullifier.arg7 = '0';
  return nullifier;
};



export function getDefaultAccountLeafNode(token_tree_height: number): TsRollupAccount {
  return new TsRollupAccount(
    {},
    token_tree_height,
    [0n, 0n],
  );
}