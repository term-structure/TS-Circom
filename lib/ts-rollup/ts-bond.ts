import { TsTokenId } from 'term-structure-sdk';
import { TsMerkleTree } from '../merkle-tree-dp';
import { getDefaultBondLeaf, BondLeafEntity } from '../ts-types/mock-types';
import { TsBondLeafEncodeType } from '../ts-types/ts-rollup-types';

export interface CircuitBondTxPayload { 
  r_bondTokenLeafId: Array<string | bigint>,
  r_oriBondTokenLeaf: Array<TsBondLeafEncodeType>,
  r_newBondTokenLeaf: Array<TsBondLeafEncodeType>,
  r_bondTokenRootFlow: Array<Array<string | bigint>>,
  r_bondTokenMkPrf: Array<string[] | (string | bigint)[]>,
}

export class BondTree {
  BondMap: {[k: number | string]: BondLeafEntity} = {};
  max!: bigint;
  private tree: TsMerkleTree;
  constructor(height: number) {
    const defaultLeafHash = this.getDefaultLeaf().encodeLeafHash();
    this.max = BigInt(2 ** height);
    this.tree = new TsMerkleTree(
      Object.entries(this.BondMap).sort((a, b) => Number(a[0]) - Number(b[0])).map((o) => o[1].encodeLeafHash()),
      height,
      defaultLeafHash
    );

  }

  private payload!: CircuitBondTxPayload;
  private updateBefore(leafId: bigint) {
    const leaf = this.getLeaf(leafId);

    this.payload.r_bondTokenLeafId.push(leafId);
    this.payload.r_oriBondTokenLeaf.push(leaf.encodeLeafMessage());
    this.payload.r_bondTokenMkPrf.push(this.getProof(leafId));
    this.payload.r_bondTokenRootFlow.push([this.getRoot()]);
  }
  private updateAfter(leafId: bigint) {
    const leaf = this.getLeaf(leafId);

    this.payload.r_newBondTokenLeaf.push(leaf.encodeLeafMessage());

    const idx = this.payload.r_bondTokenRootFlow.length - 1;
    if(this.payload.r_bondTokenRootFlow[idx]?.length) {
      this.payload.r_bondTokenRootFlow[idx].push(this.getRoot());
    } else {
      throw new Error('bondAfterUpdate: bondRootFlow not found');
    }
  }
  preparePayload() {
    this.payload = {
      r_bondTokenLeafId: [],
      r_oriBondTokenLeaf: [],
      r_newBondTokenLeaf: [],
      r_bondTokenRootFlow: [],
      r_bondTokenMkPrf: [],
    };
  }
  getPayload() {
    return this.payload;
  }

  getRoot() {
    return this.tree.getRoot();
  }
  updateLeaf(leaf: BondLeafEntity) {
    // this.updateBefore(BigInt(leaf.leafId));
    this.BondMap[leaf.leafId] = leaf;
    this.tree.updateLeafNode(BigInt(leaf.leafId), BigInt(leaf.encodeLeafHash()));
    // this.updateAfter(BigInt(leaf.leafId));
  }
  updateDoNothing() {
    const leafId = BigInt(0);
    const leaf = this.getLeaf(leafId);
    this.updateLeaf(leaf);
  }
  getLeaf(leaf_id : bigint): BondLeafEntity {
    if(!this.BondMap[leaf_id.toString()]) {
      this.BondMap[leaf_id.toString()] = this.getDefaultLeaf(leaf_id.toString());
    }
    return this.BondMap[leaf_id.toString()];
  }
  getProof(leaf_id : bigint) {
    return this.tree.getProof(leaf_id);
  }

  getDefaultLeaf(leafId = '0') {
    return getDefaultBondLeaf(leafId);
  }
}