import { RollupCore, TsRollupConfigType, calcAuctionCalcBorrowFee, calcAuctionCalcLendFee, calcBQ, calcSecondaryFee, calcSecondaryLockedAmt } from '../lib/ts-rollup/ts-rollup';
import { expect } from 'chai';
import path from 'path';
import { after, before } from 'mocha';

import { CircuitInputsExporter, createMainCircuit } from './helper/test-helper';
import { acc1Priv, acc2Priv, isTestCircuitRun, testArgs } from './helper/test-config';
import { RESERVED_ACCOUNTS } from '../lib/ts-rollup/ts-env';
import { convertDepositReq2TxEntity, convertRegisterReq2TxEntity, convertWithdrawReq2TxEntity, convertLendOrderReq2TxEntity, convertBorrowOrderReq2TxEntity, convertCancelOrderReq2TxEntity, convertLimitOrderReq2TxEntity, convertTransferReq2TxEntity, convertRedeemReq2TxEntity, convertMarketOrderReq2TxEntity } from '../lib/ts-rollup/ts-rollup-helper';
import { getEmptyTx, TransactionInfo } from '../lib/ts-types/mock-types';
import { stateToCommitment } from './helper/commitment.helper';
import fs from 'fs';
import { BigNumber } from 'ethers';
import { MIN_DEPOSIT_AMOUNT, TsRollupSigner, asyncEdDSA, dpPoseidonHash, TsTxRegisterRequest, TsTxType, TsTokenId, TsTxDepositNonSignatureRequest, TS_BASE_TOKEN, TsSecondOrderType } from 'term-structure-sdk';
// eslint-disable-next-line @typescript-eslint/no-var-requires
const circom_tester = require('circom_tester');
const wasm_tester = circom_tester.wasm;
const TsDecimalScale = BigNumber.from(10).pow(8);
const config: TsRollupConfigType = {
  order_tree_height: 8,
  account_tree_height: 10,
  token_tree_height: 8,
  nullifier_tree_height: 6,
  fee_tree_height: 3,
  bond_tree_height: 8,
  numOfReqs: 3,
  numOfChunks: 31,
};
const mainSuffix = `${config.order_tree_height}-${config.account_tree_height}-${config.token_tree_height}-${config.nullifier_tree_height}-${config.fee_tree_height}-${config.numOfReqs}-${config.numOfChunks}`;
const name = 'zkTrueUp';
const mainCircuitName = `${name}-${mainSuffix}`;

const outputPath = path.resolve(__dirname, `../build/${mainCircuitName}`).replace(/\\/g, '/');
const circuitsSrcPath = path.resolve(__dirname, '../testdata', mainCircuitName).replace(/\\/g, '/');
const circuitMainPath = path.resolve(outputPath, `./${mainCircuitName}.circom`).replace(/\\/g, '/');
if(!fs.existsSync(circuitsSrcPath)) {
  fs.mkdirSync(circuitsSrcPath);
}

type StateType = {
  oriStateRoot: string,
  newStateRoot: string,
  oriTsRoot: string,
  newTsRoot: string,
  pubdata: string
  newBlockTimestamp: number,
};
const NOW = Date.now();

describe.skip(`${mainCircuitName} test, waiting for backend testing`, function () {
  this.timeout(1000 * 1000);
  let stateLogGlobal!: StateType;

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  let mainCircuit: any;
  let rollup!: RollupCore;
  let acc1Signer!: TsRollupSigner;
  let acc2Signer!: TsRollupSigner;
  const acc1Id = RESERVED_ACCOUNTS;
  const acc2Id = RESERVED_ACCOUNTS + 1n;
  const exporter = new CircuitInputsExporter(
    mainCircuitName,
    config, mainSuffix, circuitsSrcPath, circuitMainPath
  );
  let metadata: any = {};
  const underlyingAmt = '1000000000';
  const collateralAmt = '1500000';
  const interest = 0.05;
  const maturityTime = '1704067199';
  before(async function () {
    await asyncEdDSA;
    rollup = new RollupCore(config);
    acc1Signer = new TsRollupSigner(acc1Priv);
    acc2Signer = new TsRollupSigner(acc2Priv);
    const accountTreeRoot = rollup.mkAccountTree.getRoot();
    const orderTreeRoot = rollup.mkOrderTree.getRoot();
    const defaultAccountLeafData = [...rollup.defaultAccountLeafData];
    const defaultTokenLeaf = rollup.defaultTokenLeaf;
    const defaultTokenRoot = rollup.defaultTokenRoot;
    const defaultNulliferRoot = rollup.defaultNullifierRoot;
    const defaultOrder = rollup.getDefaultOrder();
    const stateRoot = rollup.stateRoot;
    metadata = {
      oriTxNum: rollup.oriTxId,
      stateRoot,
      accountTreeRoot,
      defaultAccountLeafData,
      defaultTokenLeaf,
      defaultTokenRoot,
      defaultNulliferRoot,
      orderTreeRoot,
      defaultOrderLeafData: defaultOrder.encodeLeafMessage(),
      defaultOrderLeaf: defaultOrder.encodeLeafHash(),
    };
    await exporter.exportOthers('initStates', metadata);

    const mainPath = createMainCircuit(circuitMainPath, config, name, metadata);
    if(isTestCircuitRun) {
      mainCircuit = await wasm_tester(mainPath, {
        recompile: testArgs.circuitRecompile,
        output: path.resolve(__dirname, `../build/${mainCircuitName}`)
      });
    } else {
      console.warn('Skip circuit test');
    }
  });

  after(async function () {
    await exporter.exportInfo();
    fs.writeFileSync(path.resolve(circuitsSrcPath, './txList.json'), JSON.stringify(txList, null, 2));
  });

  beforeEach(async function () {
    stateLogGlobal = {
      oriStateRoot: '',
      newStateRoot: '',
      oriTsRoot: '',
      newTsRoot: '',
      pubdata: '',
      newBlockTimestamp: 0,
    };
  });
  const txList: TransactionInfo[] = [];

  it('tx noop', async function() {
    const reqs = new Array(config.numOfReqs).fill(0).map(() => getEmptyTx());
    const { newInputs, rawInputs, inputs } = await rollup.startRollup(async (rp) => {
      for (const req of reqs) {
        txList.push(req);
        await rp.doTransaction(req);
      }
    });
    const state = exporter.exportInputs(`noop-${mainSuffix}`, rawInputs, newInputs, inputs, mainCircuitName, stateLogGlobal);
    await expectCircuitPass(newInputs, state);
  });

  it('create bond token', async function() {
    const ETHBondTx = getEmptyTx();
    ETHBondTx.reqType = TsTxType.CREATE_BOND_TOKEN;
    ETHBondTx.tokenId = TsTokenId.TslETH20231231;
    ETHBondTx.arg1 = maturityTime;
    ETHBondTx.arg4 = TsTokenId.ETH;

    const WBTCBondTx = getEmptyTx();
    WBTCBondTx.reqType = TsTxType.CREATE_BOND_TOKEN;
    WBTCBondTx.tokenId = TsTokenId.TslWBTC20231231;
    WBTCBondTx.arg1 = maturityTime;
    WBTCBondTx.arg4 = TsTokenId.WBTC;

    const usdtBondTx = getEmptyTx();
    usdtBondTx.reqType = TsTxType.CREATE_BOND_TOKEN;
    usdtBondTx.tokenId = TsTokenId.TslUSDT20231231;
    usdtBondTx.arg1 = maturityTime;
    usdtBondTx.arg4 = TsTokenId.USDT;

    const { newInputs, rawInputs, inputs } = await rollup.startRollup(async (rp) => {
      for (const req of [
        ETHBondTx, WBTCBondTx, usdtBondTx,
      ]) {
        txList.push(req);
        await rp.doTransaction(req);
      }
    });
    const state = exporter.exportInputs(`create-bond-${mainSuffix}`, rawInputs, newInputs, inputs, mainCircuitName, stateLogGlobal);
    await expectCircuitPass(newInputs, state);
  });

  it('RegisterAndDepost acc1', async function() {
    const reqisterReq: TsTxRegisterRequest = {
      receiverId: acc1Id.toString(),
      reqType: TsTxType.REGISTER,
      tokenId: TsTokenId.UNKNOWN,
      amount: '0',
      tsAddr: BigInt(acc1Signer.tsAddr).toString(),
      nonce: '0',
    };
    const depositReq: TsTxDepositNonSignatureRequest = {
      reqType: TsTxType.DEPOSIT,
      receiverId: acc1Id.toString(),
      tokenId: TsTokenId.USDT,
      amount: l1AmtToL2Amt(TsTokenId.USDT, (10 ** 6 * MIN_DEPOSIT_AMOUNT.USDT * 10000).toString()),
      nonce: '0',
    };
    const txReq1 = convertRegisterReq2TxEntity(reqisterReq, acc1Signer.tsPubKey);
    const txReq2 = convertDepositReq2TxEntity(depositReq, acc1Signer.tsPubKey);
    const txReq3 = getEmptyTx();
    const reqs = [txReq1, txReq2, txReq3];

    const { newInputs, rawInputs, inputs } = await rollup.startRollup(async (rp) => {
      for(const req of reqs) {
        txList.push(req);
        await rp.doTransaction(req);
      }
    });

    const state = exporter.exportInputs(`register-acc1-${mainSuffix}`, rawInputs, newInputs, inputs, mainCircuitName, stateLogGlobal);
    await expectCircuitPass(newInputs, state);
  });

  it('Deposit exist token', async function() {
    const depositReqs: TsTxDepositNonSignatureRequest[] = new Array(3).fill(0)
      .map((_, i) => ({
        reqType: TsTxType.DEPOSIT,
        receiverId: acc1Id.toString(),
        tokenId: TsTokenId.USDT,
        amount: l1AmtToL2Amt(TsTokenId.USDT, (10 ** 6 * MIN_DEPOSIT_AMOUNT.USDT * 10000).toString()),
        nonce: '0',
      }));
    const { newInputs, rawInputs, inputs } = await rollup.startRollup(async (rp) => {
      for(const req of depositReqs) {
        const txReq = convertDepositReq2TxEntity(req, acc1Signer.tsPubKey);
        txList.push(txReq);
        await rp.doTransaction(txReq);
      }
    });
    const state = exporter.exportInputs(`deposit-acc1-usdt-${mainSuffix}`, rawInputs, newInputs, inputs, mainCircuitName, stateLogGlobal);
    await expectCircuitPass(newInputs, state);
    return true;
  });

  it('Register And Deposit acc2', async function() {
    const reqisterReq2: TsTxRegisterRequest = {
      receiverId: acc2Id.toString(),
      reqType: TsTxType.REGISTER,
      tokenId: TsTokenId.UNKNOWN,
      amount: '0',
      tsAddr: BigInt(acc2Signer.tsAddr).toString(),
      nonce: '0',
    };
    const depositReqs: TsTxDepositNonSignatureRequest[] = new Array(1).fill(0).map((_, i) => ({
      reqType: TsTxType.DEPOSIT,
      receiverId: acc2Id.toString(),
      tokenId: TsTokenId.ETH,
      amount: l1AmtToL2Amt(TsTokenId.ETH, (10 ** 18 * MIN_DEPOSIT_AMOUNT.ETH * 3000).toString()),
      nonce: '0',
    }));

    const txReq = convertRegisterReq2TxEntity(reqisterReq2, acc2Signer.tsPubKey);
    const txReq2 = convertDepositReq2TxEntity(depositReqs[0], acc2Signer.tsPubKey);
    const reqs = [txReq, txReq2, getEmptyTx()];
    const { newInputs, rawInputs, inputs } = await rollup.startRollup(async (rp) => {
      for(const req of reqs) {
        txList.push(req);
        await rp.doTransaction(req);
      }
    });

    const state = exporter.exportInputs(`register-acc1-${mainSuffix}`, rawInputs, newInputs, inputs, mainCircuitName, stateLogGlobal);
    await expectCircuitPass(newInputs, state);
  });

  it('Deposit non-exist token', async function() {
    const depositReqs: TsTxDepositNonSignatureRequest[] = new Array(3).fill(0).map((_, i) => ({
      reqType: TsTxType.DEPOSIT,
      receiverId: acc2Id.toString(),
      tokenId: TsTokenId.USDT,
      amount: l1AmtToL2Amt(TsTokenId.USDT, (10 ** 6 * MIN_DEPOSIT_AMOUNT.USDT * 200000).toString()),
      nonce: '0',
    }));
    const { newInputs, rawInputs, inputs } = await rollup.startRollup(async (rp) => {
      for(const req of depositReqs) {
        const txReq = convertDepositReq2TxEntity(req, acc2Signer.tsPubKey);
        txList.push(txReq);
        await rp.doTransaction(txReq);
      }
    });
    const state = exporter.exportInputs(`deposit-acc2-eth-${mainSuffix}`, rawInputs, newInputs, inputs, mainCircuitName, stateLogGlobal);
    await expectCircuitPass(newInputs, state);
    return true;
  });

  it('Withdraw', async function() {
    const currentNonce = rollup.getAccount(BigInt(acc1Id))?.nonce || 0n;
    const txWithdrawReqs = new Array(3).fill(0)
      .map((_, i) =>
        acc1Signer.prepareTxWithdraw({
          senderId: acc1Id.toString(),
          tokenId: TsTokenId.USDT,
          amount: BigInt(10 ** 8 * 1).toString(),
          nonce: (currentNonce + BigInt(i)).toString(),
        })
      );
    const { newInputs, rawInputs, inputs } = await rollup.startRollup(async (rp) => {
      for(const req of txWithdrawReqs) {
        const txReq = convertWithdrawReq2TxEntity(req, acc1Signer.tsPubKey);
        txList.push(txReq);
        await rp.doTransaction(txReq);
      }
    });
    const state = exporter.exportInputs(`withdraw-acc1-usdt-${mainSuffix}`, rawInputs, newInputs, inputs, mainCircuitName, stateLogGlobal);

    await expectCircuitPass(newInputs, state);
    return true;
  });

  let currentOrderId = 0;
  const lenderFee = '100000';
  const borrowerFee = '10000000';
  const expiredTime = Math.floor((NOW + 1000 * 60 * 60 * 24 * 7) / 1000).toString();
  it('Acc1 place Auction Lend order with ETH', async function() {
    const siger = acc1Signer;
    const aucLendReqs = new Array(1).fill(0)
      .map((_, i) =>
        siger.prepareTxAuctionLend({
          senderId: acc1Id.toString(),
          lendTokenId: TsTokenId.USDT,
          lendAmt: underlyingAmt,
          orderNonce: Math.floor(Math.random() * 100000).toString(),
          maturityTime,
          expiredTime,
          interest: getTxInterest(interest),
          epoch: '1',
          fee: lenderFee,
        })
      );

    const { newInputs, rawInputs, inputs } = await rollup.startRollup(async (rp) => {
      for(const req of aucLendReqs) {
        currentOrderId += 1;
        const txReq = convertLendOrderReq2TxEntity(currentOrderId.toString(), req, siger.tsPubKey);
        txList.push(txReq);
        await rp.doTransaction(txReq);
      }
    });

    const state = exporter.exportInputs(`auction-order-acc1-eth-${mainSuffix}`, rawInputs, newInputs, inputs, mainCircuitName, stateLogGlobal);
    await expectCircuitPass(newInputs, state);
    return true;
  });

  it('cancel acc1 lend order', async function() {
    const signer = acc1Signer;
    const aucLendReq = signer.prepareTxAuctionLend({
      senderId: acc1Id.toString(),
      lendTokenId: TsTokenId.USDT,
      lendAmt: underlyingAmt,
      orderNonce: '68958',
      maturityTime,
      expiredTime,
      interest: getTxInterest(interest),
      epoch: '1',
      fee: lenderFee,
    });
    const cancelOrderReq = signer.prepareTxCancelOrder({
      senderId: acc1Id.toString(),
      reqType: TsTxType.CANCEL_ORDER,
      txId: rollup.oriTxId.toString(),
      orderNum: '4',
    });
    currentOrderId += 1;
    const orderId = currentOrderId.toString();
    const txReq1 = convertLendOrderReq2TxEntity(orderId, aucLendReq, signer.tsPubKey);
    const txReq2 = convertCancelOrderReq2TxEntity(orderId, cancelOrderReq, signer.tsPubKey);
    const reqs = [txReq1, txReq2];
    const { newInputs, rawInputs, inputs } = await rollup.startRollup(async (rp) => {
      for(const req of reqs) {
        txList.push(req);
        await rp.doTransaction(req);
      }
    });
    const state = exporter.exportInputs(`cancel-order-acc1-lend-${mainSuffix}`, rawInputs, newInputs, inputs, mainCircuitName, stateLogGlobal);
    await expectCircuitPass(newInputs, state);
    return true;
  });

  it('Acc2 place borrow order with USDT collateral and boroow ETH', async function() {
    const signer = acc2Signer;
    const nonce = rollup.getAccount(acc2Id)?.nonce || 0n;
    const aucLendReqs = new Array(1).fill(0)
      .map((_, i) =>
        signer.prepareTxAuctionBorrow({
          senderId: acc2Id.toString(),
          collateralTokenId: TsTokenId.ETH,
          collateralAmt: collateralAmt,
          orderNonce: Math.floor(Math.random() * 100000).toString(),
          maturityTime,
          expiredTime,
          interest: getTxInterest(interest),
          borrowTokenId: TsTokenId.USDT,
          borrowAmt: underlyingAmt,
          epoch: '1',
          fee: borrowerFee,
        })
      );

    const { newInputs, rawInputs, inputs } = await rollup.startRollup(async (rp) => {
      for(const req of aucLendReqs) {
        currentOrderId += 1;
        const orderId = (currentOrderId).toString();
        const txReq = convertBorrowOrderReq2TxEntity(orderId, req, signer.tsPubKey);
        txList.push(txReq);
        await rp.doTransaction(txReq);
      }
    });

    const state = exporter.exportInputs(`auction-order-acc2-usdt-eth-${mainSuffix}`, rawInputs, newInputs, inputs, mainCircuitName, stateLogGlobal);
    await expectCircuitPass(newInputs, state);
    return true;
  });

  it('cancel acc2 borrow order', async function() {
    const signer = acc2Signer;
    const aucBorrowReq = signer.prepareTxAuctionBorrow({
      senderId: acc2Id.toString(),
      collateralTokenId: TsTokenId.ETH,
      collateralAmt: collateralAmt,
      orderNonce: '501',
      maturityTime,
      expiredTime,
      interest: getTxInterest(interest),
      borrowTokenId: TsTokenId.USDT,
      borrowAmt: underlyingAmt,
      epoch: '1',
      fee: borrowerFee,
    });
    const cancelOrderReq = signer.prepareTxCancelOrder({
      senderId: acc2Id.toString(),
      reqType: TsTxType.CANCEL_ORDER,
      txId: rollup.oriTxId.toString(),
      orderNum: '8',
    });
    currentOrderId += 1;
    const orderId = (currentOrderId).toString();
    const txReq1 = convertBorrowOrderReq2TxEntity(orderId, aucBorrowReq, signer.tsPubKey);
    const txReq2 = convertCancelOrderReq2TxEntity(orderId, cancelOrderReq, signer.tsPubKey);
    const reqs = [
      txReq1, txReq2, getEmptyTx()
    ];
    const { newInputs, rawInputs, inputs } = await rollup.startRollup(async (rp) => {
      for (const req of reqs) {
        txList.push(req);
        await rp.doTransaction(req);
      }
    });
    const state = exporter.exportInputs(`cancel-order-acc2-borrow-${mainSuffix}`, rawInputs, newInputs, inputs, mainCircuitName, stateLogGlobal);

    await expectCircuitPass(newInputs, state);
    return true;
  });

  let matchedBondAmount = 0n;
  it('full match auction tslETH', async function() {
    const matchedCollateralAmt = collateralAmt;

    const { newInputs, rawInputs, inputs } = await rollup.startRollup(async (rp) => {
      const matchedTime = rp.currentTime.toString();
      const days = (BigInt(maturityTime) - BigInt(matchedTime)) / 86400n;
      const bondAmount = (BigInt(underlyingAmt) * BigInt(interest * 100) / 100n * days / 365n) + BigInt(underlyingAmt);
      matchedBondAmount = bondAmount;
      console.log({
        interest,
        days,
        bondAmount,
      });

      const auctionStartTx = getEmptyTx();
      auctionStartTx.reqType = TsTxType.AUCTION_START;
      auctionStartTx.arg3 = getTxInterest(interest); // matchedInterest
      auctionStartTx.metadata = {
        orderId: '3',
        bondTokenId: TsTokenId.TslUSDT20231231,
        feeTokenId: TsTokenId.USDT,
        matchedTime,
      };
      txList.push(auctionStartTx);
      await rp.doTransaction(auctionStartTx);

      const auctionMatchTx = getEmptyTx();
      auctionMatchTx.reqType = TsTxType.AUCTION_MATCH;
      const feeAmtForLender = calcAuctionCalcLendFee(BigInt(lenderFee), BigInt(underlyingAmt), BigInt(days));
      auctionMatchTx.metadata = {
        orderId: '1',
        matchedLendAmt: underlyingAmt,
        matchedBondAmt: matchedBondAmount.toString(),
        bondTokenId: TsTokenId.TslUSDT20231231,
        feeTokenId: TsTokenId.USDT,
        feeAmt: feeAmtForLender.toString(),
        orderStatus: '2',
        matchedTime,
      };
      txList.push(auctionMatchTx);
      await rp.doTransaction(auctionMatchTx);


      const auctionEndTx = getEmptyTx();
      auctionEndTx.reqType = TsTxType.AUCTION_END;
      const feeAmtForBorrower = calcAuctionCalcBorrowFee(BigInt(borrowerFee), BigInt(underlyingAmt), BigInt(getTxInterest(interest)), BigInt(days));
      auctionEndTx.metadata = {
        orderId: '3',
        matchedCollateralAmt: matchedCollateralAmt,
        matchedBorrowAmt: underlyingAmt,
        matchedDebtAmt: bondAmount.toString(),
        feeTokenId: TsTokenId.USDT,
        feeAmt: feeAmtForBorrower.toString(),
        bondTokenId: TsTokenId.TslUSDT20231231,
        orderStatus: '2',
        matchedTime,
      };
      txList.push(auctionEndTx);
      await rp.doTransaction(auctionEndTx);
    });



    const state = exporter.exportInputs(`auction-order-match-eth-${mainSuffix}`, rawInputs, newInputs, inputs, mainCircuitName, stateLogGlobal);
    await expectCircuitPass(newInputs, state);
    return true;
  });



  let limitOrderId_acc1order1 = 0n;
  let limitOrderId_acc2order1 = 0n;
  const secondLimitSellTslAmt = (BigInt(underlyingAmt) / 4n).toString();
  const secondLimitBuyUsdtAmt = (BigInt(underlyingAmt) / 4n * 9n / 10n).toString();
  const takerFeeRate = '300000';
  const makerFeeRate = '100000';
  it('Acc1 place second limit order with sell TslUSDT', async function() {
    const nonce = rollup.getAccount(BigInt(acc1Id))?.nonce || 0n;
    const reqs = new Array(1).fill(0)
      .map((_, i) =>
        acc1Signer.prepareTxSecondLimitOrder({
          reqType: TsTxType.SECOND_LIMIT_ORDER,
          senderId: acc1Id.toString(),
          sellTokenId: TsTokenId.TslUSDT20231231,
          sellAmt: secondLimitSellTslAmt,
          maturityTime,
          expiredTime: Math.round((NOW + 1000 * 60 * 60 * 24 * 7) / 1000).toString(),
          orderNonce: (nonce + BigInt(i)).toString(),
          buyTokenId: TsTokenId.USDT,
          buyAmt: secondLimitBuyUsdtAmt,
          epoch: '1',
          side: TsSecondOrderType.SELL,
          takerFee: takerFeeRate,
          makerFee: makerFeeRate,
        })
      );

    const { newInputs, rawInputs, inputs } = await rollup.startRollup(async (rp) => {
      for(const req of reqs) {
        limitOrderId_acc1order1 = BigInt(currentOrderId++) + 1n;
        const txReq = convertLimitOrderReq2TxEntity(limitOrderId_acc1order1.toString(), req, maturityTime, acc1Signer.tsPubKey, Math.round(NOW / 1000).toString());
        txList.push(txReq);
        await rp.doTransaction(txReq);
      }
    });
    limitOrderId_acc1order1 = BigInt(inputs?.r_orderLeafId[0][0] || '0');

    const state = exporter.exportInputs(`second-order-acc1-sell-tslusdt-${mainSuffix}`, rawInputs, newInputs, inputs, mainCircuitName, stateLogGlobal);
    await expectCircuitPass(newInputs, state);
    return true;
  });

  it('Acc2 place second limit order with buy TslUSDT', async function() {
    const nonce = rollup.getAccount(BigInt(acc2Id))?.nonce || 0n;
    const obsReqs = new Array(1).fill(0)
      .map((_, i) =>
        acc2Signer.prepareTxSecondLimitOrder({
          reqType: TsTxType.SECOND_LIMIT_ORDER,
          senderId: acc2Id.toString(),
          sellTokenId: TsTokenId.USDT,
          sellAmt: secondLimitBuyUsdtAmt,
          maturityTime,
          expiredTime: Math.round((NOW + 1000 * 60 * 60 * 24 * 7) / 1000).toString(),
          orderNonce: (nonce + BigInt(i)).toString(),
          buyTokenId: TsTokenId.TslUSDT20231231,
          buyAmt: secondLimitSellTslAmt,
          epoch: '1',
          side: TsSecondOrderType.BUY,
          takerFee: takerFeeRate,
          makerFee: makerFeeRate,
        })
      );

    const { newInputs, rawInputs, inputs } = await rollup.startRollup(async (rp) => {
      for(const req of obsReqs) {
        limitOrderId_acc2order1 = BigInt(currentOrderId++) + 1n;
        const txReq = convertLimitOrderReq2TxEntity(limitOrderId_acc2order1.toString(), req, maturityTime, acc1Signer.tsPubKey, Math.round(NOW / 1000).toString());
        txList.push(txReq);
        await rp.doTransaction(txReq);
      }
    });
    limitOrderId_acc2order1 = BigInt(inputs?.r_orderLeafId[0][0] || '0');

    const state = exporter.exportInputs(`second-order-acc2-buy-tslusdt-${mainSuffix}`, rawInputs, newInputs, inputs, mainCircuitName, stateLogGlobal);
    await expectCircuitPass(newInputs, state);
    return true;
  });

  it('Limit Order matching', async function() {
    const MQ = BigInt(secondLimitSellTslAmt);
    const BQ = BigInt(secondLimitBuyUsdtAmt);
    const maturityTime = BigInt(1704067199);
    const days = (maturityTime - BigInt(Math.round(NOW / 1000))) / 86400n;
    const tkFeeRate = BigInt(takerFeeRate);
    const mkFeeRate = BigInt(makerFeeRate);
    const maxFeeRate = tkFeeRate > mkFeeRate ? tkFeeRate : mkFeeRate;

    const matchedMQ = MQ;
    const matchedBQ = calcBQ(MQ, MQ, BQ, days);
    const sellerMakerFee = calcSecondaryFee(mkFeeRate, matchedMQ, days);
    const buyerTakerFee = calcSecondaryFee(tkFeeRate, matchedMQ, days);

    const { newInputs, rawInputs, inputs } = await rollup.startRollup(async (rp) => {
      const matchedTime = rp.currentTime.toString();
      const tx1 = getEmptyTx();
      tx1.reqType = TsTxType.SECOND_LIMIT_START;
      tx1.metadata = {
        orderId: limitOrderId_acc2order1.toString(),
        orderStatus: '1',
        bondTokenId: TsTokenId.TslUSDT20231231,
        feeTokenId: TsTokenId.USDT,
        matchedTime,
      };
      await rp.doTransaction(tx1);

      const tx2 = getEmptyTx();
      tx2.reqType = TsTxType.SECOND_LIMIT_EXCHANGE;
      tx2.metadata = {
        orderId: limitOrderId_acc1order1.toString(),
        matchedSellAmt: matchedMQ.toString(),
        matchedBuyAmt: matchedBQ.toString(),
        orderStatus: '2',
        feeTokenId: TsTokenId.USDT,
        feeAmt: sellerMakerFee.toString(),
        bondTokenId: TsTokenId.TslUSDT20231231,
        matchedTime,
      };
      await rp.doTransaction(tx2);

      const tx3 = getEmptyTx();
      tx3.reqType = TsTxType.SECOND_LIMIT_END;
      tx3.metadata = {
        orderId: limitOrderId_acc2order1.toString(),
        matchedSellAmt: matchedBQ.toString(),
        matchedBuyAmt: matchedMQ.toString(),
        orderStatus: '2',
        feeTokenId: TsTokenId.USDT,
        feeAmt: buyerTakerFee.toString(),
        bondTokenId: TsTokenId.TslUSDT20231231,
        matchedTime,
      };
      await rp.doTransaction(tx3);
    });

    const state = exporter.exportInputs(`match-second-limit-${mainSuffix}`, rawInputs, newInputs, inputs, mainCircuitName, stateLogGlobal);

    await expectCircuitPass(newInputs, state);
    return true;
  });

  let marketOrderId1 = 0n;
  let marketOrderId2 = 0n;
  const limitMakerOrderAmt = 98039215;
  it('Market Order matching', async function() {
    const maturityTime = BigInt(1704067199);

    const reqLimit = acc1Signer.prepareTxSecondLimitOrder({
      reqType: TsTxType.SECOND_LIMIT_ORDER,
      senderId: acc1Id.toString(),
      sellTokenId: TsTokenId.TslUSDT20231231,
      sellAmt: secondLimitSellTslAmt,
      maturityTime: maturityTime.toString(),
      expiredTime: Math.round((NOW + 1000 * 60 * 60 * 24 * 7) / 1000).toString(),
      orderNonce: '123456789',
      buyTokenId: TsTokenId.USDT,
      buyAmt: secondLimitBuyUsdtAmt,
      epoch: '1',
      side: TsSecondOrderType.SELL,
      takerFee: takerFeeRate,
      makerFee: makerFeeRate,
    });
    const { newInputs: newInputs1, rawInputs: rawInputs1, inputs: inputs1 } = await rollup.startRollup(async (rp) => {
      marketOrderId1 = BigInt(currentOrderId++) + 1n;
      const txLimit = convertLimitOrderReq2TxEntity(marketOrderId1.toString(), reqLimit, maturityTime.toString(), acc1Signer.tsPubKey, Math.round(NOW / 1000).toString());
      await rp.doTransaction(txLimit);
    });
    const state1 = exporter.exportInputs(`place-limit-order-acc1-${mainSuffix}`, rawInputs1, newInputs1, inputs1, mainCircuitName, stateLogGlobal);
    await expectCircuitPass(newInputs1, state1);


    const { newInputs, rawInputs, inputs } = await rollup.startRollup(async (rp) => {
      const matchedTime = rp.currentTime.toString();
      const MQ = BigInt(secondLimitSellTslAmt);
      const BQ = BigInt(secondLimitBuyUsdtAmt);
      const days = (maturityTime - BigInt(matchedTime)) / 86400n;
      const tkFeeRate = BigInt(takerFeeRate);
      const mkFeeRate = BigInt(makerFeeRate);
      const maxFeeRate = tkFeeRate > mkFeeRate ? tkFeeRate : mkFeeRate;

      const matchedMQ = MQ;
      const matchedBQ = calcBQ(MQ, MQ, BQ, days);
      const sellerMakerFee = calcSecondaryFee(mkFeeRate, matchedMQ, days);
      const buyerTakerFee = calcSecondaryFee(tkFeeRate, matchedMQ, days);
      marketOrderId2 = BigInt(currentOrderId++) + 1n;


      
      const reqMarket = acc2Signer.prepareTxSecondMarketOrder({
        reqType: TsTxType.SECOND_MARKET_ORDER,
        senderId: acc2Id.toString(),
        sellTokenId: TsTokenId.USDT,
        sellAmt: matchedBQ.toString(),
        maturityTime: maturityTime.toString(),
        expiredTime: Math.round((NOW + 1000 * 60 * 60 * 24 * 7) / 1000).toString(),
        orderNonce: '12345678',
        buyTokenId: TsTokenId.TslUSDT20231231,
        buyAmt: matchedMQ.toString(),
        epoch: '1',
        side: TsSecondOrderType.BUY,
        takerFee: takerFeeRate,
      });

      console.log({
        MQ,
        BQ,
        matchedMQ,
        matchedBQ,
      });

      const tx1 = convertMarketOrderReq2TxEntity(marketOrderId2.toString(), reqMarket, maturityTime.toString(), acc2Signer.tsPubKey, Math.round(NOW / 1000).toString());
      tx1.reqType = TsTxType.SECOND_MARKET_ORDER;
      tx1.metadata = {
        orderId: marketOrderId2.toString(),
        orderStatus: '1',
        bondTokenId: TsTokenId.TslUSDT20231231,
        feeTokenId: TsTokenId.USDT,
        matchedTime,
      };
      await rp.doTransaction(tx1);

      const tx2 = getEmptyTx();
      tx2.reqType = TsTxType.SECOND_MARKET_EXCHANGE;
      tx2.metadata = {
        orderId: marketOrderId1.toString(),
        matchedSellAmt: matchedMQ.toString(),
        matchedBuyAmt: matchedBQ.toString(),
        orderStatus: '2',
        feeTokenId: TsTokenId.USDT,
        feeAmt: sellerMakerFee.toString(),
        bondTokenId: TsTokenId.TslUSDT20231231,
        matchedTime,
      };
      await rp.doTransaction(tx2);

      const tx3 = getEmptyTx();
      tx3.reqType = TsTxType.SECOND_MARKET_END;
      tx3.metadata = {
        orderId: marketOrderId2.toString(),
        matchedSellAmt: matchedBQ.toString(),
        matchedBuyAmt: matchedMQ.toString(),
        orderStatus: '2',
        feeTokenId: TsTokenId.USDT,
        feeAmt: buyerTakerFee.toString(),
        bondTokenId: TsTokenId.TslUSDT20231231,
        matchedTime,
      };
      await rp.doTransaction(tx3);
    });

    const state = exporter.exportInputs(`match-second-market-${mainSuffix}`, rawInputs, newInputs, inputs, mainCircuitName, stateLogGlobal);

    await expectCircuitPass(newInputs, state);
    return true;
  });

  it('transfer USDT from acc1 to acc2', async function() {
    const currentNonce = rollup.getAccount(BigInt(acc1Id))?.nonce || 0n;
    const reqs = new Array(3).fill(0).map((_, i) => acc1Signer.prepareTxTransfer({
      reqType: TsTxType.TRANSFER,
      receiverId: acc2Id.toString(),
      tokenId: TsTokenId.USDT,
      amount: '100',
      senderId: acc1Id.toString(),
      nonce: (currentNonce + BigInt(i)).toString(),
    }));
    const { newInputs, rawInputs, inputs } = await rollup.startRollup(async (rp) => {
      for(const req of reqs) {
        const txReq = convertTransferReq2TxEntity(req, acc1Signer.tsPubKey);
        txList.push(txReq);
        await rp.doTransaction(txReq);
      }
    });
    const state = exporter.exportInputs(`transfer-acc1-usdt-${mainSuffix}`, rawInputs, newInputs, inputs, mainCircuitName, stateLogGlobal);
    await expectCircuitPass(newInputs, state);
  });

  it('transfer ETH from acc2 to acc1', async function() {
    const currentNonce = rollup.getAccount(BigInt(acc2Id))?.nonce || 0n;
    const reqs = new Array(3).fill(0).map((_, i) => acc2Signer.prepareTxTransfer({
      reqType: TsTxType.TRANSFER,
      receiverId: acc2Id.toString(),
      tokenId: TsTokenId.ETH,
      amount: '1',
      senderId: acc2Id.toString(),
      nonce: (currentNonce + BigInt(i)).toString(),
    }));
    const { newInputs, rawInputs, inputs } = await rollup.startRollup(async (rp) => {
      for(const req of reqs) {
        const txReq = convertTransferReq2TxEntity(req, acc1Signer.tsPubKey);
        txList.push(txReq);
        await rp.doTransaction(txReq);
      }
    });
    const state = exporter.exportInputs(`transfer-acc2-eth-${mainSuffix}`, rawInputs, newInputs, inputs, mainCircuitName, stateLogGlobal);
    await expectCircuitPass(newInputs, state);
  });

  it('increase epoch 1 -> 3', async function() {
    const { newInputs, rawInputs, inputs } = await rollup.startRollup(async (rp) => {
      const tx1 = getEmptyTx();
      tx1.reqType = TsTxType.INCREASE_EPOCH;
      await rp.doTransaction(tx1);

      const tx2 = getEmptyTx();
      await rp.doTransaction(tx2);

      const tx3 = getEmptyTx();
      await rp.doTransaction(tx3);
    });

    const state = exporter.exportInputs(`increase-epoch-${mainSuffix}`, rawInputs, newInputs, inputs, mainCircuitName, stateLogGlobal);
    await expectCircuitPass(newInputs, state);
    return true;
  });


  it('Force Withdraw', async function() {
    const txWithdrawTx = getEmptyTx();
    txWithdrawTx.reqType = TsTxType.FORCE_WITHDRAW;
    txWithdrawTx.tokenId = TsTokenId.ETH;
    txWithdrawTx.arg0 = acc2Id.toString();
    const txWithdrawtxs = [
      txWithdrawTx,
      getEmptyTx(),
      getEmptyTx(),
    ];
    const { newInputs, rawInputs, inputs } = await rollup.startRollup(async (rp) => {
      for(const tx of txWithdrawtxs) {
        txList.push(tx);
        await rp.doTransaction(tx);
      }
    });
    const state = exporter.exportInputs(`force-withdraw-acc1-usdt-${mainSuffix}`, rawInputs, newInputs, inputs, mainCircuitName, stateLogGlobal);

    await expectCircuitPass(newInputs, state);
    return true;
  });

  it('Withdraw Fee', async function() {
    const txWithdrawFeeTx = getEmptyTx();
    txWithdrawFeeTx.reqType = TsTxType.WITHDRAW_FEE;
    txWithdrawFeeTx.tokenId = TsTokenId.USDT;
    const txs = [
      txWithdrawFeeTx,
      getEmptyTx(),
      getEmptyTx(),
    ];
    const { newInputs, rawInputs, inputs } = await rollup.startRollup(async (rp) => {
      for(const tx of txs) {
        txList.push(tx);
        await rp.doTransaction(tx);
      }
    });
    const state = exporter.exportInputs(`withdraw-fee-usdt-${mainSuffix}`, rawInputs, newInputs, inputs, mainCircuitName, stateLogGlobal);

    await expectCircuitPass(newInputs, state);
    return true;
  });

  it('set admin tsAddr', async function() {
    const txSetAdmin = getEmptyTx();
    txSetAdmin.reqType = TsTxType.SET_ADMIN_TS_ADDR;
    txSetAdmin.arg6 = '993897585093631141645065567988378268956570510229';
    txSetAdmin.metadata = {
      tsPubKeyX: '696355168636201169322454157209388601041355126149512535191612868428544671623',
      tsPubKeyY: '11811869977715740222744805358647939726859874499539987888245732584909088137693',
    };
    const txs = [
      txSetAdmin,
      getEmptyTx(),
      getEmptyTx(),
    ];
    const { newInputs, rawInputs, inputs } = await rollup.startRollup(async (rp) => {
      for(const tx of txs) {
        txList.push(tx);
        await rp.doTransaction(tx);
      }
    });
    const state = exporter.exportInputs(`set-admin-tsaddr-${mainSuffix}`, rawInputs, newInputs, inputs, mainCircuitName, stateLogGlobal);

    await expectCircuitPass(newInputs, state);
    return true;
  });

  describe('Simulate one year later', function() {
    before(async function() {
      rollup.currentTime += 86400 * 365;
    });
    it('acc2 redeem tslUSDT', async function() {
      const acc2Account = rollup.getAccount(BigInt(acc2Id));
      if(!acc2Account) {
        throw new Error('acc2 not exist');
      }
      const currentNonce = acc2Account.nonce || 0n;
      const tslUSDTInfo = acc2Account.getTokenLeaf(TsTokenId.TslUSDT20231231);
      const reqs = new Array(1).fill(0).map((_, i) => acc2Signer.prepareTxRedeem({
        reqType: TsTxType.REDEEM,
        tokenId: TsTokenId.TslUSDT20231231,
        amount: tslUSDTInfo.leaf.amount.toString(),
        senderId: acc2Id.toString(),
        nonce: (currentNonce + BigInt(i)).toString(),
      }));
      const { newInputs, rawInputs, inputs } = await rollup.startRollup(async (rp) => {
        for(const req of reqs) {
          const txReq = convertRedeemReq2TxEntity(req, acc2Signer.tsPubKey);
          txList.push(txReq);
          await rp.doTransaction(txReq);
        }
      });
      const state = exporter.exportInputs(`redeem-acc2-tslusdt-${mainSuffix}`, rawInputs, newInputs, inputs, mainCircuitName, stateLogGlobal);
      await expectCircuitPass(newInputs, state);
    });
  });
  async function expectCircuitPass(newInputs: any, state: StateType, force = false) {
    if(isTestCircuitRun || force) {
      const witness = await mainCircuit.calculateWitness(newInputs);
      expect(witness[0]).to.equal(1n);
      const {commitment} = stateToCommitment(state);
      expect(BigInt(commitment)).to.equal(witness[1]);
    }
  }
});

function getTxInterest(apyRate: string | number) {
  const apy = Number(apyRate) + 1;
  return Math.floor(apy * Math.pow(10, 8)).toString();
}


function l1AmtToL2Amt(tokenId: TsTokenId, value: string) {
  const tokenDecimalInfo = Object.values(TS_BASE_TOKEN).find(t => t.tokenId.toString() === tokenId);
  const amount = BigNumber.from(value);
  const l2Amount = amount.div(BigNumber.from(10).pow(tokenDecimalInfo?.decimals || 8)).mul(TsDecimalScale);
  return l2Amount.toString();
}
