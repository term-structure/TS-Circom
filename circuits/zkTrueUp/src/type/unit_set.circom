pragma circom 2.1.5;

template UnitSet_Enforce(){
    signal input unitSet[LenOfUnitSet()];
    component unit_set = UnitSet();
    unit_set.arr <== unitSet;
    for(var i = 0; i < MaxAccUnitsPerReq(); i++)
        Unit_Enforce(LenOfAccLeaf(), AccTreeHeight())(unit_set.accUnits[i]);
    for(var i = 0; i < MaxTokenUnitsPerReq(); i++)
        Unit_Enforce(LenOfTokenLeaf(), TokenTreeHeight())(unit_set.tokenUnits[i]);
    for(var i = 0; i < MaxOrderUnitsPerReq(); i++)
        Unit_Enforce(LenOfOrderLeaf(), OrderTreeHeight())(unit_set.orderUnits[i]);
    for(var i = 0; i < MaxFeeUnitsPerReq(); i++)
        Unit_Enforce(LenOfFeeLeaf(), FeeTreeHeight())(unit_set.feeUnits[i]);
    for(var i = 0; i < MaxTSBTokenUnitsPerReq(); i++)
        Unit_Enforce(LenOfTSBTokenLeaf(), TSBTokenTreeHeight())(unit_set.tSBTokenUnits[i]);
    for(var i = 0; i < MaxNullifierUnitsPerReq(); i++)
        Unit_Enforce(LenOfNullifierLeaf(), NullifierTreeHeight())(unit_set.nullifierUnits[i]);
}
template UnitSet_ExtractSignerTsAddr(){
    signal input unitSet[LenOfUnitSet()];
    component unit_set = UnitSet();
    unit_set.arr <== unitSet;
    component acc_unit = AccUnit();
    acc_unit.arr <== unit_set.accUnits[0];
    component acc_leaf = AccLeaf();
    acc_leaf.arr <== acc_unit.oriLeaf;
    signal output tsAddt <== acc_leaf.tsAddr;
}