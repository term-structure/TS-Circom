import { TsMerkleTree } from '../merkle-tree-dp';
import { getDefaultFeeLeaf, FeeLeafEntity } from '../ts-types/mock-types';
import { TsFeeLeafEncodeType } from '../ts-types/ts-rollup-types';

export interface CircuitFeeTxPayload { 
  r_feeLeafId: Array<string | bigint>,
  r_oriFeeLeaf: Array<TsFeeLeafEncodeType>,
  r_newFeeLeaf: Array<TsFeeLeafEncodeType>,
  r_feeRootFlow: Array<Array<string|bigint>>,
  r_feeMkPrf: Array<string[]|(string | bigint)[]>,
}

export class FeeTree {
  FeeMap: {[k: number | string]: FeeLeafEntity} = {};
  max!: bigint;
  private tree: TsMerkleTree;
  constructor(height: number) {
    const defaultLeafHash = this.getDefaultLeaf().encodeLeafHash();
    this.max = BigInt(2 ** height);
    this.tree = new TsMerkleTree(
      Object.entries(this.FeeMap).sort((a, b) => Number(a[0]) - Number(b[0])).map((o) => o[1].encodeLeafHash()),
      height,
      defaultLeafHash
    );
  }

  private payload!: CircuitFeeTxPayload;
  private updateBefore(leafId: bigint) {
    const leaf = this.getLeaf(leafId);

    this.payload.r_feeLeafId.push(leafId);
    this.payload.r_oriFeeLeaf.push(leaf.encodeLeafMessage());
    this.payload.r_feeMkPrf.push(this.getProof(leafId));
    this.payload.r_feeRootFlow.push([this.getRoot()]);
  }
  private updateAfter(leafId: bigint) {
    const leaf = this.getLeaf(leafId);

    this.payload.r_newFeeLeaf.push(leaf.encodeLeafMessage());

    const idx = this.payload.r_feeRootFlow.length - 1;
    if(this.payload.r_feeRootFlow[idx]?.length) {
      this.payload.r_feeRootFlow[idx].push(this.getRoot());
    } else {
      throw new Error('feeAfterUpdate: feeRootFlow not found');
    }
  }
  preparePayload() {
    this.payload = {
      r_feeLeafId: [],
      r_oriFeeLeaf: [],
      r_newFeeLeaf: [],
      r_feeRootFlow: [],
      r_feeMkPrf: [],
    };
  }
  getPayload() {
    return this.payload;
  }

  getRoot() {
    return this.tree.getRoot();
  }
  updateLeaf(leaf: FeeLeafEntity) {
    // this.updateBefore(BigInt(leaf.leafId));
    this.FeeMap[leaf.leafId] = leaf;
    this.tree.updateLeafNode(BigInt(leaf.leafId), BigInt(leaf.encodeLeafHash()));
    // this.updateAfter(BigInt(leaf.leafId));
  }
  updateDoNothing() {
    const leafId = BigInt(0);
    const leaf = this.getLeaf(leafId);
    this.updateLeaf(leaf);
  }
  getLeaf(leaf_id : bigint): FeeLeafEntity {
    if(!this.FeeMap[leaf_id.toString()]) {
      this.FeeMap[leaf_id.toString()] = this.getDefaultLeaf(leaf_id.toString());
    }
    return this.FeeMap[leaf_id.toString()];
  }
  getProof(leaf_id : bigint) {
    return this.tree.getProof(leaf_id);
  }

  getDefaultLeaf(leafId = '0') {
    return getDefaultFeeLeaf(leafId);
  }
}