import { TsMerkleTree } from '../merkle-tree-dp';
import { TsBondLeafEncodeType, TsFeeLeafEncodeType, TsNullifierLeafEncodeType, TsRollupBaseType, TsRollupCircuitInputItemType, TsRollupCircuitInputType } from '../ts-types/ts-rollup-types';
import { TsRollupAccount } from './ts-rollup-account';
import { RESERVED_ACCOUNTS } from './ts-env';
import assert from 'assert';
import { getDefaultAccountLeafNode, getEmptyOrderLeaf, getEmptyTx, OrderLeafNode, TransactionInfo } from '../ts-types/mock-types';
import { NullifierTree } from './ts-nullifier';
import { CHUNK_BITS_SIZE, dpPoseidonHash, EddsaSigner, hexToBuffer, MAX_CHUNKS_PER_REQ, recursiveToString, TsAccountLeafEncodeType, tsHashFunc, TsOrderLeafEncodeType, TsSystemAccountAddress, TsTokenId, TsTokenLeafEncodeType, TsTxRequestDataType, TsTxType } from 'term-structure-sdk';
import { encodeTokenLeaf, toTreeLeaf, txsToRollupCircuitInput, encodeRChunkBuffer, bigint_to_chunk_array } from './ts-rollup-helper';
import { writeFileSync } from '../../test/helper/test-helper';
import { CircuitFeeTxPayload, FeeTree } from './ts-fee';
import { BondTree, CircuitBondTxPayload } from './ts-bond';

export type TsRollupConfigType = {
  order_tree_height: number,
  account_tree_height: number,
  token_tree_height: number,
  nullifier_tree_height: number,
  fee_tree_height: number,
  bond_tree_height: number,
  numOfChunks: number,
  numOfReqs: number,
}

interface CircuitAccountTxPayload {
  r_accountLeafId: Array<string | bigint>,
  r_oriAccountLeaf: Array<TsAccountLeafEncodeType>,
  r_newAccountLeaf: Array<TsAccountLeafEncodeType>,
  r_accountRootFlow: Array<Array<string | bigint>>,
  r_accountMkPrf: Array<string[]| (string | bigint)[]>,

  r_tokenLeafId: Array<string | bigint>,
  r_oriTokenLeaf: Array<TsTokenLeafEncodeType>,
  r_newTokenLeaf: Array<TsTokenLeafEncodeType>,
  r_tokenRootFlow: Array<Array<string | bigint>>,
  r_tokenMkPrf: Array<string[]| (string | bigint)[]>,
}
interface CircuitOrderTxPayload {
  r_orderLeafId: Array<string | bigint>,
  r_oriOrderLeaf: Array<TsOrderLeafEncodeType>,
  r_newOrderLeaf: Array<TsOrderLeafEncodeType>,
  r_orderRootFlow: Array<Array<string | bigint>>,
  r_orderMkPrf: Array<string[]| (string | bigint)[]>,
}

interface CircuitNullifierTxPayload {
  nullifierTreeId: string,
  nullifierElemId: string,
  r_nullifierLeafId: Array<string | bigint>,
  r_oriNullifierLeaf: Array<TsNullifierLeafEncodeType>,
  r_newNullifierLeaf: Array<TsNullifierLeafEncodeType>,
  r_nullifierRootFlow: Array<Array<string | bigint>>,
  r_nullifierMkPrf: Array<string[] | bigint[] | (string | bigint)[]>,
}

export enum RollupStatus {
  Unknown = 0,
  Idle,
  Running,
}

export enum RollupCircuitType {
  Unknown = 0,
  Register = 1,
  Transfer = 2,
}

export class RollupCore {
  mkFeeTree!: FeeTree;
  mkBondTree!: BondTree;

  prepareTxFeePayload(): CircuitFeeTxPayload {
    return {
      r_feeLeafId: [],
      r_oriFeeLeaf: [],
      r_newFeeLeaf: [],
      r_feeRootFlow: [],
      r_feeMkPrf: [],
    };
  }
  prepareTxBondPayload(): CircuitBondTxPayload {
    return {
      r_bondTokenLeafId: [],
      r_oriBondTokenLeaf: [],
      r_newBondTokenLeaf: [],
      r_bondTokenRootFlow: [],
      r_bondTokenMkPrf: [],
    };
  }
  // TODO: amt_size, l2_token_addr_size
  public config: TsRollupConfigType = {
    account_tree_height: 12,
    token_tree_height: 8,
    order_tree_height: 24,
    nullifier_tree_height: 8,
    fee_tree_height: 3,
    bond_tree_height: 3,
    numOfChunks: 3,
    numOfReqs: 31,
  };
  get txNormalPerBatch() {
    return this.config.numOfReqs;
  }
  public get stateRoot() {
    const accountTreeRoot = this.mkAccountTree.getRoot();
    const orderTreeRoot = this.mkOrderTree.getRoot();
    const bondTreeRoot = this.mkBondTree.getRoot();
    const feeTreeRoot = this.mkFeeTree.getRoot();

    const nullifierTreeRoot = dpPoseidonHash([
      this.nullifierTreeOne.getRoot(),
      this.currentEpochOne,
      this.nullifierTreeTwo.getRoot(),
      this.currentEpochTwo,
    ]);
    const oriTxNum = this.oriTxId;

    const oriTsRoot = '0x' + dpPoseidonHash([
      this.adminTsAddr,
      bondTreeRoot,
      feeTreeRoot,
      nullifierTreeRoot,
      BigInt(orderTreeRoot), oriTxNum
    ]).toString(16).padStart(64, '0');

    const oriStateRoot = '0x' + dpPoseidonHash([
      BigInt(oriTsRoot), BigInt(accountTreeRoot)
    ]).toString(16).padStart(64, '0');
    return oriStateRoot;
  }
  public rollupStatus: RollupStatus = RollupStatus.Idle;

  // TODO: account state in Storage
  public accountList: TsRollupAccount[] = [];
  public mkAccountTree!: TsMerkleTree;
  get currentAccountAddr() {
    return this.accountList.length;
  }

  // TODO: auction order in Storage
  // leafId = 0 always be empty
  private orderMap: {[k: number | string]: OrderLeafNode} = {};
  public mkOrderTree!: TsMerkleTree;

  // TODO: nullifier state in Storage
  public currentEpochOne = 1n;
  public currentEpochTwo = 2n;

  /** Block information */
  public blockNumber = 0n;
  public currentTime = Math.floor(Date.now() / 1000);
  public oriTxId = 0n;
  get latestTxId() {
    return this.oriTxId + BigInt(this.currentTxLogs.length);
  }
  currentTxLogs: any[] = [];
  private currentAccountRootFlow: bigint[] = [];
  private currentOrderRootFlow: bigint[] = [];
  private currentNullifierRootFlowOne: bigint[] = [];
  private currentNullifierRootFlowTwo: bigint[] = [];
  private currentEpochFlow: [bigint[],bigint[]] = [[],[]];
  private currentFeeRootFlow: bigint[] = [];
  private currentBondTokenRootFlow: bigint[] = [];
  private currentAdminTsAddrFlow: bigint[] = [];
  private adminTsAddr = 0n;
  private adminTsPubKey: [bigint, bigint] = [0n, 0n];
  /** Transaction Information */
  private txAccountPayload: CircuitAccountTxPayload = this.prepareTxAccountPayload();
  private txOrderPayload: CircuitOrderTxPayload = this.prepareTxOrderPayload();
  private txNullifierPayload: CircuitNullifierTxPayload = this.prepareTxNullifierPayload();
  private txBondPayload: CircuitBondTxPayload = this.prepareTxBondPayload();
  private txFeePayload: CircuitFeeTxPayload = this.prepareTxFeePayload();

  private blockLogs: Map<string, {
    logs: any[],
    accountRootFlow: bigint[]
    auctionOrderRootFlow: bigint[]
  }> = new Map();
  // TODO: add rollup circuit logs
  public get defaultTokenLeaf(): TsTokenLeafEncodeType {
    return [0n, 0n];
  }
  public defaultTokenTree!: TsMerkleTree;
  public defaultTokenRoot!: bigint;
  public defaultNullifierRoot!: bigint;
  public get defaultAccountLeafData(): [bigint, bigint, bigint] {
    return [0n, 0n, this.defaultTokenRoot];
  }
  public getDefaultOrder = getEmptyOrderLeaf;
  public defailtOrderLeafHash = getEmptyOrderLeaf().encodeLeafHash();

  public nullifierTreeOne!: NullifierTree;
  public nullifierTreeTwo!: NullifierTree;
  constructor(config: Partial<TsRollupConfigType>) {
    this.config = {...this.config, ...config};

    this.defaultTokenTree = new TsMerkleTree(
      [],
      this.config.token_tree_height,
      dpPoseidonHash(this.defaultTokenLeaf)
    );
    this.defaultTokenRoot = BigInt(this.defaultTokenTree.getRoot());
    this.initAccountTree();
    this.initOrderTree();
    this.initNullifierTree();

    this.mkFeeTree = new FeeTree(this.config.fee_tree_height);
    this.mkBondTree = new BondTree(this.config.bond_tree_height);
  }

  private initAccountTree() {
    this.mkAccountTree = new TsMerkleTree(
      this.accountList.map(a => toTreeLeaf(a.encodeAccountLeaf())),
      this.config.account_tree_height,
      dpPoseidonHash(this.defaultAccountLeafData)
    );

    /**
     * Initial system accounts
     * 0: L2BurnAccount
     * 1: L2MintAccount
     * 2: L2AuctionAccount
     * ~100: RESERVED_ACCOUNTS, reserve system accounts 
     */
    const systemAccountNum = Number(RESERVED_ACCOUNTS);
    for (let index = 0; index < systemAccountNum; index++) {
      // INFO: Default token Tree
      this.addAccount(index, new TsRollupAccount(
        {},
        this.config.token_tree_height,
        [0n, 0n],
      ));
    }

    // TODO: initial registered accounts from storage.
  }

  private initOrderTree() {
    this.orderMap[0] = this.getDefaultOrder();
    this.mkOrderTree = new TsMerkleTree(
      Object.entries(this.orderMap).sort((a, b) => Number(a[0]) - Number(b[0])).map((o) => o[1].encodeLeafHash()),
      this.config.order_tree_height,
      this.defailtOrderLeafHash
    );
  }

  private initNullifierTree() {
    this.nullifierTreeOne = new NullifierTree(
      this.config.nullifier_tree_height
    );
    this.nullifierTreeTwo = new NullifierTree(
      this.config.nullifier_tree_height,
    );
    this.defaultNullifierRoot = BigInt(this.nullifierTreeOne.getRoot());
  }

  /** Order */
  getOrderMap() {
    return this.orderMap;
  }

  getOrder(orderId: number): OrderLeafNode | undefined {
    return this.orderMap[orderId];
  }

  /** Account */
  getAccount(accAddr: bigint): TsRollupAccount | null {
    const acc = this.accountList[Number(accAddr)];

    if(!acc) {
      return null;
    }
    return acc;
  }

  getAccountProof(accAddr: bigint) {
    return this.mkAccountTree.getProof(accAddr);
  }

  addAccount(l2addr: number, account: TsRollupAccount): number {
    if(this.currentAccountAddr !== 0 && l2addr.toString() === TsSystemAccountAddress.BURN_ADDR) {
      // TODO: for empty main tx request
      return 0;
    }
    if(this.currentAccountAddr !== l2addr) {
      throw new Error(`addAccount: l2addr=${l2addr} not match l2 account counter (${this.currentAccountAddr})`);
    }
    this.accountList.push(account);
    account.setAccountAddress(BigInt(l2addr));

    this.mkAccountTree.updateLeafNode(
      BigInt(this.currentAccountAddr - 1),
      BigInt(toTreeLeaf(account.encodeAccountLeaf())),
    );
    return l2addr;
  }

  private updateAccountToken(accountId: bigint, tokenAddr: TsTokenId, tokenAmt: bigint, lockedAmt: bigint) {
    const acc = this.getAccount(accountId);
    if(!acc) {
      throw new Error(`updateAccountToken: account id=${accountId} not found`);
    }
    const newTokenRoot = acc.updateToken(tokenAddr, tokenAmt, lockedAmt);
    this.mkAccountTree.updateLeafNode(
      accountId,
      BigInt(toTreeLeaf(acc.encodeAccountLeaf())),
    );
    return {
      newTokenRoot,
    };
  }
  private updateAccountNonce(accountId: bigint, nonce: bigint) {
    const acc = this.getAccount(accountId);
    if(!acc) {
      throw new Error(`updateAccountNonce: account id=${accountId} not found`);
    }
    acc.updateNonce(nonce);
    this.mkAccountTree.updateLeafNode(
      accountId,
      BigInt(toTreeLeaf(acc.encodeAccountLeaf())),
    );
  }

  /** Rollup trace */
  private addFirstRootFlow() {
    if(this.currentAccountRootFlow.length !== 0
      || this.currentOrderRootFlow.length !== 0) {
      throw new Error('addFirstRootFlow must run on new block');
    }
    this.addAccountRootFlow();
    this.addOrderRootFlow();
    this.addNullifierRootFlow();
    this.addEpochFlow();
    this.addOthersRootFlow();
    this.addAdminTsAddrFlow();
  }

  private flushBlock(blocknumber: bigint) {
    if(this.blockLogs.has(blocknumber.toString())) {
      throw new Error(`Block ${blocknumber} already exist`);
    }
    const logs = {...this.currentTxLogs};
    const accountRootFlow = [...this.currentAccountRootFlow];
    const auctionOrderRootFlow = [...this.currentOrderRootFlow];
    this.currentTime = Math.floor(Date.now() / 1000);
    this.blockNumber = blocknumber;
    this.currentAccountRootFlow = [];
    this.currentOrderRootFlow = [];
    this.currentNullifierRootFlowOne = [];
    this.currentNullifierRootFlowTwo = [];
    this.currentEpochFlow = [[],[]];
    this.currentTxLogs = [];
    this.currentBondTokenRootFlow = [];
    this.currentFeeRootFlow = [];
    this.currentAdminTsAddrFlow = [];

    this.blockLogs.set(blocknumber.toString(), {
      logs,
      accountRootFlow,
      auctionOrderRootFlow,
    });
  }

  private flushTx() {
    this.txAccountPayload = this.prepareTxAccountPayload();
    this.txOrderPayload = this.prepareTxOrderPayload();
    this.txNullifierPayload = this.prepareTxNullifierPayload();
    this.txBondPayload = this.prepareTxBondPayload();
    this.txFeePayload = this.prepareTxFeePayload();
  }

  private addAccountRootFlow() {
    this.currentAccountRootFlow.push(BigInt(this.mkAccountTree.getRoot()));
  }

  private addOrderRootFlow() {
    this.currentOrderRootFlow.push(BigInt(this.mkOrderTree.getRoot()));
  }

  private addNullifierRootFlow() {
    this.currentNullifierRootFlowOne.push(BigInt(this.nullifierTreeOne.getRoot()));
    this.currentNullifierRootFlowTwo.push(BigInt(this.nullifierTreeTwo.getRoot()));
  }

  private addEpochFlow() {
    this.currentEpochFlow[0].push(this.currentEpochOne);
    this.currentEpochFlow[1].push(this.currentEpochTwo);
  }

  private addOthersRootFlow() {
    this.currentBondTokenRootFlow.push(BigInt(this.mkBondTree.getRoot()));
    this.currentFeeRootFlow.push(BigInt(this.mkFeeTree.getRoot()));
  }

  private addAdminTsAddrFlow() {
    this.currentAdminTsAddrFlow.push(BigInt(this.adminTsAddr));
  }

  private addTxLogs(detail: any) {
    this.currentTxLogs.push(detail);
  }
  private getNullifierTree(isOne = true) {
    return isOne ? this.nullifierTreeOne : this.nullifierTreeTwo;
  }

  /** Rollup Transaction */
  // TODO: refactor method to retrict RollupCircuitType
  async startRollup(callback: (that: RollupCore, blockNumber: bigint) => Promise<void>): Promise<{
    blockNumber: bigint,
    inputs?: TsRollupCircuitInputType,
    rawInputs: any,
    newInputs: any,
  }> {
    const perBatch = this.txNormalPerBatch;
    if(this.rollupStatus === RollupStatus.Running) {
      throw new Error('Rollup is running');
    }
    this.rollupStatus = RollupStatus.Running;

    const newBlockNumber = this.blockNumber + 1n;
    this.addFirstRootFlow();
    // TODO: rollback state if callback failed
    await callback(this, newBlockNumber);
    if(this.currentTxLogs.length < perBatch) {
      const emptyTxNum = perBatch - this.currentTxLogs.length;
      console.warn(`Rollup txNumbers=${this.currentTxLogs.length} not match txPerBatch=${perBatch}, emptyTxNum=${emptyTxNum}`);
      for(let i = 0; i < emptyTxNum; i++) {
        await this.doTransaction(getEmptyTx());
      }
    } else if(this.currentTxLogs.length > perBatch) {
      throw new Error(`Rollup txNumbers=${this.currentTxLogs.length} not match txPerBatch=${perBatch}`);
    }
    // const circuitInputs = exportTransferCircuitInput(this.currentTxLogs, this.txId, this.currentAccountRootFlow, this.currentAuctionOrderRootFlow);
    writeFileSync('./test.json', JSON.stringify(this.currentTxLogs, null, 2));



    const circuitInputs = txsToRollupCircuitInput(this.currentTxLogs) as any;

    const { result: preprocessedReq, raw: rawPreprocessedReq } = convertToPreProcessedReqType(this.currentTxLogs, this.currentTime);
    // TODO: type check

    circuitInputs['o_chunks'] = circuitInputs['o_chunks'].flat();
    const o_chunk_remains = this.config.numOfChunks - circuitInputs['o_chunks'].length;
    circuitInputs['isCriticalChunk'] = circuitInputs['isCriticalChunk'].flat();
    assert(circuitInputs['isCriticalChunk'].length === circuitInputs['o_chunks'].length, `isCriticalChunk=${circuitInputs['isCriticalChunk'].length} length not match o_chunks=${circuitInputs['o_chunks'].length} `);
    for (let index = 0; index < o_chunk_remains; index++) {
      circuitInputs['o_chunks'].push('0');
      circuitInputs['isCriticalChunk'].push('0');
    }
    assert(circuitInputs['o_chunks'].length === this.config.numOfChunks, `o_chunks=${circuitInputs['o_chunks'].length} length not match numOfChunks=${this.config.numOfChunks} `);
    assert(circuitInputs['isCriticalChunk'].length === this.config.numOfChunks, `isCriticalChunk=${circuitInputs['isCriticalChunk'].length} length not match numOfChunks=${this.config.numOfChunks} `);


    circuitInputs['oriTxNum'] = this.oriTxId.toString();
    circuitInputs['accountRootFlow'] = this.currentAccountRootFlow.map(x => recursiveToString(x));
    circuitInputs['orderRootFlow'] = this.currentOrderRootFlow.map(x => recursiveToString(x));
    circuitInputs['feeRootFlow'] = this.currentFeeRootFlow.map(x => recursiveToString(x));
    circuitInputs['bondTokenRootFlow'] = this.currentBondTokenRootFlow.map(x => recursiveToString(x));
    circuitInputs['adminTsAddrFlow'] = this.currentAdminTsAddrFlow.map(x => recursiveToString(x));
    circuitInputs['nullifierRootFlow'] = [
      this.currentNullifierRootFlowOne.map(x => recursiveToString(x)),
      this.currentNullifierRootFlowTwo.map(x => recursiveToString(x)),
    ];
    circuitInputs['epochFlow'] = [
      this.currentEpochFlow[0].map(x => recursiveToString(x)),
      this.currentEpochFlow[1].map(x => recursiveToString(x)),
    ];
    circuitInputs['currentTime'] = this.currentTime;

    const oriTxId = this.oriTxId;
    this.oriTxId = this.latestTxId;
    this.flushBlock(newBlockNumber);
    this.rollupStatus = RollupStatus.Idle;

    // REFACTOR:
    const { result: state, raw: rawState} = convertToCircuitStateType(circuitInputs, this.config.numOfReqs + 1, Number(oriTxId));
    return {
      blockNumber: newBlockNumber,
      inputs: circuitInputs,
      rawInputs: {
        currentTime: circuitInputs['currentTime'].toString(),
        state: rawState,
        preprocessedReq: rawPreprocessedReq,
        isCriticalChunk: circuitInputs['isCriticalChunk'],
        o_chunks: circuitInputs['o_chunks'],
      },
      newInputs: {
        currentTime: circuitInputs['currentTime'].toString(),
        state,
        preprocessedReq,
        isCriticalChunk: circuitInputs['isCriticalChunk'],
        o_chunks: circuitInputs['o_chunks'],
      },
    };
  }

  private prepareTxAccountPayload() {
    return {
      r_accountLeafId: [],
      r_oriAccountLeaf: [],
      r_newAccountLeaf: [],
      r_accountRootFlow: [],
      r_accountMkPrf: [],

      r_tokenLeafId: [],
      r_oriTokenLeaf: [],
      r_newTokenLeaf: [],
      r_tokenRootFlow: [],
      r_tokenMkPrf: [],
    } as CircuitAccountTxPayload;
  }

  private prepareTxOrderPayload() {
    return {
      r_orderLeafId: [],
      r_oriOrderLeaf: [],
      r_newOrderLeaf: [],
      r_orderRootFlow: [],
      r_orderMkPrf: [],
    } as CircuitOrderTxPayload;
  }

  private prepareTxNullifierPayload() {
    return {
      nullifierTreeId: '0',
      nullifierElemId: '0',
      r_nullifierLeafId: [],
      r_oriNullifierLeaf: [],
      r_newNullifierLeaf: [],
      r_nullifierRootFlow: [],
      r_nullifierMkPrf: [],
    } as CircuitNullifierTxPayload;
  }

  private nullifierBeforeUpdate(elemId: number, leafId: bigint) {
    const nullifier = this.getNullifierTree();
    this.txNullifierPayload.nullifierElemId = elemId.toString();
    this.txNullifierPayload.r_nullifierLeafId.push(leafId.toString());
    this.txNullifierPayload.r_oriNullifierLeaf.push(nullifier.getLeaf(leafId).encodeLeafMessage());
    this.txNullifierPayload.r_nullifierMkPrf.push(nullifier.getProof(leafId));
    this.txNullifierPayload.r_nullifierRootFlow.push([nullifier.getRoot()]);
  }
  private nullifierAfterUpdate(leafId: bigint) {
    const nullifier = this.getNullifierTree();
    this.txNullifierPayload.r_newNullifierLeaf.push(nullifier.getLeaf(leafId).encodeLeafMessage());

    const idx = this.txNullifierPayload.r_nullifierRootFlow.length - 1;
    if(this.txNullifierPayload.r_nullifierRootFlow[idx]?.length) {
      this.txNullifierPayload.r_nullifierRootFlow[idx].push(nullifier.getRoot());
    } else {
      throw new Error('nullifierAfterUpdate: r_nullifierRootFlow not found');
    }
  }

  private tokenBeforeUpdate(accountLeafId: bigint, tokenId: TsTokenId) {
    const account = this.getAccount(accountLeafId) || getDefaultAccountLeafNode(this.config.token_tree_height);
    const tokenInfo = account.getTokenLeaf(tokenId);

    this.txAccountPayload.r_tokenLeafId.push(tokenId);
    this.txAccountPayload.r_oriTokenLeaf.push(encodeTokenLeaf(tokenInfo.leaf));
    this.txAccountPayload.r_tokenMkPrf.push(account.tokenTree.getProof(tokenInfo.leafId));
    this.txAccountPayload.r_tokenRootFlow.push([account.getTokenRoot()]);
  }
  private tokenAfterUpdate(accountLeafId: bigint, tokenAddr: TsTokenId) {
    const account = this.getAccount(accountLeafId);
    if(!account) {
      throw new Error('accountAfterUpdate: account not found');
    }
    const tokenInfo = account.getTokenLeaf(tokenAddr);
    this.txAccountPayload.r_newTokenLeaf.push(encodeTokenLeaf(tokenInfo.leaf));

    const idx = this.txAccountPayload.r_tokenRootFlow.length - 1;
    if(this.txAccountPayload.r_tokenRootFlow[idx]?.length) {
      this.txAccountPayload.r_tokenRootFlow[idx].push(account.getTokenRoot());
    } else {
      throw new Error('tokenAfterUpdate: tokenRootFlow not found');
    }
  }
  private accountBeforeUpdate(accountLeafId: bigint) {
    const account = this.getAccount(accountLeafId) || getDefaultAccountLeafNode(this.config.token_tree_height);
    const accLeafData = account.encodeAccountLeaf();

    this.txAccountPayload.r_accountLeafId.push(accountLeafId);
    this.txAccountPayload.r_oriAccountLeaf.push(accLeafData);
    this.txAccountPayload.r_accountMkPrf.push(this.getAccountProof(accountLeafId));
    this.txAccountPayload.r_accountRootFlow.push([this.mkAccountTree.getRoot()]);

  }
  private accountAfterUpdate(accountLeafId: bigint) {
    const account = this.getAccount(accountLeafId);
    if(!account) {
      throw new Error('accountAfterUpdate: account not found');
    }
    this.txAccountPayload.r_newAccountLeaf.push(account.encodeAccountLeaf());

    const idx = this.txAccountPayload.r_accountRootFlow.length -1;
    if(this.txAccountPayload.r_accountRootFlow[idx]?.length) {
      this.txAccountPayload.r_accountRootFlow[idx].push(
        this.mkAccountTree.getRoot()
      );
    } else {
      throw new Error('accountAfterUpdate: accountRootFlow not found');
    }
  }

  private accountAndTokenBeforeUpdate(accountLeafId: bigint, tokenId: TsTokenId) {
    this.tokenBeforeUpdate(accountLeafId, tokenId);
    this.accountBeforeUpdate(accountLeafId);
  }

  private accountAndTokenAfterUpdate(accountLeafId: bigint, tokenId: TsTokenId) {
    this.tokenAfterUpdate(accountLeafId, tokenId);
    this.accountAfterUpdate(accountLeafId);
  }

  private orderBeforeUpdate(orderLeafId: bigint) {
    const order = this.getOrder(Number(orderLeafId)) || this.getDefaultOrder();
    this.txOrderPayload.r_orderLeafId.push(orderLeafId.toString());
    this.txNullifierPayload;
    this.txOrderPayload.r_oriOrderLeaf.push(order.encodeLeafMessage());
    this.txOrderPayload.r_orderMkPrf.push(this.mkOrderTree.getProof(orderLeafId));

    this.txOrderPayload.r_orderRootFlow.push(
      [BigInt(this.mkOrderTree.getRoot()).toString()]
    );
  }

  private orderAfterUpdate(orderLeafId: bigint) {
    const order = this.getOrder(Number(orderLeafId)) || this.getDefaultOrder();
    this.txOrderPayload.r_newOrderLeaf.push(order.encodeLeafMessage());

    const idx = this.txOrderPayload.r_orderRootFlow.length - 1;
    if(this.txOrderPayload.r_orderRootFlow[idx]?.length) {
      this.txOrderPayload.r_orderRootFlow[idx].push(
        BigInt(this.mkOrderTree.getRoot()).toString()
      );
    } else {
      throw new Error('orderAfterUpdate: orderRootFlow not found');
    }
  }

  private bondBeforeUpdate(bondLeafId: bigint) {
    const bond = this.mkBondTree.getLeaf(bondLeafId);
    this.txBondPayload.r_bondTokenLeafId.push(bondLeafId.toString());
    this.txNullifierPayload;
    this.txBondPayload.r_oriBondTokenLeaf.push(bond.encodeLeafMessage());
    this.txBondPayload.r_bondTokenMkPrf.push(this.mkBondTree.getProof(bondLeafId));

    this.txBondPayload.r_bondTokenRootFlow.push(
      [BigInt(this.mkBondTree.getRoot()).toString()]
    );
  }

  private bondAfterUpdate(bondLeafId: bigint) {
    const bond = this.mkBondTree.getLeaf(bondLeafId);
    this.txBondPayload.r_newBondTokenLeaf.push(bond.encodeLeafMessage());

    const idx = this.txBondPayload.r_bondTokenRootFlow.length - 1;
    if(this.txBondPayload.r_bondTokenRootFlow[idx]?.length) {
      this.txBondPayload.r_bondTokenRootFlow[idx].push(
        BigInt(this.mkBondTree.getRoot()).toString()
      );
    } else {
      throw new Error('bondAfterUpdate: bondRootFlow not found');
    }
  }

  private feeBeforeUpdate(feeLeafId: bigint) {
    const fee = this.mkFeeTree.getLeaf(feeLeafId);
    this.txFeePayload.r_feeLeafId.push(feeLeafId.toString());
    this.txFeePayload.r_oriFeeLeaf.push(fee.encodeLeafMessage());
    this.txFeePayload.r_feeMkPrf.push(this.mkFeeTree.getProof(feeLeafId));

    this.txFeePayload.r_feeRootFlow.push(
      [BigInt(this.mkFeeTree.getRoot()).toString()]
    );
  }

  private feeAfterUpdate(feeLeafId: bigint) {
    const fee = this.mkFeeTree.getLeaf(feeLeafId);
    this.txFeePayload.r_newFeeLeaf.push(fee.encodeLeafMessage());

    const idx = this.txFeePayload.r_feeRootFlow.length - 1;
    if(this.txFeePayload.r_feeRootFlow[idx]?.length) {
      this.txFeePayload.r_feeRootFlow[idx].push(
        BigInt(this.mkFeeTree.getRoot()).toString()
      );
    } else {
      throw new Error('feeAfterUpdate: feeRootFlow not found');
    }
  }

  private addAuctionOrder(order: OrderLeafNode) {
    order.setOrderLeafId(BigInt(order.leafId));
    this.orderMap[order.leafId] = order;
    this.mkOrderTree.updateLeafNode(BigInt(order.leafId), BigInt(order.encodeLeafHash()));
  }

  private removeOrder(leafId: number) {
    const order = this.getOrder(leafId);
    if(!order) {
      throw new Error('removeObsOrder: order not found');
    }
    this.orderMap[leafId] = this.getDefaultOrder();
    this.mkOrderTree.updateLeafNode(BigInt(leafId), BigInt(this.orderMap[leafId].encodeLeafHash()));
  }
  private updateOrder(order: OrderLeafNode) {
    assert(BigInt(order.leafId) > 0n, 'updateObsOrder: orderLeafId should be exist');
    this.orderMap[order.leafId] = order;
    this.mkOrderTree.updateLeafNode(BigInt(order.leafId), BigInt(order.encodeLeafHash()));
  }

  private getTxChunks(txEntity: TransactionInfo, metadata?: {
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
    const { r_chunks, o_chunks, isCritical } = encodeRChunkBuffer(txEntity, metadata);

    // TODO multiple txs need handle o_chunks in end of block;
    const r_chunks_bigint = bigint_to_chunk_array(BigInt('0x' + r_chunks.toString('hex')), BigInt(CHUNK_BITS_SIZE));
    const o_chunks_bigint = bigint_to_chunk_array(BigInt('0x' + o_chunks.toString('hex')), BigInt(CHUNK_BITS_SIZE));
    const isCriticalChunk = o_chunks_bigint.map(_ => '0');
    if (isCritical) {
      isCriticalChunk[0] = '1';
    }

    return { r_chunks_bigint, o_chunks_bigint, isCriticalChunk };
  }

  async doTransaction(req: TransactionInfo): Promise<TsRollupBaseType> {
    if(![
      TsTxType.AUCTION_BORROW,
      TsTxType.AUCTION_LEND,
      TsTxType.SECOND_LIMIT_ORDER,
      TsTxType.SECOND_MARKET_ORDER,
    ].includes(req.reqType)) {
      this.nullifierBeforeUpdate(0, 0n,);
      this.nullifierAfterUpdate(0n);
    }
    try {
      let inputs: TsRollupBaseType;
      switch (req.reqType) {
        case TsTxType.REGISTER:
          this.feeBeforeUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          this.feeAfterUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          inputs = await this.doRegister(req);
          break;
        case TsTxType.DEPOSIT:
          this.feeBeforeUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          this.feeAfterUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          inputs = await this.doDeposit(req);
          break;
        case TsTxType.TRANSFER:
          this.feeBeforeUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          this.feeAfterUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          inputs = await this.doTransfer(req);
          break;
        case TsTxType.FORCE_WITHDRAW:
          this.feeBeforeUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          this.feeAfterUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          inputs = await this.doForceWithdraw(req);
          break;
        case TsTxType.WITHDRAW:
          this.feeBeforeUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          this.feeAfterUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          inputs = await this.doWithdraw(req);
          break;
        case TsTxType.AUCTION_LEND:
        case TsTxType.AUCTION_BORROW:
          this.feeBeforeUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          this.feeAfterUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          inputs = await this.doAuctionOrder(req);
          break;
        case TsTxType.AUCTION_START:
          this.feeBeforeUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          this.feeAfterUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          inputs = await this.doAuctionStart(req);
          break;
        case TsTxType.AUCTION_MATCH:
          inputs = await this.DoReqAuctionExchange(req);
          break;
        case TsTxType.AUCTION_END:
          inputs = await this.doAuctionEnd(req);
          break;
        case TsTxType.SECOND_MARKET_ORDER:
          this.feeBeforeUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          this.feeAfterUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          inputs = await this.doSecondMarketOrder(req);
          break;
        case TsTxType.SECOND_LIMIT_ORDER:
          this.feeBeforeUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          this.feeAfterUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          inputs = await this.doSecondOrder(req);
          break;
        case TsTxType.SECOND_LIMIT_START:
          this.feeBeforeUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          this.feeAfterUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          inputs = await this.doSecondLimitStart(req);
          break;
        case TsTxType.SECOND_MARKET_EXCHANGE:
        case TsTxType.SECOND_LIMIT_EXCHANGE:
          inputs = await this.doSecondLimitExchange(req);
          break;
        case TsTxType.SECOND_MARKET_END:
        case TsTxType.SECOND_LIMIT_END:
          inputs = await this.doSecondLimitEnd(req);
          break;
        case TsTxType.CANCEL_ORDER:
          this.feeBeforeUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          this.feeAfterUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          inputs = await this.doCancelOrder(req);
          break;
        case TsTxType.INCREASE_EPOCH:
          this.feeBeforeUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          this.feeAfterUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          inputs = await this.doIncreaseEpoch(req);
          break;
        case TsTxType.CREATE_BOND_TOKEN:
          this.feeBeforeUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          this.feeAfterUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          inputs = await this.doCreateBondToken(req);
          break;
        case TsTxType.WITHDRAW_FEE:
          inputs = await this.doWithdrawFee(req);
          break;
        case TsTxType.SET_ADMIN_TS_ADDR:
          this.feeBeforeUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          this.feeAfterUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          inputs = await this.doSetAdminTsAddr(req);
          break;
        case TsTxType.REDEEM:
          this.feeBeforeUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          this.feeAfterUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          inputs = await this.doRedeem(req);
          break;
        case TsTxType.NOOP:
          this.feeBeforeUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          this.feeAfterUpdate(BigInt(req.metadata?.feeTokenId || '0'));
          inputs = await this.doNoop();
          break;
        default:
          throw new Error(`Unknown request type reqType=${req.reqType}`);
          break;
      }

      if(this.adminTsAddr !== 0n && isAdminTxType(req.reqType)) {
        const adminSinger = new EddsaSigner(hexToBuffer('0x0cef2e17df41494b8d56b57d4b3908833560e584329c5a0f223ffb36cee07f38'));
        const signature = adminSinger.signPoseidon(dpPoseidonHash(inputs.reqData));
        inputs.sigR = [
          EddsaSigner.toObject(signature.R8[0]),
          EddsaSigner.toObject(signature.R8[1]),
        ];
        inputs.sigS = signature.S;
        inputs.tsPubKey = this.adminTsPubKey;
      }

      if(![TsTxType.CREATE_BOND_TOKEN, TsTxType.REDEEM].includes(req.reqType)) {
        this.bondBeforeUpdate(BigInt(req.metadata?.bondTokenId || '0'));
        this.bondAfterUpdate(BigInt(req.metadata?.bondTokenId || '0'));
      }
      this.addOthersRootFlow();
      this.addAccountRootFlow();
      this.addOrderRootFlow();
      this.addNullifierRootFlow();
      this.addAdminTsAddrFlow();
      this.addEpochFlow();
      Object.assign(inputs, this.txAccountPayload);
      Object.assign(inputs, this.txOrderPayload);
      Object.assign(inputs, this.txNullifierPayload);
      Object.assign(inputs, this.txBondPayload);
      Object.assign(inputs, this.txFeePayload);
      this.flushTx();
      return inputs;

    } catch (error) {
      console.error('doTransaction error', error);
      throw error;
    }
  }

  doAuctionOrder(req: TransactionInfo) {
    assert(req.reqType === TsTxType.AUCTION_LEND || req.reqType === TsTxType.AUCTION_BORROW, 'doAuctionOrder: reqType should be AUCTION_LEND or AUCTION_BORROW');
    const isLender = req.reqType === TsTxType.AUCTION_LEND;
    const reqData = req.encodeMessage();
    const accountId = BigInt(req.accountId);
    const tokenId = req.tokenAddr  as TsTokenId;
    const from = this.getAccount(accountId);
    assert(from, `doAuctionOrder: account not found L2Addr=${from}`);
    const lendingAmt = BigInt(req.amount);
    const days = (BigInt(req.arg1) - BigInt(this.currentTime))/ 86400n;
    const feeAmtForLender = calcAuctionCalcLendFee(BigInt(req.fee0), lendingAmt, days);
    const lockAmt = lendingAmt + (isLender ? feeAmtForLender : 0n);
    this.accountAndTokenBeforeUpdate(accountId, tokenId);
    this.updateAccountToken(accountId, tokenId, -lockAmt, lockAmt);
    this.accountAndTokenAfterUpdate(accountId, tokenId);

    this.accountAndTokenBeforeUpdate(accountId, tokenId);
    this.accountAndTokenAfterUpdate(accountId, tokenId);

    assert(req.metadata?.orderId, 'doAuctionOrder: orderId is not set');
    const orderLeafId = BigInt(req.metadata?.orderId);
    this.orderBeforeUpdate(orderLeafId);
    const order = getEmptyOrderLeaf();
    order.copyFromTx(orderLeafId.toString(), req);
    order.setTxId(this.latestTxId.toString());
    order.lockAmt = lockAmt.toString();



    const {
      elemId,
      leafId,
      insert: insertNullifier,
    } = this.getNullifierTree().prepareInsertNullifer(order.encodeNullifierHash());
    this.nullifierBeforeUpdate(elemId, leafId);
    insertNullifier();
    this.addAuctionOrder(order);

    this.nullifierAfterUpdate(leafId);
    this.orderAfterUpdate(orderLeafId);

    const borrowingAmt = req.reqType === TsTxType.AUCTION_BORROW
      ? BigInt(req.arg5)
      : BigInt(0);
    const { r_chunks_bigint, o_chunks_bigint, isCriticalChunk } = this.getTxChunks(req, {
      borrowingAmt,
      matchedTime: BigInt(req.metadata?.matchedTime || this.currentTime),
    });

    const tx =  {
      reqData,
      tsPubKey: from.tsPubKey,
      sigR: req.eddsaSig.R8,
      sigS: req.eddsaSig.S,
      r_chunks: r_chunks_bigint,
      o_chunks: o_chunks_bigint,
      isCriticalChunk,
    };
    this.addTxLogs(tx);
    return tx as TsRollupBaseType;
  }

  doSecondMarketOrder(req: TransactionInfo) {
    const reqData = req.encodeMessage();
    const accountId = BigInt(req.accountId);
    const tokenId = req.tokenAddr  as TsTokenId;
    const from = this.getAccount(accountId);
    assert(from, `doSecondOrder: account not found L2Addr=${from}`);
    const isSell = req.arg8 === '1';
    const MQ = isSell ? BigInt(req.amount) : BigInt(req.arg5);
    const BQ = isSell ? BigInt(req.arg5) : BigInt(req.amount);
    const maturityTime = BigInt(req.metadata?.maturityTime || '0');
    const days = (maturityTime - BigInt(req.arg2)) / 86400n;
    const fee0 = BigInt(req.fee0 || '0');
    const fee1 = BigInt(req.fee1 || '0');
    const maxFeeRate = fee0 > fee1 ? fee0 : fee1;
    const lockedAmt = BigInt(req.metadata?.lockedAmt || '0');
    this.accountAndTokenBeforeUpdate(accountId, tokenId);
    this.accountAndTokenAfterUpdate(accountId, tokenId);

    this.accountAndTokenBeforeUpdate(accountId, tokenId);
    this.accountAndTokenAfterUpdate(accountId, tokenId);

    assert(req.metadata?.orderId, 'doAuctionOrder: orderId is not set');
    const orderLeafId = BigInt(req.metadata?.orderId);
    this.orderBeforeUpdate(orderLeafId);
    const order = getEmptyOrderLeaf();
    order.copyFromTx(orderLeafId.toString(), req);
    order.setTxId(this.latestTxId.toString());
    order.lockAmt = lockedAmt.toString();
    const {
      elemId,
      leafId,
      insert: insertNullifier,
    } = this.getNullifierTree().prepareInsertNullifer(order.encodeNullifierHash());
    this.nullifierBeforeUpdate(elemId, leafId);
    insertNullifier();

    this.nullifierAfterUpdate(leafId);
    this.orderAfterUpdate(orderLeafId);
    this.currentHoldTakerOrder = order;

    const { r_chunks_bigint, o_chunks_bigint, isCriticalChunk } = this.getTxChunks(req, {
      matchedTime: BigInt(req.metadata?.matchedTime || this.currentTime),
    });

    const tx =  {
      reqData,
      tsPubKey: from.tsPubKey,
      sigR: req.eddsaSig.R8,
      sigS: req.eddsaSig.S,
      r_chunks: r_chunks_bigint,
      o_chunks: o_chunks_bigint,
      isCriticalChunk,
    };
    this.addTxLogs(tx);
    return tx as TsRollupBaseType;
  }

  doSecondOrder(req: TransactionInfo) {
    const reqData = req.encodeMessage();
    const accountId = BigInt(req.accountId);
    const tokenId = req.tokenAddr  as TsTokenId;
    const from = this.getAccount(accountId);
    assert(from, `doSecondOrder: account not found L2Addr=${from}`);
    const isSell = req.arg8 === '1';
    const MQ = isSell ? BigInt(req.amount) : BigInt(req.arg5);
    const BQ = isSell ? BigInt(req.arg5) : BigInt(req.amount);
    const maturityTime = BigInt(req.metadata?.maturityTime || '0');
    const days = (maturityTime - BigInt(req.arg2)) / 86400n;
    const fee0 = BigInt(req.fee0 || '0');
    const fee1 = BigInt(req.fee1 || '0');
    const maxFeeRate = fee0 > fee1 ? fee0 : fee1;
    const lockedAmt = BigInt(req.metadata?.lockedAmt || '0');
    // const actualLockAmt = calcSecondaryLockedAmt(   //days to calc fee is from current
    //   req.reqType === TsTxType.SECOND_LIMIT_ORDER,
    //   isSell,
    //   MQ, BQ, days, maxFeeRate,
    // );
    // console.log({
    //   lockedAmt,
    //   actualLockAmt
    // });
    // assert(lockedAmt === actualLockAmt, 'doSecondOrder: lockedAmt is not correct'); 

    this.accountAndTokenBeforeUpdate(accountId, tokenId);
    this.updateAccountToken(accountId, tokenId, -BigInt(lockedAmt), BigInt(lockedAmt));
    this.accountAndTokenAfterUpdate(accountId, tokenId);

    this.accountAndTokenBeforeUpdate(accountId, tokenId);
    this.accountAndTokenAfterUpdate(accountId, tokenId);

    assert(req.metadata?.orderId, 'doAuctionOrder: orderId is not set');
    const orderLeafId = BigInt(req.metadata?.orderId);
    this.orderBeforeUpdate(orderLeafId);
    const order = getEmptyOrderLeaf();
    order.copyFromTx(orderLeafId.toString(), req);
    order.setTxId(this.latestTxId.toString());
    order.lockAmt = lockedAmt.toString();
    const {
      elemId,
      leafId,
      insert: insertNullifier,
    } = this.getNullifierTree().prepareInsertNullifer(order.encodeNullifierHash());
    this.nullifierBeforeUpdate(elemId, leafId);
    insertNullifier();
    this.addAuctionOrder(order);

    this.nullifierAfterUpdate(leafId);
    this.orderAfterUpdate(orderLeafId);

    if(req.reqType === TsTxType.SECOND_MARKET_ORDER) {
      this.currentHoldTakerOrder = order;
    }

    const { r_chunks_bigint, o_chunks_bigint, isCriticalChunk } = this.getTxChunks(req, {
      matchedTime: BigInt(req.metadata?.matchedTime || this.currentTime),
    });

    const tx =  {
      reqData,
      tsPubKey: from.tsPubKey,
      sigR: req.eddsaSig.R8,
      sigS: req.eddsaSig.S,
      r_chunks: r_chunks_bigint,
      o_chunks: o_chunks_bigint,
      isCriticalChunk,
    };
    this.addTxLogs(tx);
    return tx as TsRollupBaseType;
  }
  private currentHoldTakerOrder: OrderLeafNode | null = null;
  doSecondLimitStart(req: TransactionInfo) {
    const reqData = req.encodeMessage();
    const orderLeafId = Number(req.metadata?.orderId);
    const order = this.getOrder(orderLeafId);
    if(!order) {
      throw new Error(`doSecondLimitStart: order not found orderLeafId=${orderLeafId}`);
    }
    if(order.reqType === '0') {
      throw new Error('doSecondLimitStart: order not found (order.reqType=0)');
    }
    this.currentHoldTakerOrder = order;
    const from = this.getAccount(BigInt(order.accountId));
    if(!from) {
      throw new Error(`account not found L2Addr=${from}`);
    }
    const sellTokenId = order.tokenId.toString() as TsTokenId;

    this.accountAndTokenBeforeUpdate(from.L2Address, sellTokenId);
    this.accountAndTokenAfterUpdate(from.L2Address, sellTokenId);
    this.accountAndTokenBeforeUpdate(from.L2Address, sellTokenId);
    this.accountAndTokenAfterUpdate(from.L2Address, sellTokenId);

    this.orderBeforeUpdate(BigInt(orderLeafId));
    this.removeOrder(orderLeafId);
    this.orderAfterUpdate(BigInt(orderLeafId));

    const txId = this.latestTxId;
    const { r_chunks_bigint, o_chunks_bigint, isCriticalChunk } = this.getTxChunks(req, {
      txOffset: txId - BigInt(order.orderTxId),
      makerBuyAmt: 0n,
      matchedTime: BigInt(req.metadata?.matchedTime || this.currentTime),
    });

    const tx =  {
      reqData,
      tsPubKey: from.tsPubKey, // Deposit tx not need signature
      sigR: ['0', '0'],
      sigS: '0',

      r_chunks: r_chunks_bigint,
      o_chunks: o_chunks_bigint,
      isCriticalChunk,
    };

    this.addTxLogs(tx);
    return tx as TsRollupBaseType;

  }
  doSecondLimitExchange(req: TransactionInfo) {
    const reqData = req.encodeMessage();
    const orderLeafId = Number(req.metadata?.orderId);
    const makerOrder = this.getOrder(orderLeafId);
    if(!makerOrder) {
      throw new Error(`doSecondLimitExchange: order not found orderLeafId=${orderLeafId}`);
    }
    if(makerOrder.reqType === '0') {
      throw new Error(`doSecondLimitExchange: order not found orderLeafId=${orderLeafId} (order.reqType=0)`);
    }
    const makerAcc = this.getAccount(BigInt(makerOrder.accountId));
    if(!makerAcc) {
      throw new Error(`account not found L2Addr=${makerOrder.accountId}`);
    }
    const sellTokenId = makerOrder.tokenId.toString() as TsTokenId;
    const buyTokenId = makerOrder.arg4.toString() as TsTokenId;

    const isSell = makerOrder.arg8 === '1';
    const mainTokenId = isSell ? sellTokenId : buyTokenId;
    const baseTokenId = isSell ? buyTokenId : sellTokenId;

    const actualFeeTokenId = BigInt(baseTokenId);
    const feeTokenId = BigInt(req.metadata?.feeTokenId || '0');
    const feeAmt = BigInt(req.metadata?.feeAmt || '0');
    assert(feeTokenId === actualFeeTokenId, `feeTokenId=${feeTokenId} not match actualFeeTokenId=${actualFeeTokenId}`);

    const feeForSeller = isSell ? feeAmt : 0n;
    const feeForBuyer = isSell ? 0n : feeAmt;

    const matchedSellAmt = BigInt(req.metadata?.matchedSellAmt || '0');
    const matchedBuyAmt = BigInt(req.metadata?.matchedBuyAmt || '0');
    const acc1Amt = isSell ? matchedSellAmt : matchedBuyAmt;
    const acc2Amt = isSell ? matchedBuyAmt : matchedSellAmt;
    const days = (BigInt(makerOrder.arg1) - BigInt(this.currentTime)) / 86400n;
    const actualFeeAmt = calcSecondaryFee(BigInt(makerOrder.fee1), isSell ?  matchedSellAmt : matchedBuyAmt, days);
    assert(feeAmt === actualFeeAmt, `feeAmt=${feeAmt} not match actualFeeAmt=${actualFeeAmt}`);

    const diffLockAmt = - acc1Amt - feeForBuyer;
    const oriLockedAmt = BigInt(makerOrder.lockAmt);
    const newLockedAmt = oriLockedAmt + diffLockAmt;

    this.orderBeforeUpdate(BigInt(orderLeafId));
    // TODO: different days matched
    makerOrder.acc1 = (BigInt(makerOrder.acc1) + acc1Amt).toString();
    makerOrder.acc2 = (BigInt(makerOrder.acc2) + acc2Amt).toString();
    makerOrder.lockAmt = newLockedAmt.toString();
    const isAllSellAmtMatched = req.metadata?.orderStatus === '2';
    if(isAllSellAmtMatched) {
      this.removeOrder(orderLeafId);
    } else {
      this.updateOrder(makerOrder);
    }
    this.orderAfterUpdate(BigInt(orderLeafId));

    this.accountBeforeUpdate(makerAcc.L2Address);
    this.tokenBeforeUpdate(makerAcc.L2Address, buyTokenId);
    this.updateAccountToken(
      makerAcc.L2Address,
      buyTokenId,
      matchedBuyAmt - feeForSeller,
      0n);
    this.tokenAfterUpdate(makerAcc.L2Address, buyTokenId);

    this.tokenBeforeUpdate(makerAcc.L2Address, sellTokenId);
    this.updateAccountToken(
      makerAcc.L2Address,
      sellTokenId,
      isAllSellAmtMatched ? newLockedAmt : 0n,
      isAllSellAmtMatched ? -oriLockedAmt : diffLockAmt,
    );
    this.tokenAfterUpdate(makerAcc.L2Address, sellTokenId);
    this.accountAfterUpdate(makerAcc.L2Address);
    this.accountBeforeUpdate(makerAcc.L2Address);
    this.accountAfterUpdate(makerAcc.L2Address);

    this.feeBeforeUpdate(feeTokenId);
    const feeLeaf = this.mkFeeTree.getLeaf(feeTokenId);
    feeLeaf.amount = (BigInt(feeLeaf.amount) + feeAmt).toString();
    this.mkFeeTree.updateLeaf(feeLeaf);
    this.feeAfterUpdate(feeTokenId);

    const txId = this.latestTxId;
    const buyAmt = BigInt(makerOrder.arg5);
    const { r_chunks_bigint, o_chunks_bigint, isCriticalChunk } = this.getTxChunks(req, {
      txOffset: txId - BigInt(makerOrder.orderTxId),
      makerBuyAmt: buyAmt,
      matchedTime: BigInt(req.metadata?.matchedTime || this.currentTime),
    });

    const tx =  {
      reqData,
      tsPubKey: makerAcc.tsPubKey, // Deposit tx not need signature
      sigR: ['0', '0'],
      sigS: '0',
      r_chunks: r_chunks_bigint,
      o_chunks: o_chunks_bigint,
      isCriticalChunk,
    };

    this.addTxLogs(tx);
    return tx as TsRollupBaseType;

  }
  doSecondLimitEnd(req: TransactionInfo) {
    assert(!!this.currentHoldTakerOrder, 'doSecondLimitEnd: currentHoldTakerOrder is null');
    const reqData = req.encodeMessage();
    const orderLeafId = Number(req.metadata?.orderId);
    assert(orderLeafId === Number(this.currentHoldTakerOrder.leafId), 'doSecondLimitEnd: orderLeafId not match');
    const takerOrder = this.currentHoldTakerOrder;
    if(!takerOrder) {
      throw new Error(`doSecondLimitEnd: order not found orderLeafId=${orderLeafId}`);
    }
    if(takerOrder.reqType === '0') {
      throw new Error(`doSecondLimitEnd: order not found orderLeafId=${orderLeafId} (order.reqType=0)`);
    }
    const takerAcc = this.getAccount(BigInt(takerOrder.accountId));
    if(!takerAcc) {
      throw new Error(`account not found L2Addr=${takerOrder.accountId}`);
    }
    const sellTokenId = takerOrder.tokenId.toString() as TsTokenId;
    const buyTokenId = takerOrder.arg4.toString() as TsTokenId;

    const isAllSellAmtMatched = req.metadata?.orderStatus === '2';
    const matchedSellAmt = BigInt(req.metadata?.matchedSellAmt || '0');
    const matchedBuyAmt = BigInt(req.metadata?.matchedBuyAmt || '0');

    const feeTokenId = BigInt(req.metadata?.feeTokenId || '0');
    const feeAmt = BigInt(req.metadata?.feeAmt || '0');
    const isSell = takerOrder.arg8 === '1';
    const actualFeeTokenId = BigInt(isSell ? buyTokenId : sellTokenId);
    assert(feeTokenId === actualFeeTokenId, `feeTokenId=${feeTokenId} not match actualFeeTokenId=${actualFeeTokenId}`);
    const feeForBuyAmt = isSell ? feeAmt : 0n;
    const feeForSellAmt = isSell ? 0n : feeAmt;
    const diffLockAmt = -matchedSellAmt - feeForSellAmt;
    const newLockedAmt = BigInt(takerOrder.lockAmt) + diffLockAmt;

    console.log({
      matchedSellAmt,
      matchedBuyAmt,
      feeAmt,
      feeForBuyAmt,
      feeForSellAmt,
      diffLockAmt,
      newLockedAmt,
    });

    const matchedMQ = isSell ? matchedSellAmt : matchedBuyAmt;
    const days = (BigInt(takerOrder.arg1) - BigInt(this.currentTime)) / BigInt(86400);
    const actualFeeAmt = calcSecondaryFee(BigInt(takerOrder.fee0), matchedMQ, days);
    assert(feeAmt === actualFeeAmt, `feeAmt=${feeAmt} not match actualFeeAmt=${actualFeeAmt}`);

    this.orderBeforeUpdate(BigInt(orderLeafId));
    takerOrder.acc1 = (BigInt(takerOrder.acc1) + matchedSellAmt).toString();
    takerOrder.acc2 = (BigInt(takerOrder.acc2) + matchedBuyAmt).toString();
    takerOrder.lockAmt = newLockedAmt.toString();
    if(req.reqType === TsTxType.SECOND_LIMIT_ORDER) {
      if(isAllSellAmtMatched) {
        this.removeOrder(orderLeafId);
      } else {
        this.updateOrder(takerOrder);
      }
    }
    this.orderAfterUpdate(BigInt(orderLeafId));

    this.accountBeforeUpdate(takerAcc.L2Address);

    this.tokenBeforeUpdate(takerAcc.L2Address, buyTokenId);
    this.updateAccountToken(takerAcc.L2Address, buyTokenId, matchedBuyAmt - feeForBuyAmt, 0n);
    this.tokenAfterUpdate(takerAcc.L2Address, buyTokenId);

    this.tokenBeforeUpdate(takerAcc.L2Address, sellTokenId);
    this.updateAccountToken(
      takerAcc.L2Address,
      sellTokenId,
      isAllSellAmtMatched ? newLockedAmt : 0n,
      isAllSellAmtMatched ? diffLockAmt - newLockedAmt : diffLockAmt,
    );
    this.tokenAfterUpdate(takerAcc.L2Address, sellTokenId);

    this.accountAfterUpdate(takerAcc.L2Address);

    this.accountBeforeUpdate(takerAcc.L2Address);
    this.accountAfterUpdate(takerAcc.L2Address);

    this.feeBeforeUpdate(feeTokenId);
    const feeLeaf = this.mkFeeTree.getLeaf(feeTokenId);
    feeLeaf.amount = (BigInt(feeLeaf.amount) + feeAmt).toString();
    this.mkFeeTree.updateLeaf(feeLeaf);
    this.feeAfterUpdate(feeTokenId);

    const txId = this.latestTxId;
    const { r_chunks_bigint, o_chunks_bigint, isCriticalChunk } = this.getTxChunks(req, {
      txOffset: txId - BigInt(takerOrder.orderTxId),
      makerBuyAmt: 0n,
      matchedTime: BigInt(req.metadata?.matchedTime || this.currentTime),
    });

    this.currentHoldTakerOrder = null;
    const tx =  {
      reqData,
      tsPubKey: takerAcc.tsPubKey, // Deposit tx not need signature
      sigR: ['0', '0'],
      sigS: '0',

      r_chunks: r_chunks_bigint,
      o_chunks: o_chunks_bigint,
      isCriticalChunk,
    };

    this.addTxLogs(tx);
    return tx as TsRollupBaseType;

  }


  private currentHoldAuctionOrder: OrderLeafNode | null = null;
  private matchedLendInterest = 0n;
  async doAuctionStart(req: TransactionInfo): Promise<TsRollupBaseType> {
    this.matchedLendInterest = 0n;
    const reqData = req.encodeMessage();
    const orderLeafId = Number(req.metadata?.orderId);
    const borrowOrder = this.getOrder(orderLeafId);
    assert(borrowOrder, `doAuctionStart: order not found orderLeafId=${orderLeafId}`);
    assert(borrowOrder.reqType === TsTxType.AUCTION_BORROW, `doAuctionStart: reqType not match order.reqType=(${borrowOrder.reqType})`);
    const accountId = BigInt(borrowOrder.accountId);
    assert(accountId !== 0n, `doAuctionStart: order not found orderLeafId=${orderLeafId} (order.accountId=0)`);
    const from = this.getAccount(accountId);
    if(!from) {
      throw new Error(`account not found L2Addr=${from}`);
    }
    const sellTokenId = borrowOrder.tokenId.toString() as TsTokenId;

    this.accountAndTokenBeforeUpdate(accountId, sellTokenId);
    this.accountAndTokenAfterUpdate(accountId, sellTokenId);
    this.accountAndTokenBeforeUpdate(accountId, sellTokenId);
    this.accountAndTokenAfterUpdate(accountId, sellTokenId);

    this.orderBeforeUpdate(BigInt(orderLeafId));
    this.removeOrder(orderLeafId);
    this.orderAfterUpdate(BigInt(orderLeafId));

    const { r_chunks_bigint, o_chunks_bigint, isCriticalChunk } = this.getTxChunks(req, {
      txOffset: this.latestTxId - BigInt(borrowOrder.orderTxId),
      oriMatchedInterest: BigInt(borrowOrder.arg3),
      matchedTime: BigInt(req.metadata?.matchedTime || this.currentTime),
    });

    this.currentHoldAuctionOrder = borrowOrder;
    const tx =  {
      reqData,
      tsPubKey: from.tsPubKey,
      sigR: ['0', '0'],
      sigS: '0',
      r_chunks: r_chunks_bigint,
      o_chunks: o_chunks_bigint,
      isCriticalChunk,
    };

    this.addTxLogs(tx);
    return tx as TsRollupBaseType;

  }

  async DoReqAuctionExchange(req: TransactionInfo): Promise<TsRollupBaseType> {
    const reqData = req.encodeMessage();
    const orderLeafId = Number(req.metadata?.orderId);
    const lendOrder = this.getOrder(orderLeafId);
    assert(lendOrder, `doAuctionMatch: order not found orderLeafId=${orderLeafId}`);
    this.matchedLendInterest = BigInt(lendOrder.arg3) > this.matchedLendInterest ? BigInt(lendOrder.arg3) : this.matchedLendInterest;
    const accountId = BigInt(lendOrder.accountId);
    assert(accountId !== 0n, `doAuctionMatch: order not found orderLeafId=${orderLeafId} (order.accountId=0)`);
    const lendAcc = this.getAccount(BigInt(lendOrder.accountId));
    assert(lendAcc, `doAuctionMatch: maker account not found accountId=${lendOrder.accountId}`);

    const lendTokenId = lendOrder.tokenId.toString() as TsTokenId;

    const bondTokenId = req.metadata?.bondTokenId as TsTokenId; // TODO: get from order
    assert(bondTokenId, 'doAuctionMatch: bondTokenId not found');
    const addLendCumAmt = BigInt(req.metadata?.matchedLendAmt || '0');
    const matchedBondAmt = BigInt(req.metadata?.matchedBondAmt || '0');

    const feeTokenId = BigInt(req.metadata?.feeTokenId || '0');
    const actualFeeTokenId = BigInt(lendTokenId);
    assert(feeTokenId === actualFeeTokenId, `feeTokenId=${feeTokenId} not match actualFeeTokenId=${actualFeeTokenId}`);
    const feeAmt = BigInt(req.metadata?.feeAmt || '0');
    const days = (BigInt(this.currentHoldAuctionOrder?.arg1 || '0') - BigInt(this.currentTime)) / 86400n;
    const actualFeeAmt = calcAuctionCalcLendFee(BigInt(lendOrder.fee0), addLendCumAmt, days);
    assert(feeAmt === actualFeeAmt, `feeAmt=${feeAmt} not match actualFeeAmt=${actualFeeAmt}`);
    const newLockedAmt = BigInt(lendOrder.lockAmt) - addLendCumAmt - feeAmt;

    this.orderBeforeUpdate(BigInt(orderLeafId));
    lendOrder.acc1 = (BigInt(lendOrder.acc1) + addLendCumAmt).toString();
    lendOrder.acc2 = (BigInt(lendOrder.acc2) + matchedBondAmt).toString();
    lendOrder.lockAmt  = newLockedAmt.toString();
    const isAllAmtMatched = req.metadata?.orderStatus === '2';
    const actualIsFullMatched = lendOrder.amount === lendOrder.acc1;
    assert(isAllAmtMatched === actualIsFullMatched, `isAllAmtMatched=${isAllAmtMatched} not match actualIsFullMatched=${actualIsFullMatched}`);
    if(isAllAmtMatched) {
      this.removeOrder(orderLeafId);
    } else {
      this.updateOrder(lendOrder);
    }
    this.orderAfterUpdate(BigInt(orderLeafId));

    this.accountBeforeUpdate(accountId);
    this.tokenBeforeUpdate(accountId, bondTokenId);
    this.updateAccountToken(lendAcc.L2Address, bondTokenId, matchedBondAmt, 0n);
    this.tokenAfterUpdate(accountId, bondTokenId);

    this.tokenBeforeUpdate(accountId, lendTokenId);
    this.updateAccountToken(lendAcc.L2Address, lendTokenId,
      isAllAmtMatched ? newLockedAmt : 0n,
      isAllAmtMatched ? - addLendCumAmt - feeAmt - newLockedAmt  : -addLendCumAmt - feeAmt);
    this.tokenAfterUpdate(accountId, lendTokenId);
    this.accountAfterUpdate(accountId);

    this.accountBeforeUpdate(accountId);
    this.accountAfterUpdate(accountId);

    this.feeBeforeUpdate(feeTokenId);
    const feeLeaf = this.mkFeeTree.getLeaf(feeTokenId);
    feeLeaf.amount = (BigInt(feeLeaf.amount) + feeAmt).toString();
    this.mkFeeTree.updateLeaf(feeLeaf);
    this.feeAfterUpdate(feeTokenId);

    const { r_chunks_bigint, o_chunks_bigint, isCriticalChunk } = this.getTxChunks(req, {
      txOffset: this.latestTxId - BigInt(lendOrder.orderTxId),
      bondTokenId: BigInt(bondTokenId),
      matchedTime: BigInt(req.metadata?.matchedTime || this.currentTime),
    });

    const tx =  {
      reqData,
      tsPubKey: lendAcc.tsPubKey,
      sigR: ['0', '0'],
      sigS: '0',
      r_chunks: r_chunks_bigint,
      o_chunks: o_chunks_bigint,
      isCriticalChunk,
    };
    this.addTxLogs(tx);
    return tx as TsRollupBaseType;

  }
  doAuctionEnd(req: TransactionInfo) {
    const bondTokenId = req.metadata?.bondTokenId as TsTokenId; // TODO: get from order
    assert(bondTokenId, 'doAuctionMatch: bondTokenId not found');
    assert(!!this.currentHoldAuctionOrder, 'doSecondLimitEnd: currentHoldTakerOrder is null');
    const reqData: TsTxRequestDataType = req.encodeMessage();
    const orderLeafId = Number(req.metadata?.orderId);
    assert(orderLeafId === Number(this.currentHoldAuctionOrder.leafId), 'doSecondLimitEnd: orderLeafId not match');
    const borrowOrder = this.currentHoldAuctionOrder;
    const borrowAccountId = BigInt(borrowOrder.accountId);
    assert(borrowOrder.reqType === TsTxType.AUCTION_BORROW, 'doSecondLimitEnd: reqType not match');
    assert(borrowAccountId !== 0n, `doSecondLimitEnd: order not found orderLeafId=${orderLeafId} (order.sender=0)`);
    const borrowAcc = this.getAccount(borrowAccountId);
    assert(borrowAcc, `doSecondLimitEnd: maker account not found accountId=${borrowOrder.accountId}`);
    const feeTokenId = BigInt(req.metadata?.feeTokenId || '0');
    const actualFeeTokenId = BigInt(borrowOrder.arg4);
    assert(feeTokenId === actualFeeTokenId, `feeTokenId=${feeTokenId} not match actualFeeTokenId=${actualFeeTokenId}`);
    const feeAmt = BigInt(req.metadata?.feeAmt || '0');

    const collateralTokenId = borrowOrder.tokenId.toString() as TsTokenId;
    const borrowTokenId = borrowOrder.arg4.toString() as TsTokenId;
    const addCollateralCumAmt = BigInt(req.metadata?.matchedCollateralAmt || '0');
    const addBorrowCumAmt = BigInt(req.metadata?.matchedBorrowAmt || '0');
    const days = (BigInt(borrowOrder.arg1 || '0') - BigInt(this.currentTime)) / 86400n;
    const actualFeeAmt = calcAuctionCalcBorrowFee(BigInt(borrowOrder.fee0), addBorrowCumAmt, this.matchedLendInterest, days);
    assert(feeAmt === actualFeeAmt, `feeAmt=${feeAmt} not match actualFeeAmt=${actualFeeAmt}`);
    const newLockedAmt = BigInt(borrowOrder.lockAmt) - addCollateralCumAmt;

    this.orderBeforeUpdate(BigInt(orderLeafId));
    borrowOrder.acc1 = (BigInt(borrowOrder.acc1) + addCollateralCumAmt).toString();
    borrowOrder.acc2 = (BigInt(borrowOrder.acc2) + addBorrowCumAmt).toString();
    borrowOrder.lockAmt  = newLockedAmt.toString();
    const isAllAmtMatched = req.metadata?.orderStatus === '2';
    const actualFullMatched = borrowOrder.acc2 === borrowOrder.arg5;
    assert(isAllAmtMatched === actualFullMatched, `isAllAmtMatched=${isAllAmtMatched} not match actualFullMatched=${actualFullMatched}`);
    if(isAllAmtMatched) {
      this.removeOrder(orderLeafId);
    } else {
      this.updateOrder(borrowOrder);
    }
    this.orderAfterUpdate(BigInt(orderLeafId));

    this.accountBeforeUpdate(borrowAccountId);
    this.tokenBeforeUpdate(borrowAccountId, borrowTokenId);
    this.updateAccountToken(borrowAcc.L2Address, borrowTokenId, addBorrowCumAmt - feeAmt, 0n);
    this.tokenAfterUpdate(borrowAccountId, borrowTokenId);

    this.tokenBeforeUpdate(borrowAccountId, collateralTokenId);
    this.updateAccountToken(borrowAcc.L2Address, collateralTokenId,
      isAllAmtMatched ? newLockedAmt : 0n,
      isAllAmtMatched ? -addCollateralCumAmt - newLockedAmt : -addCollateralCumAmt );
    this.tokenAfterUpdate(borrowAccountId, collateralTokenId);
    this.accountAfterUpdate(borrowAccountId);

    this.accountBeforeUpdate(borrowAccountId);
    this.accountAfterUpdate(borrowAccountId);

    this.feeBeforeUpdate(feeTokenId);
    const feeLeaf = this.mkFeeTree.getLeaf(feeTokenId);
    feeLeaf.amount = (BigInt(feeLeaf.amount) + feeAmt).toString();
    this.mkFeeTree.updateLeaf(feeLeaf);
    this.feeAfterUpdate(feeTokenId);

    const { r_chunks_bigint, o_chunks_bigint, isCriticalChunk } = this.getTxChunks(req, {
      txOffset: this.latestTxId - BigInt(borrowOrder.leafId),
      collateralTokenId: BigInt(collateralTokenId),
      collateralAmt: addCollateralCumAmt,
      debtTokenId: BigInt(borrowTokenId),
      debtAmt: BigInt(req.metadata?.matchedDebtAmt || '0'),
      bondTokenId: BigInt(bondTokenId),
      maturityTime: BigInt(borrowOrder.arg1),
      accountId: borrowAccountId,
      matchedTime: BigInt(req.metadata?.matchedTime || this.currentTime),
    });

    this.currentHoldAuctionOrder = null;
    const tx =  {
      reqData,
      tsPubKey: borrowAcc.tsPubKey,
      sigR: ['0', '0'],
      sigS: '0',
      r_chunks: r_chunks_bigint,
      o_chunks: o_chunks_bigint,
      isCriticalChunk,
    };
    this.addTxLogs(tx);
    return tx as TsRollupBaseType;

  }

  private async doCancelOrder(req: TransactionInfo): Promise<TsRollupBaseType> {
    const orderLeafId = BigInt(req.metadata?.orderId || '0');
    const reqData: TsTxRequestDataType = req.encodeMessage();
    const order = this.getOrder(Number(orderLeafId));
    assert(order, `doCancelOrder: order not found orderLeafId=${orderLeafId}`);
    const fromAccountId = BigInt(order.accountId);
    assert(fromAccountId !== 0n, `doCancelOrder: order not found orderLeafId=${orderLeafId} (order.sender=0)`);

    const unlockTokenId = order.tokenId.toString() as TsTokenId;
    const unlockAmt = BigInt(order.lockAmt);

    this.accountAndTokenBeforeUpdate(fromAccountId, unlockTokenId);
    this.updateAccountToken(fromAccountId, unlockTokenId, unlockAmt, -unlockAmt);
    this.accountAndTokenAfterUpdate(fromAccountId, unlockTokenId);
    this.accountAndTokenBeforeUpdate(fromAccountId, unlockTokenId);
    this.accountAndTokenAfterUpdate(fromAccountId, unlockTokenId);

    this.orderBeforeUpdate(orderLeafId);
    this.removeOrder(Number(orderLeafId));
    this.orderAfterUpdate(orderLeafId);

    const txId = this.latestTxId;
    const { r_chunks_bigint, o_chunks_bigint, isCriticalChunk } = this.getTxChunks(req, {
      txId: BigInt(order.orderTxId),
      matchedTime: BigInt(req.metadata?.matchedTime || this.currentTime),
    });

    const tx =  {
      reqData,
      tsPubKey: [req.metadata?.tsPubKeyX, req.metadata?.tsPubKeyY],
      sigR: req.eddsaSig.R8,
      sigS: req.eddsaSig.S,

      r_chunks: r_chunks_bigint,
      o_chunks: o_chunks_bigint,
      isCriticalChunk,
    };

    this.addTxLogs(tx);
    return tx as TsRollupBaseType;
  }


  private async doIncreaseEpoch(req: TransactionInfo): Promise<TsRollupBaseType> {
    const orderLeafId = 0n;
    const account = this.getAccount(0n);
    if(!account) {
      throw new Error('doNoop: account not found');
    }
    this.accountAndTokenBeforeUpdate(account.L2Address, TsTokenId.UNKNOWN);
    this.accountAndTokenAfterUpdate(account.L2Address, TsTokenId.UNKNOWN);
    this.accountAndTokenBeforeUpdate(account.L2Address, TsTokenId.UNKNOWN);
    this.accountAndTokenAfterUpdate(account.L2Address, TsTokenId.UNKNOWN);
    this.orderBeforeUpdate(orderLeafId);
    this.orderAfterUpdate(orderLeafId);

    if(this.currentEpochOne < this.currentEpochTwo) {
      this.currentEpochOne += 2n;
      this.nullifierTreeOne = new NullifierTree(
        this.config.nullifier_tree_height,
      );
    } else {
      this.currentEpochTwo += 2n;
      this.nullifierTreeTwo = new NullifierTree(
        this.config.nullifier_tree_height,
      );
    }
    const { r_chunks_bigint, o_chunks_bigint, isCriticalChunk } = this.getTxChunks(req, {
      matchedTime: BigInt(req.metadata?.matchedTime || this.currentTime),
    });

    const tx =  {
      reqData: req.encodeMessage(),
      tsPubKey: ['0', '0'],
      sigR: [0n, 0n],
      sigS: 0n,

      r_chunks: r_chunks_bigint,
      o_chunks: o_chunks_bigint,
      isCriticalChunk: isCriticalChunk,
    };
    this.addTxLogs(tx);
    return tx as TsRollupBaseType;
  }
  private async doNoop() {
    const req = getEmptyTx();
    const orderLeafId = 0n;
    const account = this.getAccount(0n);
    if(!account) {
      throw new Error('doNoop: account not found');
    }
    this.accountAndTokenBeforeUpdate(account.L2Address, TsTokenId.UNKNOWN);
    this.accountAndTokenAfterUpdate(account.L2Address, TsTokenId.UNKNOWN);
    this.accountAndTokenBeforeUpdate(account.L2Address, TsTokenId.UNKNOWN);
    this.accountAndTokenAfterUpdate(account.L2Address, TsTokenId.UNKNOWN);
    this.orderBeforeUpdate(orderLeafId);
    this.orderAfterUpdate(orderLeafId);
    const tx =  {
      reqData: req.encodeMessage(),
      tsPubKey: ['0', '0'],
      sigR: [0n, 0n],
      sigS: 0n,

      r_chunks: new Array(MAX_CHUNKS_PER_REQ).fill(0n),
      o_chunks: [TsTxType.NOOP],
      isCriticalChunk: [TsTxType.NOOP],
    };
    this.addTxLogs(tx);
    return tx as TsRollupBaseType;
  }

  private async doDeposit(req: TransactionInfo) {
    const depositL2Addr = BigInt(req.arg0);
    const reqData = req.encodeMessage();
    const orderLeafId = 0n;
    const tokenId = req.tokenId.toString() as TsTokenId;
    const depositAccount = this.getAccount(depositL2Addr);
    assert(depositAccount, `Deposit account not found L2Addr=${depositL2Addr}`);

    this.accountAndTokenBeforeUpdate(depositL2Addr, tokenId);
    this.updateAccountToken(depositL2Addr, tokenId, BigInt(req.amount), 0n);
    this.accountAndTokenAfterUpdate(depositL2Addr, tokenId);

    this.accountAndTokenBeforeUpdate(depositL2Addr, tokenId);
    this.accountAndTokenAfterUpdate(depositL2Addr, tokenId);
    this.orderBeforeUpdate(orderLeafId);
    this.orderAfterUpdate(orderLeafId);
    const { r_chunks_bigint, o_chunks_bigint, isCriticalChunk } = this.getTxChunks(req, {
      matchedTime: BigInt(req.metadata?.matchedTime || this.currentTime),
    });

    const tx =  {
      reqData,
      tsPubKey: depositAccount.tsPubKey,
      sigR: ['0', '0'],
      sigS: '0',
      r_chunks: r_chunks_bigint,
      o_chunks: o_chunks_bigint,
      isCriticalChunk,
    };
    this.addTxLogs(tx);
    return tx as TsRollupBaseType;

  }

  private async doTransfer(req: TransactionInfo) {
    const orderLeafId = 0n;
    const senderId = BigInt(req.accountId);
    const receiverId = BigInt(req.arg0);
    const reqData = req.encodeMessage();
    const tokenId = req.tokenId.toString() as TsTokenId;
    const transferAccount = this.getAccount(senderId);
    assert(transferAccount, `transfer account not found L2Addr=${senderId}`);
    this.accountAndTokenBeforeUpdate(senderId, tokenId);
    const newNonce = transferAccount.nonce + 1n;
    this.updateAccountToken(senderId, tokenId, -BigInt(req.amount), 0n);
    this.updateAccountNonce(senderId, newNonce);
    this.accountAndTokenAfterUpdate(senderId, tokenId);

    this.accountAndTokenBeforeUpdate(receiverId, tokenId);
    this.updateAccountToken(receiverId, tokenId, BigInt(req.amount), 0n);
    this.accountAndTokenAfterUpdate(receiverId, tokenId);

    this.orderBeforeUpdate(orderLeafId);
    this.orderAfterUpdate(orderLeafId);

    const { r_chunks_bigint, o_chunks_bigint, isCriticalChunk } = this.getTxChunks(req, {
      receiverId: BigInt(req.arg0),
      matchedTime: BigInt(req.metadata?.matchedTime || this.currentTime),
    });

    const tx =  {
      reqData,
      tsPubKey: transferAccount.tsPubKey, // transfer tx not need signature
      sigR: req.eddsaSig.R8,
      sigS: req.eddsaSig.S,
      r_chunks: r_chunks_bigint,
      o_chunks: o_chunks_bigint,
      isCriticalChunk,
    };
    this.addTxLogs(tx);
    return tx as TsRollupBaseType;

  }

  private async doRegister(req: TransactionInfo): Promise<TsRollupBaseType> {
    const orderLeafId = 0n;
    const reqData = req.encodeMessage();
    const registerL2Addr = BigInt(req.arg0);
    const registerTokenId = req.tokenAddr as TsTokenId;
    const tokenInfos = req.tokenAddr !== TsTokenId.UNKNOWN && Number(req.amount) > 0
      ? {
        [req.tokenAddr as TsTokenId]: {
          amount: BigInt(req.amount),
          lockAmt: 0n,
        }
      }
      : {};
    assert(req.metadata?.tsPubKeyX && req.metadata?.tsPubKeyY, 'Register tx not found tsPubKey');

    const tsPubKeyX = BigInt(req.metadata.tsPubKeyX);
    const tsPubKeyY = BigInt(req.metadata.tsPubKeyY);
    const registerAccount = new TsRollupAccount(
      tokenInfos,
      this.config.token_tree_height,
      [tsPubKeyX, tsPubKeyY,]
    );
    this.accountAndTokenBeforeUpdate(registerL2Addr, registerTokenId);
    this.addAccount(Number(registerL2Addr), registerAccount);
    this.accountAndTokenAfterUpdate(registerL2Addr, registerTokenId);

    this.accountAndTokenBeforeUpdate(registerL2Addr, registerTokenId);
    this.accountAndTokenAfterUpdate(registerL2Addr, registerTokenId);
    this.orderBeforeUpdate(orderLeafId);
    this.orderAfterUpdate(orderLeafId);

    const { r_chunks_bigint, o_chunks_bigint, isCriticalChunk } = this.getTxChunks(req, {
      matchedTime: BigInt(req.metadata?.matchedTime || this.currentTime),
    });

    const tx = {
      reqData,
      tsPubKey: [tsPubKeyX, tsPubKeyY,],
      sigR: ['0', '0'],
      sigS: '0',
      r_chunks: r_chunks_bigint,
      o_chunks: o_chunks_bigint,
      isCriticalChunk,
    };
    this.addTxLogs(tx);
    return tx as TsRollupBaseType;
  }

  private async doWithdraw(req: TransactionInfo): Promise<TsRollupBaseType> {
    const reqData = req.encodeMessage();
    const orderLeafId = 0n;
    const tokenId = req.tokenAddr as TsTokenId;
    const transferL2AddrFrom = BigInt(req.accountId);
    const from = this.getAccount(transferL2AddrFrom);
    assert(from, `Withdraw account not found L2Addr=${transferL2AddrFrom}`);

    this.accountAndTokenBeforeUpdate(transferL2AddrFrom, tokenId);
    const newNonce = from.nonce + 1n;
    this.updateAccountToken(transferL2AddrFrom, tokenId, -BigInt(req.amount), 0n);
    this.updateAccountNonce(transferL2AddrFrom, newNonce);
    this.accountAndTokenAfterUpdate(transferL2AddrFrom, tokenId);

    this.accountAndTokenBeforeUpdate(transferL2AddrFrom, tokenId);
    this.accountAndTokenAfterUpdate(transferL2AddrFrom, tokenId);
    this.orderBeforeUpdate(orderLeafId);
    this.orderAfterUpdate(orderLeafId);


    const { r_chunks_bigint, o_chunks_bigint, isCriticalChunk } = this.getTxChunks(req, {
      matchedTime: BigInt(req.metadata?.matchedTime || this.currentTime),
    });

    const tx =  {
      reqData,
      tsPubKey: from.tsPubKey,
      sigR: req.eddsaSig.R8,
      sigS: req.eddsaSig.S,
      r_chunks: r_chunks_bigint,
      o_chunks: o_chunks_bigint,
      isCriticalChunk,
    };
    this.addTxLogs(tx);
    return tx as TsRollupBaseType;
  }
  private async doForceWithdraw(req: TransactionInfo): Promise<TsRollupBaseType> {
    const reqData = req.encodeMessage();
    const orderLeafId = 0n;
    const tokenId = req.tokenId as TsTokenId;
    const receiverId = BigInt(req.arg0);
    const from = this.getAccount(receiverId);
    assert(from, `Withdraw account not found L2Addr=${receiverId}`);

    this.accountAndTokenBeforeUpdate(receiverId, tokenId);
    // const newNonce = from.nonce + 1n;
    const forceWithdrawAmt = from.getTokenAmount(tokenId);
    this.updateAccountToken(receiverId, tokenId, -forceWithdrawAmt, 0n);
    // this.updateAccountNonce(transferL2AddrFrom, newNonce);
    this.accountAndTokenAfterUpdate(receiverId, tokenId);

    this.accountAndTokenBeforeUpdate(receiverId, tokenId);
    this.accountAndTokenAfterUpdate(receiverId, tokenId);
    this.orderBeforeUpdate(orderLeafId);
    this.orderAfterUpdate(orderLeafId);
    const { r_chunks_bigint, o_chunks_bigint, isCriticalChunk } = this.getTxChunks(req, {
      forceWithdrawAmt,
      matchedTime: BigInt(req.metadata?.matchedTime || this.currentTime),
    });

    const tx =  {
      reqData,
      tsPubKey: from.tsPubKey,
      sigR: req.eddsaSig.R8,
      sigS: req.eddsaSig.S,
      r_chunks: r_chunks_bigint,
      o_chunks: o_chunks_bigint,
      isCriticalChunk,
    };
    this.addTxLogs(tx);
    return tx as TsRollupBaseType;
  }


  async doCreateBondToken(req: TransactionInfo): Promise<TsRollupBaseType> {
    const orderLeafId = 0n;
    const accountId = 0n;
    const bondTokenId = BigInt(req.tokenId);
    const maturityTime = req.arg1;
    const baseTokenId = req.arg4;

    this.bondBeforeUpdate(bondTokenId);
    const bondLeaf = this.mkBondTree.getDefaultLeaf(bondTokenId.toString());
    bondLeaf.baseTokenId = baseTokenId;
    bondLeaf.maturityTime = maturityTime;
    this.mkBondTree.updateLeaf(bondLeaf);
    this.bondAfterUpdate(bondTokenId);

    this.accountAndTokenBeforeUpdate(accountId, TsTokenId.UNKNOWN);
    this.accountAndTokenAfterUpdate(accountId, TsTokenId.UNKNOWN);
    this.accountAndTokenBeforeUpdate(accountId, TsTokenId.UNKNOWN);
    this.accountAndTokenAfterUpdate(accountId, TsTokenId.UNKNOWN);
    this.orderBeforeUpdate(orderLeafId);
    this.orderAfterUpdate(orderLeafId);

    const { r_chunks_bigint, o_chunks_bigint, isCriticalChunk } = this.getTxChunks(req, {
      matchedTime: BigInt(req.metadata?.matchedTime || this.currentTime),
    });
    const tx =  {
      reqData: req.encodeMessage(),
      tsPubKey: ['0', '0'],
      sigR: [0n, 0n],
      sigS: 0n,

      r_chunks: r_chunks_bigint,
      o_chunks: o_chunks_bigint,
      isCriticalChunk: isCriticalChunk,
    };
    this.addTxLogs(tx);
    return tx as TsRollupBaseType;
  }

  async doWithdrawFee(req: TransactionInfo): Promise<TsRollupBaseType> {
    const orderLeafId = 0n;
    const accountId = 0n;
    const feeTokenId = BigInt(req.tokenId);

    this.feeBeforeUpdate(feeTokenId);
    const feeLeaf = this.mkFeeTree.getLeaf(feeTokenId);
    const withdrawFeeAmt = BigInt(feeLeaf.amount);
    assert(withdrawFeeAmt > 0n, `fee amount need to be larger than 0, feeTokenId=${feeTokenId}`);
    feeLeaf.amount = '0';
    this.mkFeeTree.updateLeaf(feeLeaf);
    this.feeAfterUpdate(feeTokenId);
    this.accountAndTokenBeforeUpdate(accountId, TsTokenId.UNKNOWN);
    this.accountAndTokenAfterUpdate(accountId, TsTokenId.UNKNOWN);
    this.accountAndTokenBeforeUpdate(accountId, TsTokenId.UNKNOWN);
    this.accountAndTokenAfterUpdate(accountId, TsTokenId.UNKNOWN);
    this.orderBeforeUpdate(orderLeafId);
    this.orderAfterUpdate(orderLeafId);

    const { r_chunks_bigint, o_chunks_bigint, isCriticalChunk } = this.getTxChunks(req, {
      withdrawFeeAmt,
      matchedTime: BigInt(req.metadata?.matchedTime || this.currentTime),
    });
    const tx =  {
      reqData: req.encodeMessage(),
      tsPubKey: ['0', '0'],
      sigR: [0n, 0n],
      sigS: 0n,

      r_chunks: r_chunks_bigint,
      o_chunks: o_chunks_bigint,
      isCriticalChunk: isCriticalChunk,
    };
    this.addTxLogs(tx);
    return tx as TsRollupBaseType;
  }

  async doSetAdminTsAddr(req: TransactionInfo): Promise<TsRollupBaseType> {
    const orderLeafId = 0n;
    const accountId = 0n;
    const adminTsAddr = BigInt(req.arg6);
    this.adminTsPubKey  = [BigInt(req.metadata?.tsPubKeyX || '0'), BigInt(req.metadata?.tsPubKeyY || '0')];
    const adminAcc = new TsRollupAccount({}, this.config.token_tree_height, this.adminTsPubKey);
    assert(adminAcc.tsAddr === adminTsAddr, `adminTsAddr is not correct, adminTsAddr=${adminTsAddr}, adminAcc.tsAddr=${adminAcc.tsAddr}`);
    this.adminTsAddr = adminTsAddr;
    this.accountAndTokenBeforeUpdate(accountId, TsTokenId.UNKNOWN);
    this.accountAndTokenAfterUpdate(accountId, TsTokenId.UNKNOWN);
    this.accountAndTokenBeforeUpdate(accountId, TsTokenId.UNKNOWN);
    this.accountAndTokenAfterUpdate(accountId, TsTokenId.UNKNOWN);
    this.orderBeforeUpdate(orderLeafId);
    this.orderAfterUpdate(orderLeafId);

    const { r_chunks_bigint, o_chunks_bigint, isCriticalChunk } = this.getTxChunks(req, {
      matchedTime: BigInt(req.metadata?.matchedTime || this.currentTime),
    });
    const tx =  {
      reqData: req.encodeMessage(),
      tsPubKey: ['0', '0'],
      sigR: [0n, 0n],
      sigS: 0n,

      r_chunks: r_chunks_bigint,
      o_chunks: o_chunks_bigint,
      isCriticalChunk: isCriticalChunk,
    };
    this.addTxLogs(tx);
    return tx as TsRollupBaseType;
  }


  doRedeem(req: TransactionInfo): TsRollupBaseType | PromiseLike<TsRollupBaseType> {
    const orderLeafId = 0n;
    const senderId = BigInt(req.accountId);
    const account = this.getAccount(senderId);
    const tokenId = req.tokenId as TsTokenId;
    const amount = BigInt(req.amount);
    assert(account, `account not found, accountId=${senderId}`);
    const b = account.getTokenAmount(tokenId);
    console.log({
      tokenId,
      amount,
      b,
    });
    this.bondBeforeUpdate(BigInt(tokenId));
    this.bondAfterUpdate(BigInt(tokenId));
    this.accountBeforeUpdate(senderId);
    this.tokenBeforeUpdate(senderId, tokenId);
    const newNonce = account.nonce + 1n;
    this.updateAccountNonce(senderId, newNonce);
    this.updateAccountToken(senderId, tokenId, -amount, 0n);
    this.tokenAfterUpdate(senderId, tokenId);
    
    const underlyingTokenId = getUnderlyingTokenId(tokenId);
    this.tokenBeforeUpdate(senderId, underlyingTokenId);
    this.updateAccountToken(senderId, underlyingTokenId, amount, 0n);
    this.tokenAfterUpdate(senderId, underlyingTokenId);
    this.accountAfterUpdate(senderId);
    this.accountBeforeUpdate(senderId);
    this.accountAfterUpdate(senderId);

    this.orderBeforeUpdate(orderLeafId);
    this.orderAfterUpdate(orderLeafId);

    const { r_chunks_bigint, o_chunks_bigint, isCriticalChunk } = this.getTxChunks(req, {
      matchedTime: BigInt(req.metadata?.matchedTime || this.currentTime),
    });
    const tx =  {
      reqData: req.encodeMessage(),
      tsPubKey: account.tsPubKey,
      sigR: req.eddsaSig.R8,
      sigS: req.eddsaSig.S,

      r_chunks: r_chunks_bigint,
      o_chunks: o_chunks_bigint,
      isCriticalChunk: isCriticalChunk,
    };
    this.addTxLogs(tx);
    return tx as TsRollupBaseType;
  }
}

// TODO: getUnderlyingTokenId
export function getUnderlyingTokenId(tokenId: TsTokenId): TsTokenId {
  switch (tokenId) {
    case TsTokenId.TslDAI20231231:
      return TsTokenId.DAI;
    case TsTokenId.TslUSDC20231231:
      return TsTokenId.USDC;
    case TsTokenId.TslUSDT20231231:
      return TsTokenId.USDT;
    case TsTokenId.TslWBTC20231231:
      return TsTokenId.WBTC;
    case TsTokenId.TslETH20231231:
      return TsTokenId.ETH;
    default:
      throw new Error(`invalid tokenId, tokenId=${tokenId}`);
  }
}

export function calcAuctionCalcLendFee(feeRate: bigint, matchedLendingAmt: bigint, days: bigint) {
  const one = 10n ** 8n;
  const temp = feeRate * days;
  const fee = (temp * matchedLendingAmt) / (one * 365n);
  return fee;
}

export function calcAuctionCalcBorrowFee(feeRate: bigint, matchedBorrowingAmt: bigint, matchedInterest: bigint, days: bigint) {
  const one = 10n ** 8n;
  const isLessOne = matchedInterest < one;
  const t = isLessOne ? ((one - matchedInterest) - (matchedInterest - one)) : 0n;
  const absInterest = (matchedInterest - one) + t;
  const fee = (matchedBorrowingAmt * feeRate * days * absInterest) / (one * one * 365n);
  return fee;
}

export function calcSecondaryFee(feeRate: bigint, matchedMQ: bigint, days: bigint) {
  const fee = (matchedMQ * feeRate * days) / (365n * (10n ** 8n));
  return fee;
}

export function calcBQ(targetMQ: bigint, priceMQ: bigint, priceBQ: bigint, days: bigint) {
  const a = 365n * targetMQ * priceBQ;
  const b = (priceMQ * days) + ((365n-days) * priceBQ);
  return a / b;
}

export function calcSecondaryLockedAmt(isLimit: boolean, isSell: boolean, MQ: bigint, BQ: bigint, daysFromCurrent: bigint, daysFromExpired: bigint, maxFeeRate: bigint) {
  if(isSell) {
    return MQ;
  } else {
    // INFO: market order only lock fee amt
    const temp = isLimit ? calcBQ(MQ, MQ, BQ, daysFromExpired) : BQ;
    const feeAmt = calcSecondaryFee(maxFeeRate, MQ, daysFromCurrent);
    return temp + feeAmt;
  }
}

export function isAdminTxType(reqType: TsTxType) {
  return [
    TsTxType.NOOP,
    TsTxType.REGISTER,
    TsTxType.DEPOSIT,
    TsTxType.FORCE_WITHDRAW,
    TsTxType.AUCTION_START,
    TsTxType.AUCTION_MATCH,
    TsTxType.AUCTION_END,
    TsTxType.SECOND_LIMIT_START,
    TsTxType.SECOND_LIMIT_EXCHANGE,
    TsTxType.SECOND_LIMIT_END,
    TsTxType.SECOND_MARKET_EXCHANGE,
    TsTxType.SECOND_MARKET_END,
    TsTxType.ADMIN_CANCEL_ORDER,
    TsTxType.INCREASE_EPOCH,
    TsTxType.CREATE_BOND_TOKEN,
    TsTxType.WITHDRAW_FEE,
    TsTxType.EVACUATION,
    TsTxType.SET_ADMIN_TS_ADDR,
  ].includes(reqType);
}



type CircuitStateType = {
  feeRoot: any;
  bondRoot: any;
  orderRoot: any;
  accRoot: any;
  nullifierRoot: any;
  epoch: any;
  adminTsAddr: any;
  txCount: any
}

type PreProcessedReqType = {
  req: any;
  sig: any;
  unitSet: any;
  chunks: any;
  nullifierTreeId: any;
  nullifierElemId: any;
  matchedTime: any;
}
function convertToPreProcessedReqType(currentTxLogs: any[], matchedTimeStr: any) {
  const result = [];
  const raw = [];
  for (let index = 0; index < currentTxLogs.length; index++) {
    const txLog = currentTxLogs[index];
    const { result: token, raw: raw_token } = parseUnits(txLog, ['r_tokenLeafId', 'r_oriTokenLeaf', 'r_newTokenLeaf', 'r_tokenRootFlow', 'r_tokenMkPrf', ]);
    const { result: account, raw: raw_account } = parseUnits(txLog, ['r_accountLeafId', 'r_oriAccountLeaf', 'r_newAccountLeaf', 'r_accountRootFlow', 'r_accountMkPrf', ]);
    const { result: order, raw: raw_order } = parseUnits(txLog, ['r_orderLeafId', 'r_oriOrderLeaf', 'r_newOrderLeaf', 'r_orderRootFlow', 'r_orderMkPrf', ]);
    const { result: fee, raw: raw_fee } = parseUnits(txLog, ['r_feeLeafId', 'r_oriFeeLeaf', 'r_newFeeLeaf', 'r_feeRootFlow', 'r_feeMkPrf', ]);
    const { result: bondToken, raw: raw_bondToken } = parseUnits(txLog, ['r_bondTokenLeafId', 'r_oriBondTokenLeaf', 'r_newBondTokenLeaf', 'r_bondTokenRootFlow', 'r_bondTokenMkPrf', ]);
    const { result: nullifier, raw: raw_nullifier } = parseUnits(txLog, ['r_nullifierLeafId', 'r_oriNullifierLeaf', 'r_newNullifierLeaf', 'r_nullifierRootFlow', 'r_nullifierMkPrf', ]);
    const preprocessed: PreProcessedReqType = {
      req: txLog['reqData'],
      sig: [
        txLog['tsPubKey'], txLog['sigR'], txLog['sigS'],
      ],
      unitSet: [
        token, account, order, fee, bondToken, nullifier,
      ],
      chunks: txLog['r_chunks'],
      nullifierTreeId: txLog['nullifierTreeId'],
      nullifierElemId: txLog['nullifierElemId'],
      matchedTime: matchedTimeStr,
    };
    raw.push({
      ...preprocessed,
      unitSet: {
        token: raw_token,
        account: raw_account,
        order: raw_order,
        fee: raw_fee,
        bondToken: raw_bondToken,
        nullifier: raw_nullifier,
      }
    });
    result.push([
      preprocessed.req, preprocessed.sig, preprocessed.unitSet, preprocessed.chunks, preprocessed.nullifierTreeId, preprocessed.nullifierElemId, matchedTimeStr,
    ]);
  }
  return {
    result, raw
  };
}

function parseUnits(obj: any, keys: string[]) {
  const firstKey = keys[0];
  const unitLength = obj[firstKey].length;
  const result = [];
  const raw = [];
  for (let index = 0; index < unitLength; index++) {
    const temp = [];
    const temp1: any = {};
    for (let keyIndex = 0; keyIndex < keys.length; keyIndex++) {
      const key = keys[keyIndex];
      temp.push(obj[key][index]);
      temp1[key] = obj[key][index];
    }
    raw.push(temp1);
    result.push(temp);
  }
  return {
    result, raw
  };
}

function convertToCircuitStateType(circuitInpunts: any, length: number, count: number) {
  const result = [];
  const raw = [];
  for (let index = 0; index < length; index++) {
    const temp = [
      circuitInpunts['feeRootFlow'][index],
      circuitInpunts['bondTokenRootFlow'][index],
      circuitInpunts['orderRootFlow'][index],
      circuitInpunts['accountRootFlow'][index],
      [
        circuitInpunts['nullifierRootFlow'][0][index],
        circuitInpunts['nullifierRootFlow'][1][index]
      ],
      [
        circuitInpunts['epochFlow'][0][index],
        circuitInpunts['epochFlow'][1][index]
      ],
      circuitInpunts['adminTsAddrFlow'][index],
      (count + index).toString(),
    ];

    const temp1 = {
      feeRootFlow: circuitInpunts['feeRootFlow'][index],
      bondTokenRootFlow: circuitInpunts['bondTokenRootFlow'][index],
      orderRootFlow: circuitInpunts['orderRootFlow'][index],
      accountRootFlow: circuitInpunts['accountRootFlow'][index],
      nullifierRootFlow: [
        circuitInpunts['nullifierRootFlow'][0][index],
        circuitInpunts['nullifierRootFlow'][1][index]
      ],
      epochFlow: [
        circuitInpunts['epochFlow'][0][index],
        circuitInpunts['epochFlow'][1][index]
      ],
      adminTsAddrFlow: circuitInpunts['adminTsAddrFlow'][index],
      txCount: (count + index).toString(),
    };
    result.push(temp);
    raw.push(temp1);
  }
  return {
    result, raw
  };
}