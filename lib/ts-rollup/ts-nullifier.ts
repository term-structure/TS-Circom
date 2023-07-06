import { TsMerkleTree } from '../merkle-tree-dp';
import { getDefaultNullifierLeaf, NullifierLeafEntity } from '../ts-types/mock-types';
import { NULLIFIER_MAX_LENGTH } from './ts-env';

export class NullifierTree {
  nullifierMap: {[k: number | string]: NullifierLeafEntity} = {};
  max!: bigint;
  private tree: TsMerkleTree;
  constructor(height: number) {
    const defaultLeafHash = this.getDefaultLeaf().encodeLeafHash();
    this.max = BigInt(2 ** height);
    this.tree = new TsMerkleTree(
      Object.entries(this.nullifierMap).sort((a, b) => Number(a[0]) - Number(b[0])).map((o) => o[1].encodeLeafHash()),
      height,
      defaultLeafHash
    );
  }
  delete() {
    Object.keys(this.nullifierMap).forEach((k) => {
      delete this.nullifierMap[k];
    });
  }
  getRoot() {
    return this.tree.getRoot();
  }
  getLeaf(leaf_id : bigint): NullifierLeafEntity {
    if(!this.nullifierMap[leaf_id.toString()]) {
      const nu = this.getDefaultLeaf();
      nu.leafId = leaf_id.toString();
      this.nullifierMap[leaf_id.toString()] = nu;
    }
    return this.nullifierMap[leaf_id.toString()];
  }
  getProof(leaf_id : bigint) {
    return this.tree.getProof(leaf_id);
  }

  getNulliferInfo(hash : bigint) {
    const leafId = hash % this.max;
    const hashString = hash.toString();
    const leaf = this.getLeaf(leafId);
    const existItem = Object.entries(leaf).find((v) => v[1] === hashString);
    if(!existItem) {
      return {
        isExist: false,
        leafId,
        elemId: leaf.cnt,
      };
    }
    return {
      isExist: true,
      leafId,
      elemId: Number(existItem[0].replace('arg', '')),
    };
  }

  prepareInsertNullifer(hash : bigint) {
    const leafId = hash % this.max; // 0 ~ 2^height - 1
    const leaf: any = this.getLeaf(leafId);
    if(leaf.cnt >= NULLIFIER_MAX_LENGTH) {
      throw new Error(`Nullifier hash is full in leaf=${leafId}`);
    }
    const elemId: number = leaf.cnt;
    return {
      elemId,
      leafId,
      insert: () => {
        leaf[`arg${elemId}`] = hash.toString();
        leaf.cnt += 1;
        this.tree.updateLeafNode(leafId, leaf.encodeLeafHash());
      },
    };
  }

  // TODO:
  getDefaultLeaf() {
    return getDefaultNullifierLeaf();
  }
}