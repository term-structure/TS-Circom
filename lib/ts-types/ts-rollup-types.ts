import { TsTxRequestDataType } from 'term-structure-sdk';
export type TsFeeLeafEncodeType = [bigint];
export type TsBondLeafEncodeType = [bigint, bigint];
export type TsNullifierLeafEncodeType = [bigint, bigint, bigint, bigint, bigint, bigint, bigint, bigint];
export interface TsRollupBaseType {
    reqData: TsTxRequestDataType,
    tsPubKey: [bigint, bigint] | [string, string],
    sigR: [bigint, bigint] | [string, string],
    sigS: bigint | string,
    r_chunks: bigint[] | string[],
    o_chunks: bigint[] | string[],
    isCriticalChunk: bigint[] | string[],
  }

export interface TsRollupAuctionBaseType {
    orderLeafId: string,
    oriOrderLeaf: string,
    r_orderLeafId: Array<string>
}

export interface TsRollupAuctionStateType {
    orderRootFlow: string,
    orderMerkleProofTo: string[],
}

export interface TsRollupStateType {
    oriTokenRootFrom: string,
    oriTokenRootTo: string,
    accountMerkleProofFrom: string,
    accountMerkleProofTo: string,
    tokenMerkleProofFrom: string,
    tokenMerkleProofTo: string,
    newTokenRootFrom: string,
    newTokenRootTo: string,
    accountRootFlow: string,
}

export interface TsRollupCircuitInputItemType extends TsRollupBaseType, TsRollupStateType, TsRollupAuctionBaseType, TsRollupAuctionStateType {}

export type TsRollupCircuitInputType = {
    // [key in keyof TsRollupCircuitInputItemType]: Array<TsRollupCircuitInputItemType[key]>;
    [key: string]: any,
}

// Register Circuit Input
export interface TsRollupRegisterType {
    L2TokenAddr: string;
    amount: string;
    L2Addr: string;
    tsPubKey: [string, string];
}

export interface TsRollupRegisterStateType {
    accountRootFlow: string;
    accountMerkleProof: string[];
}
export interface TsRollupRegisterInputItemType extends TsRollupRegisterType, TsRollupRegisterStateType {}

export type TsRollupRegisterCircuitInputType = {
    [key in keyof TsRollupRegisterInputItemType]: Array<TsRollupRegisterInputItemType[key]>;
}