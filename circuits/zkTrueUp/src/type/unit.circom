pragma circom 2.1.5;

template Unit_Enforce(len_of_leaf, tree_height){
    signal input unit[LenOfUnit(len_of_leaf, tree_height)];
    component unit_ = Unit(len_of_leaf, tree_height);
    unit_.arr <== unit;
    VerifyExists(tree_height)(unit_.leafId[0], PoseidonSpecificLen(len_of_leaf)(unit_.oriLeaf), unit_.mkPrf, unit_.oriRoot[0]);
    VerifyExists(tree_height)(unit_.leafId[0], PoseidonSpecificLen(len_of_leaf)(unit_.newLeaf), unit_.mkPrf, unit_.newRoot[0]);
}