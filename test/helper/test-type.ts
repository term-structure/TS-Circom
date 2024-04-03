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
export type BuildMetadataType = {
    defaultNulliferRoot?: string,
}