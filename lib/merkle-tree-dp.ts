import { toTreeLeaf } from './ts-rollup/ts-rollup-helper';

export const DEFAULT_LEAF = 0n;
export type DecimalString = string;

export class TsMerkleTree {
  public nodeMap: Map<bigint, bigint> = new Map;
  public treeHeight = 8;
  private hash: (x : bigint[]) => bigint = toTreeLeaf;
  private defaultLeaf: bigint;
  levelsDefaultHash = new Map<number, bigint>();

  constructor(
    leafs : bigint[],
    treeHeight : number,
    defaultLeaf = DEFAULT_LEAF,
  ) {
    this.treeHeight = treeHeight;
    this.defaultLeaf = defaultLeaf;
    this.setLevelDefaultHash();
    leafs.forEach((leaf, i) => {
      this.updateLeafNode(BigInt(i), leaf);
    });
  }

  getLeafDefaultVavlue() {
    return this.defaultLeaf;
  }

  getProofIds(leaf_id: bigint): DecimalString[] {
    const prfIds: bigint[] = [];
    const leafStart = this.getNodeIdInTree(leaf_id);
    for (let i = leafStart; i > 1n; i = i >> 1n) {
      if ( i % 2n === 0n) {
        prfIds.push(i + 1n);
      } else {
        prfIds.push(i - 1n);
      } 
    }
    return prfIds.map(v => v.toString());
  }
  getNodeIdInTree(leafId: bigint) {
    return leafId + (1n << BigInt(this.treeHeight));
  }
  getDefaultRoot(): bigint {
    return this.getDefaultHashByLevel(0);
  }
  getDefaultHashByLevel(level: number): bigint {
    const result = this.levelsDefaultHash.get(level);
    if (!result) {
      console.log({
        level,
        height: this.treeHeight,
      });
      throw new Error('level is not in the tree');
    }
    return result;
  }
  setLevelDefaultHash() {
    this.levelsDefaultHash = new Map<number, bigint>();
    this.levelsDefaultHash.set(this.treeHeight, BigInt(this.getLeafDefaultVavlue()));

    for(let level = this.treeHeight - 1; level >= 0 ; level--) {
      const prevLevelHash = this.levelsDefaultHash.get(level+1);
      if (prevLevelHash != undefined) {
        this.levelsDefaultHash.set(level, this.hash([prevLevelHash, prevLevelHash]));
      }
    }
  }

  getNode(nodeId: bigint): bigint {
    const node = this.nodeMap.get(nodeId);
    if(!node) {
      const level = merkleTreeIdToLevel(nodeId);
      return this.getDefaultHashByLevel(level);
    }
    return node;
  }

  getRoot() {
    return this.getNode(1n);
  }

  getLeaf(leaf_id : bigint) {
    const nodeId = this.getNodeIdInTree(leaf_id);
    return this.getNode(nodeId);
  }

  getProof(leaf_id : bigint) {
    const prf = [];
    for (let i = leaf_id + (1n << BigInt(this.treeHeight)); i > 1n; i = i >> 1n) {
      const nodeId = i % 2n === 0n ? i + 1n : i - 1n;
      prf.push(this.getNode(nodeId));
    }

    return prf;
  }

  updateLeafNode(leaf_id : bigint, value : bigint) {
    const prf = this.getProof(leaf_id);
    const node_id = this.getNodeIdInTree(leaf_id);
    this.nodeMap.set(node_id, value);
    for (let i = node_id, j = 0; i > 1n; i = i >> 1n) {
      const r = i % 2n === 0n ? [
        this.getNode(i), prf[j]
      ] : [
        prf[j], this.getNode(i),
      ];
      this.nodeMap.set(i >> 1n, this.hash(r));
      j++;
    }
  }

  // verifyProof(leaf_id: number, proof: string[]) {
  //     const leaf_node_id = leaf_id + (1 << this.treeHeight);
  //     const hashes = [];
  //     hashes.push(this.hash([

  //     ]))
  //     for (let i = 0; i < proof.length; i++) {
  //         const node = proof[i]
  //         let data: any = null
  //         let isLeftNode = null
  //     }
                
  //     for (let i = leaf_node_id, j = 0; i > 1; i = Math.floor(i / 2)) {
  //         const r: any = [
  //             [
  //                 this.nodes[i], prf[j]
  //             ],
  //             [
  //                 prf[j], this.nodes[i]
  //             ]
  //         ][i % 2];
  //         this.nodes[Math.floor(i / 2)] = this.hash(r);
  //         j++;
  //     }
  //     return h === this.getRoot();
  // }


 
}
function merkleTreeIdToLevel(merkleTreeId: bigint): number {
  return bigintLog2(merkleTreeId);
}
function bigintLog2(value: bigint) {
  let result = 0n, i, v;
  for (i = 1n; value >> (1n << i); i <<= 1n);
  while (value > 1n) {
    v = 1n << --i;
    if (value >> v) {
      result += v;
      value >>= v;
    }
  }
  return Number(result);
}
