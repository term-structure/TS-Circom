import assert from 'assert';
import { TsAccountLeafEncodeType, tsHashFunc, TsTokenId, TsTokenInfo, dpPoseidonHash } from 'term-structure-sdk';
import { TsMerkleTree } from '../merkle-tree-dp';
import { RESERVED_ACCOUNTS } from './ts-env';

type TokenLeafInfoType = {
  [key in TsTokenId]?: TsTokenInfo;
}
export class TsRollupAccount {
  L2Address = -1n;

  
  private eddsaPubKey: [bigint, bigint];
  get tsPubKey(): [string, string] {
    return [this.eddsaPubKey[0].toString(), this.eddsaPubKey[1].toString()];
  }
  nonce: bigint;
  tokenLeafs: TokenLeafInfoType;
  tokenTree: TsMerkleTree;
  
  tokenTreeSize: number;
  get isNormalAccount() {
    return TsRollupAccount.checkIsNormalAccount(this.L2Address);
  }
  static checkIsNormalAccount(l2Addr: bigint) {
    return l2Addr >= RESERVED_ACCOUNTS;
  }

  public get tsAddr() {
    if(this.tsPubKey[0] === '0' && this.tsPubKey[1] === '0') {
      return '0x0000000000000000000000000000000000000000';
    }
    const raw = BigInt(tsHashFunc(this.tsPubKey));
    const hash = raw % BigInt(2 ** 160);
    return hash;
    // return `0x${this.tsAddr.toString(16)}`;
  }

  constructor(
    tokenLeafs: TokenLeafInfoType,
    tokenTreeSize: number,
    _eddsaPubKey: [bigint, bigint],
    // eddsaPubKey: [bigint, bigint],
    nonce = 0n,
  ) {
    this.tokenTreeSize = tokenTreeSize;
    this.nonce = nonce;
    this.tokenLeafs = tokenLeafs;

    // this.tsAddr = tsAddr;
    this.eddsaPubKey = _eddsaPubKey;
   
    this.tokenTree = new TsMerkleTree(
      [],
      this.tokenTreeSize,
      this.encodeTokenLeaf({
        amount: 0n,
        lockAmt: 0n,
      })
    );

  }

  setAccountAddress(l2Addr: bigint) {
    this.L2Address = l2Addr;
  }
    
  updateNonce(newNonce: bigint) {
    if(this.isNormalAccount) {
      assert(newNonce > this.nonce, 'new nonce need larger than current nonce');
    } else {
      assert(newNonce === this.nonce, 'system account new nonce need equal to current nonce');
    }
    this.nonce = newNonce;
    return this.nonce;
  }

  encodeTokenLeaf(tokenInfo: TsTokenInfo) {
    if(!tokenInfo) {
      return dpPoseidonHash([0n, 0n]);
    }
    return dpPoseidonHash([BigInt(tokenInfo.amount), BigInt(tokenInfo.lockAmt)]);
  }
  encodeTokenLeafs() {
    const arr: TsTokenInfo[] = [];
    const total = 2 ** this.tokenTreeSize;
    for(let i = 0; i < total; i++) {      
      arr.push(this.getTokenLeaf(i.toString() as TsTokenId).leaf);
    }
    return arr.map(t => dpPoseidonHash([
      t.amount,
      t.lockAmt
    ]));
  }

  getTokenRoot() {
    return this.tokenTree.getRoot();
  }

  getTokenLeaf(tokenAddr: TsTokenId): {leafId: bigint, leaf: TsTokenInfo} {
    const leafId = BigInt(tokenAddr);
    const tokenInfo = this.tokenLeafs[tokenAddr];

    if(tokenInfo) {
      return {
        leafId,
        leaf: tokenInfo
      };
    }
    return {
      leafId,
      leaf: {
        amount: 0n,
        lockAmt: 0n,
      }
    };
  }

  getTokenLeafId(tokenAddr: TsTokenId) {
    return BigInt(tokenAddr);
  }

  getTokenProof(tokenAddr: TsTokenId) {
    const leafId = this.getTokenLeafId(tokenAddr);
    return this.tokenTree.getProof(leafId);
  }
  
  updateToken(tokenAddr: TsTokenId, addAmt: bigint, addLockAmt: bigint) {
    if(!this.isNormalAccount) {
      return this.tokenTree.getRoot();
    }
    const leafId = this.getTokenLeafId(tokenAddr);
    let tokenInfo!: TsTokenInfo;
    if(!!this.tokenLeafs[tokenAddr]) {
      const _tokenInfo = this.tokenLeafs[tokenAddr] as TsTokenInfo;
      tokenInfo = {
        amount: _tokenInfo.amount + addAmt,
        lockAmt: _tokenInfo.lockAmt + addLockAmt,
      };
      
    } else {
      tokenInfo = {
        amount: addAmt,
        lockAmt: addLockAmt,
      };
    }
    assert(tokenInfo.amount >= 0n, 'new token amount must >= 0');
    assert(tokenInfo.lockAmt >= 0n, 'new token lock amount must >= 0');
    this.tokenTree.updateLeafNode(leafId, BigInt(this.encodeTokenLeaf(tokenInfo)));
    this.tokenLeafs[tokenAddr] = tokenInfo;
  }

  getTokenAmount(tokenAddr: TsTokenId) {
    return this.getTokenLeaf(tokenAddr).leaf.amount;
  }

  getTokenLockedAmount(tokenAddr: TsTokenId) {
    return this.getTokenLeaf(tokenAddr).leaf.lockAmt;
  }

  encodeAccountLeaf(): TsAccountLeafEncodeType {
    const pub = this.tsAddr;
    return [
      BigInt(pub),
      this.nonce,
      BigInt(this.getTokenRoot()),
    ];
  }

}
