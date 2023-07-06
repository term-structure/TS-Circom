import { BigNumber, utils } from 'ethers';
import { bigintToHex, CHUNK_BYTES_SIZE, dpPoseidonHash, MAX_CHUNKS_BYTES_PER_REQ, recursiveToString, TsTokenInfo, TsTokenLeafEncodeType, TsTxAuctionBorrowRequest, TsTxAuctionLendRequest, TsTxCancelOrderRequest, TsTxDepositNonSignatureRequest, TsTxRedeemRequest, TsTxRegisterRequest, TsTxRequestDataType, TsTxSecondLimitOrderRequest, TsTxSecondMarketOrderRequest, TsTxTransferRequest, TsTxType, TsTxWithdrawRequest } from 'term-structure-sdk';
import { getEmptyTx, TransactionInfo } from '../ts-types/mock-types';
import { TsRollupCircuitInputType } from '../ts-types/ts-rollup-types';
import { calcSecondaryLockedAmt } from './ts-rollup';

export function encodeRollupWithdrawMessage(req: TransactionInfo): TsTxRequestDataType {
  return [
    BigInt(TsTxType.WITHDRAW),
    BigInt(req.accountId),
    BigInt(req.tokenId),
    BigInt(req.amount),
    BigInt(req.nonce),
    0n, 0n,
    0n, 0n, 0n, 0n, 0n,
    0n, 0n, 0n, 0n, 0n,
  ];
}

export function convertRegisterReq2TxEntity(req: TsTxRegisterRequest, tsPubKey: [bigint, bigint]): TransactionInfo {
  const tx: TransactionInfo = getEmptyTx();
  tx.reqType = req.reqType;
  tx.tokenId = req.tokenId;
  tx.amount = req.amount;
  tx.nonce = req.nonce;
  tx.arg0 = req.receiverId;
  tx.arg6 = req.tsAddr;
  tx.metadata = {
    tsPubKeyX: tsPubKey[0].toString(),
    tsPubKeyY: tsPubKey[1].toString(),
  };
  return tx;
}

export function convertDepositReq2TxEntity(req: TsTxDepositNonSignatureRequest, tsPubKey: [bigint, bigint]): TransactionInfo {
  const tx: TransactionInfo = getEmptyTx();
  tx.reqType = req.reqType;
  tx.arg0 = req.receiverId;
  tx.tokenId = req.tokenId;
  tx.amount = req.amount;
  tx.nonce = req.nonce;
  tx.metadata = {
    tsPubKeyX: tsPubKey[0].toString(),
    tsPubKeyY: tsPubKey[1].toString(),
  };
  return tx;
}

export function convertTransferReq2TxEntity(req: TsTxTransferRequest, tsPubKey: [bigint, bigint]): TransactionInfo {
  const tx: TransactionInfo = getEmptyTx();
  tx.reqType = req.reqType;
  tx.accountId = req.senderId;
  tx.tokenId = req.tokenId;
  tx.amount = req.amount;
  tx.nonce = req.nonce;
  tx.arg0 = req.receiverId;
  tx.eddsaSig = req.eddsaSig;
  tx.metadata = {
    tsPubKeyX: tsPubKey[0].toString(),
    tsPubKeyY: tsPubKey[1].toString(),
  };
  return tx;
}

export function convertWithdrawReq2TxEntity(req: TsTxWithdrawRequest, tsPubKey: [bigint, bigint]): TransactionInfo {
  const tx: TransactionInfo = getEmptyTx();
  tx.reqType = req.reqType;
  tx.accountId = req.senderId;
  tx.tokenId = req.tokenId;
  tx.amount = req.amount;
  tx.nonce = req.nonce;
  tx.eddsaSig = req.eddsaSig;

  tx.metadata = {
    tsPubKeyX: tsPubKey[0].toString(),
    tsPubKeyY: tsPubKey[1].toString(),
  };
  return tx;
}

export function convertLendOrderReq2TxEntity(orderId: string, req: TsTxAuctionLendRequest, tsPubKey: [bigint, bigint]): TransactionInfo {
  const tx: TransactionInfo = getEmptyTx();
  tx.reqType = req.reqType;
  tx.accountId = req.senderId;
  tx.tokenId = req.lendTokenId;
  tx.amount = req.lendAmt;
  tx.nonce = req.orderNonce;
  tx.fee0 = req.fee || '0';
  tx.arg1 = req.maturityTime;
  tx.arg2 = req.expiredTime;
  tx.arg3 = req.interest;
  tx.arg7 = req.epoch;

  tx.eddsaSig = req.eddsaSig;
  tx.metadata = {
    orderId: orderId,
    tsPubKeyX: tsPubKey[0].toString(),
    tsPubKeyY: tsPubKey[1].toString(),
  };
  return tx;
}

export function convertBorrowOrderReq2TxEntity(orderId: string, req: TsTxAuctionBorrowRequest, tsPubKey: [bigint, bigint]): TransactionInfo {
  const tx: TransactionInfo = getEmptyTx();
  tx.reqType = req.reqType;
  tx.accountId = req.senderId;
  tx.tokenId = req.collateralTokenId;
  tx.amount = req.collateralAmt;
  tx.nonce = req.orderNonce;
  tx.fee0 = req.fee || '0';
  tx.arg1 = req.maturityTime;
  tx.arg2 = req.expiredTime;
  tx.arg3 = req.interest;
  tx.arg4 = req.borrowTokenId;
  tx.arg5 = req.borrowAmt;
  tx.arg7 = req.epoch;

  tx.eddsaSig = req.eddsaSig;
  tx.metadata = {
    orderId: orderId,
    tsPubKeyX: tsPubKey[0].toString(),
    tsPubKeyY: tsPubKey[1].toString(),
  };
  return tx;
}

export function convertCancelOrderReq2TxEntity(orderId: string, req: TsTxCancelOrderRequest, tsPubKey: [bigint, bigint]): TransactionInfo {
  const tx: TransactionInfo = getEmptyTx();
  tx.reqType = req.reqType;
  tx.accountId = req.senderId;
  tx.arg1 = req.txId || '0';
  tx.arg2 = req.orderNum;
  tx.eddsaSig = req.eddsaSig;
  tx.metadata = {
    orderId,
    tsPubKeyX: tsPubKey[0].toString(),
    tsPubKeyY: tsPubKey[1].toString(),
  };
  return tx;
}

export function convertRedeemReq2TxEntity(req: TsTxRedeemRequest, tsPubKey: [bigint, bigint]): TransactionInfo {
  const tx: TransactionInfo = getEmptyTx();
  tx.reqType = req.reqType;
  tx.accountId = req.senderId;
  tx.tokenId = req.tokenId;
  tx.amount = req.amount;
  tx.nonce = req.nonce;
  tx.eddsaSig = req.eddsaSig;
  tx.metadata = {
    tsPubKeyX: tsPubKey[0].toString(),
    tsPubKeyY: tsPubKey[1].toString(),
  };
  return tx;
}


export function convertLimitOrderReq2TxEntity(orderId: string, req: TsTxSecondLimitOrderRequest, maturityTime: string, tsPubKey: [bigint, bigint], currentTime: string): TransactionInfo {
  const tx: TransactionInfo = getEmptyTx();
  tx.reqType = req.reqType;
  tx.accountId = req.senderId;
  tx.tokenId = req.sellTokenId;
  tx.amount = req.sellAmt;
  tx.nonce = req.orderNonce;
  tx.fee0 = req.takerFee || '0';
  tx.fee1 = req.makerFee || '0';
  tx.arg1 = req.maturityTime;
  tx.arg2 = req.expiredTime;
  tx.arg4 = req.buyTokenId;
  tx.arg5 = req.buyAmt;
  tx.arg7 = req.epoch;
  tx.arg8 = req.side;

  tx.eddsaSig = req.eddsaSig;

  const isSell = req.side === '1';
  const MQ = BigInt(isSell ? req.sellAmt : req.buyAmt);
  const BQ = BigInt(isSell ? req.buyAmt : req.sellAmt);
  const daysFromExpired = (BigInt(req.maturityTime) - BigInt(req.expiredTime)) / BigInt(86400);
  const daysFromCurrent = (BigInt(req.maturityTime) - BigInt(currentTime)) / BigInt(86400);
  const takerFeeRate = BigInt(req.takerFee);
  const makerFeeRate = BigInt(req.makerFee);
  const maxFeeRate = takerFeeRate > makerFeeRate ? takerFeeRate : makerFeeRate;
  const lockedAmt = calcSecondaryLockedAmt(tx.reqType === TsTxType.SECOND_LIMIT_ORDER, isSell, MQ, BQ, daysFromCurrent, daysFromExpired, maxFeeRate);
  tx.metadata = {
    orderId,
    tsPubKeyX: tsPubKey[0].toString(),
    tsPubKeyY: tsPubKey[1].toString(),
    maturityTime,
    bondTokenId: isSell ? tx.tokenId : tx.arg4,
    feeTokenId: isSell ? tx.arg4 : tx.tokenId,
    lockedAmt: lockedAmt.toString(),
  };
  return tx;
}

export function convertMarketOrderReq2TxEntity(orderId: string, req: TsTxSecondMarketOrderRequest, maturityTime: string, tsPubKey: [bigint, bigint], currentTime: string): TransactionInfo {
  const tx: TransactionInfo = getEmptyTx();
  tx.reqType = req.reqType;
  tx.accountId = req.senderId;
  tx.tokenId = req.sellTokenId;
  tx.amount = req.sellAmt;
  tx.nonce = req.orderNonce;
  tx.fee0 = req.takerFee || '0';
  // tx.fee1 = req.makerFee || '0';
  tx.arg1 = req.maturityTime;
  tx.arg2 = req.expiredTime;
  tx.arg4 = req.buyTokenId;
  tx.arg5 = req.buyAmt;
  tx.arg7 = req.epoch;
  tx.arg8 = req.side;

  tx.eddsaSig = req.eddsaSig;

  const isSell = req.side === '1';
  const MQ = BigInt(isSell ? req.sellAmt : req.buyAmt);
  const BQ = BigInt(isSell ? req.buyAmt : req.sellAmt);
  const daysFromExpired = (BigInt(req.maturityTime) - BigInt(req.expiredTime)) / BigInt(86400);
  const daysFromCurrent = (BigInt(req.maturityTime) - BigInt(currentTime)) / BigInt(86400);
  const takerFeeRate = BigInt(req.takerFee);
  // const makerFeeRate = BigInt(req.makerFee);
  const maxFeeRate = takerFeeRate;
  const lockedAmt = calcSecondaryLockedAmt(tx.reqType === TsTxType.SECOND_LIMIT_ORDER, isSell, MQ, BQ, daysFromCurrent, daysFromExpired, maxFeeRate);
  tx.metadata = {
    orderId,
    tsPubKeyX: tsPubKey[0].toString(),
    tsPubKeyY: tsPubKey[1].toString(),
    maturityTime,
    bondTokenId: isSell ? tx.tokenId : tx.arg4,
    feeTokenId: isSell ? tx.arg4 : tx.tokenId,
    lockedAmt: lockedAmt.toString(),
  };
  return tx;
}

export function encodeTokenLeaf(token: TsTokenInfo): TsTokenLeafEncodeType {
  return [
    BigInt(token.amount),
    BigInt(token.lockAmt),
  ];
}


export function encodeRChunkBuffer(txTransferReq: TransactionInfo, metadata?: {
  txOffset?: bigint,
  oriMatchedInterest?: bigint,
  collateralTokenId?: bigint,
  collateralAmt?: bigint,
  debtTokenId?: bigint,
  debtAmt?: bigint,
  maturityTime?: bigint,
  accountId?: bigint,
  receiverId?: bigint,
  makerBuyAmt?: bigint,
  borrowingAmt?: bigint,
  forceWithdrawAmt?: bigint,
  withdrawFeeAmt?: bigint,
  bondTokenId?: bigint,
  matchedTime?: bigint,
  txId?: bigint,
}) {

  switch (txTransferReq.reqType) {
    case TsTxType.REGISTER:
      if (!txTransferReq.arg0) {
        throw new Error('arg0 is required');
      }
      if (!txTransferReq.arg6) {
        throw new Error('tsAddr is required');
      }
      const out_r = utils.solidityPack(
        ['uint8', 'uint32', 'uint160',],
        [
          BigNumber.from(txTransferReq.reqType),
          BigNumber.from(txTransferReq.arg0),
          BigNumber.from(txTransferReq.arg6),
        ]
      ).replaceAll('0x', '');
      return {
        r_chunks: Buffer.concat([Buffer.from(out_r, 'hex')], MAX_CHUNKS_BYTES_PER_REQ),
        o_chunks: Buffer.concat([Buffer.from(out_r, 'hex')], 3 * CHUNK_BYTES_SIZE),
        isCritical: true,
      };
    case TsTxType.DEPOSIT:
      if (!txTransferReq.arg0) {
        throw new Error('arg0 is required');
      }
      const out_d = utils.solidityPack(
        ['uint8', 'uint32', 'uint16', 'uint128',],
        [
          BigNumber.from(txTransferReq.reqType),
          BigNumber.from(txTransferReq.arg0),
          BigNumber.from(txTransferReq.tokenId),
          BigNumber.from(txTransferReq.amount),
        ]
      ).replaceAll('0x', '');
      return {
        r_chunks: Buffer.concat([Buffer.from(out_d, 'hex')], MAX_CHUNKS_BYTES_PER_REQ),
        o_chunks: Buffer.concat([Buffer.from(out_d, 'hex')], 2 * CHUNK_BYTES_SIZE),
        isCritical: true,
      };
    case TsTxType.TRANSFER:
      const out_t = utils.solidityPack(
        ['uint8', 'uint32', 'uint16', 'uint40', 'uint32',],
        [
          BigNumber.from(txTransferReq.reqType),
          BigNumber.from(txTransferReq.accountId),
          BigNumber.from(txTransferReq.tokenId),
          BigNumber.from(amountToTxAmountV3_40bit(BigInt(txTransferReq.amount))),
          BigNumber.from(metadata?.receiverId),
        ]
      ).replaceAll('0x', '');
      return {
        r_chunks: Buffer.concat([Buffer.from(out_t, 'hex')], MAX_CHUNKS_BYTES_PER_REQ),
        o_chunks: Buffer.concat([Buffer.from(out_t, 'hex')], 2 * CHUNK_BYTES_SIZE),
        isCritical: false,
      };
    case TsTxType.FORCE_WITHDRAW:
      if (metadata?.forceWithdrawAmt === undefined) {
        throw new Error('forceWithdrawAmt is required');
      }
      const out_fw = utils.solidityPack(
        ['uint8', 'uint32', 'uint16', 'uint128',],
        [
          BigNumber.from(txTransferReq.reqType),
          BigNumber.from(txTransferReq.arg0),
          BigNumber.from(txTransferReq.tokenId),
          BigNumber.from(metadata.forceWithdrawAmt.toString()),
        ]
      ).replaceAll('0x', '');
      return {
        r_chunks: Buffer.concat([Buffer.from(out_fw, 'hex')], MAX_CHUNKS_BYTES_PER_REQ),
        o_chunks: Buffer.concat([Buffer.from(out_fw, 'hex')], 2 * CHUNK_BYTES_SIZE),
        isCritical: true,
      };
    case TsTxType.WITHDRAW:
      const out_w = utils.solidityPack(
        ['uint8', 'uint32', 'uint16', 'uint128',],
        [
          BigNumber.from(txTransferReq.reqType),
          BigNumber.from(txTransferReq.accountId),
          BigNumber.from(txTransferReq.tokenId),
          BigNumber.from(txTransferReq.amount),
        ]
      ).replaceAll('0x', '');
      return {
        r_chunks: Buffer.concat([Buffer.from(out_w, 'hex')], MAX_CHUNKS_BYTES_PER_REQ),
        o_chunks: Buffer.concat([Buffer.from(out_w, 'hex')], 2 * CHUNK_BYTES_SIZE),
        isCritical: true,
      };

    case TsTxType.SECOND_MARKET_ORDER:
      const out_smo = utils.solidityPack(
        ['uint8', 'uint32', 'uint16', 'uint40', 'uint40', 'uint16', 'uint40', 'uint32'],
        [
          BigNumber.from(txTransferReq.reqType),
          BigNumber.from(txTransferReq.accountId),
          BigNumber.from(txTransferReq.tokenId),
          BigNumber.from(amountToTxAmountV3_40bit(BigInt(txTransferReq.amount))),
          BigNumber.from(amountToTxAmountV3_40bit(BigInt(txTransferReq.fee0))),
          BigNumber.from(txTransferReq.arg4),
          BigNumber.from(amountToTxAmountV3_40bit(BigInt(txTransferReq.arg5))),
          BigNumber.from(txTransferReq.arg2),
        ]
      ).replaceAll('0x', '');
      return {
        r_chunks: Buffer.concat([Buffer.from(out_smo, 'hex')], MAX_CHUNKS_BYTES_PER_REQ),
        o_chunks: Buffer.concat([Buffer.from(out_smo, 'hex')], 2 * CHUNK_BYTES_SIZE),
        isCritical: false,
      };
    case TsTxType.SECOND_LIMIT_ORDER:
      const out_slo = utils.solidityPack(
        ['uint8', 'uint32', 'uint16', 'uint40', 'uint40', 'uint40', 'uint16', 'uint40', 'uint32', 'uint32'],
        [
          BigNumber.from(txTransferReq.reqType),
          BigNumber.from(txTransferReq.accountId),
          BigNumber.from(txTransferReq.tokenId),
          BigNumber.from(amountToTxAmountV3_40bit(BigInt(txTransferReq.amount))),
          BigNumber.from(amountToTxAmountV3_40bit(BigInt(txTransferReq.fee0))),
          BigNumber.from(amountToTxAmountV3_40bit(BigInt(txTransferReq.fee1))),
          BigNumber.from(txTransferReq.arg4),
          BigNumber.from(amountToTxAmountV3_40bit(BigInt(txTransferReq.arg5))),
          BigNumber.from(txTransferReq.arg2),
          BigNumber.from(metadata?.matchedTime),
        ]
      ).replaceAll('0x', '');
      return {
        r_chunks: Buffer.concat([Buffer.from(out_slo, 'hex')], MAX_CHUNKS_BYTES_PER_REQ),
        o_chunks: Buffer.concat([Buffer.from(out_slo, 'hex')], 3 * CHUNK_BYTES_SIZE),
        isCritical: false,
      };
    case TsTxType.SECOND_LIMIT_START:
      if (!metadata?.txOffset) {
        throw new Error('txOffset is required');
      }
      const out_sls = utils.solidityPack(
        ['uint8', 'uint32'],
        [
          BigNumber.from(txTransferReq.reqType),
          BigNumber.from(metadata?.txOffset),
        ]
      ).replaceAll('0x', '');
      return {
        r_chunks: Buffer.concat([Buffer.from(out_sls, 'hex')], MAX_CHUNKS_BYTES_PER_REQ),
        o_chunks: Buffer.concat([Buffer.from(out_sls, 'hex')], 1 * CHUNK_BYTES_SIZE),
        isCritical: false,
      };
    case TsTxType.SECOND_LIMIT_EXCHANGE:
    case TsTxType.SECOND_MARKET_EXCHANGE:
      if (!metadata?.txOffset) {
        throw new Error('txOffset is required');
      }
      if (!metadata?.makerBuyAmt) {
        throw new Error('buyAmt is required');
      }
      const out_sle = utils.solidityPack(
        ['uint8', 'uint32', 'uint40'],
        [
          BigNumber.from(txTransferReq.reqType),
          BigNumber.from(metadata?.txOffset),
          BigNumber.from(amountToTxAmountV3_40bit(metadata?.makerBuyAmt)),
        ]
      ).replaceAll('0x', '');
      return {
        r_chunks: Buffer.concat([Buffer.from(out_sle, 'hex')], MAX_CHUNKS_BYTES_PER_REQ),
        o_chunks: Buffer.concat([Buffer.from(out_sle, 'hex')], 1 * CHUNK_BYTES_SIZE),
        isCritical: false,
      };
    case TsTxType.SECOND_LIMIT_END:
    case TsTxType.SECOND_MARKET_END:
      const out_slend = utils.solidityPack(
        ['uint8', 'uint32'],
        [
          BigNumber.from(txTransferReq.reqType),
          BigNumber.from(metadata?.matchedTime),
        ]
      ).replaceAll('0x', '');
      return {
        r_chunks: Buffer.concat([Buffer.from(out_slend, 'hex')], MAX_CHUNKS_BYTES_PER_REQ),
        o_chunks: Buffer.concat([Buffer.from(out_slend, 'hex')], 1 * CHUNK_BYTES_SIZE),
        isCritical: false,
      };
    case TsTxType.AUCTION_LEND:
      const out_aorder_lender = utils.solidityPack(
        ['uint8', 'uint32', 'uint16', 'uint40', 'uint40', 'uint32', 'uint32'],
        [
          BigNumber.from(txTransferReq.reqType),
          BigNumber.from(txTransferReq.accountId),
          BigNumber.from(txTransferReq.tokenId),
          BigNumber.from(amountToTxAmountV3_40bit(BigInt(txTransferReq.amount))),
          BigNumber.from(amountToTxAmountV3_40bit(BigInt(txTransferReq.fee0))),
          BigNumber.from(BigInt(txTransferReq.arg1)),
          BigNumber.from(metadata?.matchedTime),
        ]
      ).replaceAll('0x', '');
      return {
        r_chunks: Buffer.concat([Buffer.from(out_aorder_lender, 'hex')], MAX_CHUNKS_BYTES_PER_REQ),
        o_chunks: Buffer.concat([Buffer.from(out_aorder_lender, 'hex')], 3 * CHUNK_BYTES_SIZE),
        isCritical: false,
      };
    case TsTxType.AUCTION_BORROW:
      if (!metadata?.borrowingAmt) {
        throw new Error('borrowingAmt is required');
      }
      const out_aorder_borrower = utils.solidityPack(
        ['uint8', 'uint32', 'uint16', 'uint40', 'uint40', 'uint40', 'uint32'],
        [
          BigNumber.from(txTransferReq.reqType),
          BigNumber.from(txTransferReq.accountId),
          BigNumber.from(txTransferReq.tokenId),
          BigNumber.from(amountToTxAmountV3_40bit(BigInt(txTransferReq.amount))),
          BigNumber.from(amountToTxAmountV3_40bit(BigInt(txTransferReq.fee0))),
          BigNumber.from(amountToTxAmountV3_40bit(metadata?.borrowingAmt)),
          BigNumber.from(metadata?.matchedTime),
        ]
      ).replaceAll('0x', '');
      return {
        r_chunks: Buffer.concat([Buffer.from(out_aorder_borrower, 'hex')], MAX_CHUNKS_BYTES_PER_REQ),
        o_chunks: Buffer.concat([Buffer.from(out_aorder_borrower, 'hex')], 3 * CHUNK_BYTES_SIZE),
        isCritical: false,
      };
    case TsTxType.CANCEL_ORDER:
      if (!metadata?.txId) {
        throw new Error('txOffset is required');
      }
      const out_co = utils.solidityPack(
        ['uint8', 'uint64'],
        [
          BigNumber.from(txTransferReq.reqType),
          BigNumber.from(metadata?.txId.toString()),
        ]
      ).replaceAll('0x', '');
      return {
        r_chunks: Buffer.concat([Buffer.from(out_co, 'hex')], MAX_CHUNKS_BYTES_PER_REQ),
        o_chunks: Buffer.concat([Buffer.from(out_co, 'hex')], 1 * CHUNK_BYTES_SIZE),
        isCritical: false,
      };
    case TsTxType.AUCTION_START:
      if (!metadata?.txOffset) {
        throw new Error('txOffset is required');
      }
      const out_als = utils.solidityPack(
        ['uint8', 'uint32', 'uint40'],
        [
          BigNumber.from(txTransferReq.reqType),
          BigNumber.from(metadata?.txOffset.toString()),
          BigNumber.from(amountToTxAmountV3_40bit(BigInt(metadata?.oriMatchedInterest ?? 0))),
        ]
      ).replaceAll('0x', '');
      return {
        r_chunks: Buffer.concat([Buffer.from(out_als, 'hex')], MAX_CHUNKS_BYTES_PER_REQ),
        o_chunks: Buffer.concat([Buffer.from(out_als, 'hex')], 1 * CHUNK_BYTES_SIZE),
        isCritical: false,
      };
    case TsTxType.AUCTION_MATCH:
      if (!metadata?.txOffset) {
        throw new Error('txOffset is required');
      }
      const out_ale = utils.solidityPack(
        ['uint8', 'uint32'],
        [
          BigNumber.from(txTransferReq.reqType),
          BigNumber.from(metadata?.txOffset.toString()),
        ]
      ).replaceAll('0x', '');
      return {
        r_chunks: Buffer.concat([Buffer.from(out_ale, 'hex')], MAX_CHUNKS_BYTES_PER_REQ),
        o_chunks: Buffer.concat([Buffer.from(out_ale, 'hex')], 1 * CHUNK_BYTES_SIZE),
        isCritical: false,
      };
    case TsTxType.AUCTION_END:
      const out_alend = utils.solidityPack(
        ['uint8', 'uint32', 'uint16', 'uint128', 'uint16', 'uint128', 'uint32'],
        [
          BigNumber.from(txTransferReq.reqType),
          BigNumber.from(metadata?.accountId?.toString()),
          BigNumber.from(metadata?.collateralTokenId?.toString()),
          BigNumber.from(metadata?.collateralAmt?.toString()),
          BigNumber.from(metadata?.bondTokenId?.toString()),
          BigNumber.from(metadata?.debtAmt?.toString()),
          BigNumber.from(metadata?.matchedTime),
        ]
      ).replaceAll('0x', '');

      return {
        r_chunks: Buffer.concat([Buffer.from(out_alend, 'hex')], MAX_CHUNKS_BYTES_PER_REQ),
        o_chunks: Buffer.concat([Buffer.from(out_alend, 'hex')], 4 * CHUNK_BYTES_SIZE),
        isCritical: true,
      };
    case TsTxType.INCREASE_EPOCH:
      const out_increase_epoch = utils.solidityPack(
        ['uint8'],
        [
          BigNumber.from(txTransferReq.reqType),
        ]
      ).replaceAll('0x', '');
      return {
        r_chunks: Buffer.concat([Buffer.from(out_increase_epoch, 'hex')], MAX_CHUNKS_BYTES_PER_REQ),
        o_chunks: Buffer.concat([Buffer.from(out_increase_epoch, 'hex')], 1 * CHUNK_BYTES_SIZE),
        isCritical: false,
      };
    case TsTxType.CREATE_BOND_TOKEN:
      const out_cbt = utils.solidityPack(
        ['uint8', 'uint32', 'uint16', 'uint16'],
        [
          BigNumber.from(txTransferReq.reqType),
          BigNumber.from(txTransferReq.arg1),
          BigNumber.from(txTransferReq.arg4),
          BigNumber.from(txTransferReq.tokenId),
        ]
      ).replaceAll('0x', '');
      return {
        r_chunks: Buffer.concat([Buffer.from(out_cbt, 'hex')], MAX_CHUNKS_BYTES_PER_REQ),
        o_chunks: Buffer.concat([Buffer.from(out_cbt, 'hex')], 1 * CHUNK_BYTES_SIZE),
        isCritical: true,
      };
    case TsTxType.REDEEM:
      const out_rd = utils.solidityPack(
        ['uint8', 'uint32', 'uint16', 'uint128'],
        [
          BigNumber.from(txTransferReq.reqType),
          BigNumber.from(txTransferReq.accountId),
          BigNumber.from(txTransferReq.tokenId),
          BigNumber.from(txTransferReq.amount),
        ]
      ).replaceAll('0x', '');
      return {
        r_chunks: Buffer.concat([Buffer.from(out_rd, 'hex')], MAX_CHUNKS_BYTES_PER_REQ),
        o_chunks: Buffer.concat([Buffer.from(out_rd, 'hex')], 2 * CHUNK_BYTES_SIZE),
        isCritical: false,
      };
    case TsTxType.WITHDRAW_FEE:
      if (metadata?.withdrawFeeAmt === undefined) {
        throw new Error('withdrawFeeAmt is required');
      }
      const out_wf = utils.solidityPack(
        ['uint8', 'uint16', 'uint128'],
        [
          BigNumber.from(txTransferReq.reqType),
          BigNumber.from(txTransferReq.tokenId),
          BigNumber.from(metadata.withdrawFeeAmt.toString()),
        ]
      ).replaceAll('0x', '');
      return {
        r_chunks: Buffer.concat([Buffer.from(out_wf, 'hex')], MAX_CHUNKS_BYTES_PER_REQ),
        o_chunks: Buffer.concat([Buffer.from(out_wf, 'hex')], 2 * CHUNK_BYTES_SIZE),
        isCritical: true,
      };
    case TsTxType.SET_ADMIN_TS_ADDR:
      const out_sat = utils.solidityPack(
        ['uint8'],
        [
          BigNumber.from(txTransferReq.reqType),
        ]
      ).replaceAll('0x', '');
      return {
        r_chunks: Buffer.concat([Buffer.from(out_sat, 'hex')], MAX_CHUNKS_BYTES_PER_REQ),
        o_chunks: Buffer.concat([Buffer.from(out_sat, 'hex')], 1 * CHUNK_BYTES_SIZE),
        isCritical: false,
      };
    case TsTxType.NOOP:
      return {
        r_chunks: Buffer.alloc(MAX_CHUNKS_BYTES_PER_REQ),
        o_chunks: Buffer.concat([Buffer.from('00', 'hex')], 1 * CHUNK_BYTES_SIZE),
        isCritical: false,
      };
    default:
      throw new Error(`unknown reqType=${txTransferReq.reqType}`);
  }

}

export function txsToRollupCircuitInput<T, B>(obj: any[], initData: any = {}): TsRollupCircuitInputType {
  obj.forEach((item) => {
    txToCircuitInput(item, initData);
  });
  return initData;
}
export function bigint_to_chunk_arrayV2(x: Buffer, chunkBytes: number): bigint[] {
  const ret: bigint[] = [];
  for (let i = x.length - 1; i >= 0; i -= chunkBytes) {
    let val = 0n;
    for (let offset = 0; offset < chunkBytes; offset++) {
      const element = x[i - offset];
      val += BigInt(element) << BigInt(offset * 8);
    }
    ret.push(val);
  }
  return ret;
}
export function bigint_to_chunk_array(x: bigint, chunkBits: bigint): bigint[] {
  const mod = 2n ** BigInt(chunkBits);

  const ret: bigint[] = [];
  let x_temp: bigint = x;
  while (x_temp > 0n) {
    ret.push(x_temp % mod);
    x_temp = x_temp >> chunkBits;
  }
  return ret.reverse();
}



export function txToCircuitInput(obj: any, initData: any = {}) {
  const result: any = initData;
  Object.keys(obj).forEach((key) => {
    const item = obj[key];
    if (!result[key]) {
      result[key] = [];
    }

    result[key].push(recursiveToString(item));
  });

  return result;
}

export function toTreeLeaf(inputs: bigint[]) {
  return dpPoseidonHash(inputs);
}

export function amountToTxAmountV2(number: bigint): bigint { // 48bit
  const sign = number >> 127n << 47n;
  const fraction = number - sign;
  const fractionLength = BigInt(fraction.toString(2).length);
  const bias = (1n << 5n) - 1n;
  const exp = fractionLength - 28n + bias;
  const modNumber = (fractionLength > 0n) ? 1n << (fractionLength - 1n) : 1n;

  const modifiedFraction = fraction % modNumber;
  const modifiedFractionLength = (fractionLength > 0n) ? fractionLength - 1n : 0n;
  const finalFraction = (modifiedFractionLength < 41n)
    ? modifiedFraction << (41n - modifiedFractionLength)
    : modifiedFraction >> (modifiedFractionLength - 41n);
  const retVal = sign + (exp << 41n) + finalFraction;
  return retVal;
}


export function amountToTxAmountV3_40bit(number: bigint): bigint {
  let val_exp = 0n;
  if (number === 0n) {
    return 0n;
  }
  while (number % 10n === 0n) {
    number /= 10n;
    val_exp += 1n;
  }
  return number + (val_exp << 35n);
}

export function arrayChunkToHexString(arr: string[], chunkSize: number = CHUNK_BYTES_SIZE) {
  const hex = arr.map((e) => {
    return BigInt(e).toString(16).padStart(chunkSize * 2, '0');
  }).join('');

  return '0x' + hex;
}
