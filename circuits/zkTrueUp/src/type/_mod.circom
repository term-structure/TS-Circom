pragma circom 2.1.5;

include "./../const/_mod.circom";
include "./account.circom";
include "./arr.circom";
include "./bool.circom";
include "./channel.circom";
include "./fee.circom";
include "./nullifier.circom";
include "./order.circom";
include "./prep_req.circom";
include "./req.circom";
include "./sig.circom";
include "./state.circom";
include "./token.circom";
include "./unit_set.circom";
include "./unit.circom";

template Slice(len, start, slice_len){
    signal input arr[len];
    signal output out[slice_len];
    for(var i = 0; i < slice_len; i++)
        out[i] <== arr[i + start];
}
function Cum(idx, arr){
    var res = 0;
    for(var i = 0; i < idx; i++)
        res = res + arr[i];
    return res;
}
template Bool(){
    signal input a;
    signal output {bool} out <== a;
    a * (1 - a) === 0;
}
function LenOfReq(){
    return 20;
}
template Req(){
    signal input arr[LenOfReq()];
    signal output (opType, accId, tokenId, amount, nonce, fee0, fee1, txFeeTokenId, txFeeAmt) <== (arr[0], arr[1], arr[2], arr[3], arr[4], arr[5], arr[6], arr[7], arr[8]);
    signal output arg[LenOfReq() - 9] <== Slice(LenOfReq(), 9, LenOfReq() - 9)(arr);
}
template Req_Alloc(){
    signal input raw[LenOfReq()];
    signal output arr[LenOfReq()] <== raw;
    var bits[LenOfReq()] = [BitsOpType(), BitsAccId(), BitsTokenId(), BitsUnsignedAmt(), BitsNonce(), BitsRatio(), BitsRatio(), BitsTokenId(), BitsUnsignedAmt(), BitsAccId(), BitsTime(), BitsTime(), BitsRatio(), BitsTokenId(), BitsUnsignedAmt(), BitsTsAddr(), BitsEpoch(), BitsSide(), BitsRatio(), ConstFieldBitsFull()];
    for(var i = 0; i < LenOfReq(); i++)
        _ <== Num2Bits(bits[i])(arr[i]);
}
function LenOfSig(){
    return 5;
}
template Sig(){
    signal input arr[LenOfSig()];
    signal output (tsPubKeyX, tsPubKeyY, RX, RY, S) <== (arr[0], arr[1], arr[2], arr[3], arr[4]);
}
template Sig_Alloc(){
    signal input raw[LenOfSig()];
    signal output arr[LenOfSig()] <== raw;
}
function LenOfState(){
    return 10;
}
template State(){
    signal input arr[LenOfState()];
    signal output (feeRoot, tSBTokenRoot, orderRoot, accRoot, nullifierRoot[2], epoch[2], adminTsAddr, txCount) <== (arr[0], arr[1], arr[2], arr[3], [arr[4], arr[5]], [arr[6], arr[7]], arr[8], arr[9]);
}
template State_Alloc(){
    signal input raw[LenOfState()];
    signal output arr[LenOfState()] <== raw;
    _ <== Num2Bits(BitsEpoch())(arr[6]); 
    _ <== Num2Bits(BitsEpoch())(arr[7]); 
}
function LenOfUnit(len_of_leaf, tree_height){
    return 1 + len_of_leaf + len_of_leaf + 1 + 1 + tree_height;
}
template Unit(len_of_leaf, tree_height){
    var len = LenOfUnit(len_of_leaf, tree_height);
    var offsets[6] = [1, len_of_leaf, len_of_leaf, 1, 1, tree_height];
    signal input arr[len];
    signal output leafId    [offsets[0]] <== Slice(len, Cum(0, offsets), offsets[0])(arr);
    signal output oriLeaf   [offsets[1]] <== Slice(len, Cum(1, offsets), offsets[1])(arr);
    signal output newLeaf   [offsets[2]] <== Slice(len, Cum(2, offsets), offsets[2])(arr);
    signal output oriRoot   [offsets[3]] <== Slice(len, Cum(3, offsets), offsets[3])(arr);
    signal output newRoot   [offsets[4]] <== Slice(len, Cum(4, offsets), offsets[4])(arr);
    signal output mkPrf     [offsets[5]] <== Slice(len, Cum(5, offsets), offsets[5])(arr);
}
function LenOfTokenLeaf(){
    return 2;
}
template TokenLeaf(){
    signal input arr[LenOfTokenLeaf()];
    signal output (avl_amt, locked_amt) <== (arr[0], arr[1]);
}
template TokenLeaf_Alloc(){
    signal input raw[LenOfTokenLeaf()];
    signal output arr[LenOfTokenLeaf()] <== raw;
    _ <== Num2Bits(BitsAmount())(arr[0] + (1 << BitsUnsignedAmt()));
    _ <== Num2Bits(BitsUnsignedAmt())(arr[1]);
}
function LenOfTokenUnit(){
    return LenOfUnit(LenOfTokenLeaf(), TokenTreeHeight());
}
template TokenUnit(){
    signal input arr[LenOfTokenUnit()];
    signal output leafId[1];
    signal output oriLeaf[LenOfTokenLeaf()], newLeaf[LenOfTokenLeaf()];
    signal output oriRoot[1], newRoot[1], mkPrf[TokenTreeHeight()];
    (leafId, oriLeaf, newLeaf, oriRoot, newRoot, mkPrf) <== Unit(LenOfTokenLeaf(), TokenTreeHeight())(arr);
}
template TokenUnit_Alloc(){
    signal input raw[LenOfTokenUnit()];
    signal output arr[LenOfTokenUnit()] <== raw;
    component token_unit = TokenUnit();
    token_unit.arr <== arr;
    _ <== TokenLeaf_Alloc()(token_unit.oriLeaf);
    _ <== TokenLeaf_Alloc()(token_unit.newLeaf);
}
function LenOfAccLeaf(){
    return 3;
}
template AccLeaf(){
    signal input arr[LenOfAccLeaf()];
    signal output (tsAddr, nonce, tokens) <== (arr[0], arr[1], arr[2]);
}
template AccLeaf_Alloc(){
    signal input raw[LenOfAccLeaf()];
    signal output arr[LenOfAccLeaf()] <== raw;
    _ <== Num2Bits(BitsTsAddr())(arr[0]);
    _ <== Num2Bits(BitsNonce())(arr[1]);
}
function LenOfAccUnit(){
    return LenOfUnit(LenOfAccLeaf(), AccTreeHeight());
}
template AccUnit(){
    signal input arr[LenOfAccUnit()];
    signal output leafId[1];
    signal output oriLeaf[LenOfAccLeaf()], newLeaf[LenOfAccLeaf()];
    signal output oriRoot[1], newRoot[1], mkPrf[AccTreeHeight()];
    (leafId, oriLeaf, newLeaf, oriRoot, newRoot, mkPrf) <== Unit(LenOfAccLeaf(), AccTreeHeight())(arr);
}
template AccUnit_Alloc(){
    signal input raw[LenOfAccUnit()];
    signal output arr[LenOfAccUnit()] <== raw;
    component acc_unit = AccUnit();
    acc_unit.arr <== arr;
    _ <== AccLeaf_Alloc()(acc_unit.oriLeaf);
    _ <== AccLeaf_Alloc()(acc_unit.newLeaf);
}
function LenOfOrderLeaf(){
    return LenOfReq() + 4;
}
template OrderLeaf(){
    signal input arr[LenOfOrderLeaf()];
    signal output req[LenOfReq()] <== Slice(LenOfOrderLeaf(), 0, LenOfReq())(arr);
    signal output (txId, cumAmt0, cumAmt1, lockedAmt) <== (arr[LenOfReq()], arr[LenOfReq() + 1], arr[LenOfReq() + 2], arr[LenOfReq() + 3]);
}
template OrderLeaf_Alloc(){
    signal input raw[LenOfOrderLeaf()];
    signal output arr[LenOfOrderLeaf()] <== raw;
    component order_leaf = OrderLeaf();
    order_leaf.arr <== arr;
    _ <== Req_Alloc()(order_leaf.req);
    _ <== Num2Bits(BitsAmount())(order_leaf.cumAmt0);
    _ <== Num2Bits(BitsAmount())(order_leaf.cumAmt1);
    _ <== Num2Bits(BitsAmount())(order_leaf.lockedAmt);
}
function LenOfOrderUnit(){
    return LenOfUnit(LenOfOrderLeaf(), OrderTreeHeight());
}
template OrderUnit(){
    signal input arr[LenOfOrderUnit()];
    signal output leafId[1];
    signal output oriLeaf[LenOfOrderLeaf()], newLeaf[LenOfOrderLeaf()];
    signal output oriRoot[1], newRoot[1], mkPrf[OrderTreeHeight()];
    (leafId, oriLeaf, newLeaf, oriRoot, newRoot, mkPrf) <== Unit(LenOfOrderLeaf(), OrderTreeHeight())(arr);
}
template OrderUnit_Alloc(){
    signal input raw[LenOfOrderUnit()];
    signal output arr[LenOfOrderUnit()] <== raw;
    component order_unit = OrderUnit();
    order_unit.arr <== arr;
    _ <== OrderLeaf_Alloc()(order_unit.oriLeaf);
    _ <== OrderLeaf_Alloc()(order_unit.newLeaf);
}
function LenOfFeeLeaf(){
    return 1;
}
template FeeLeaf(){
    signal input arr[LenOfFeeLeaf()];
    signal output amount <== arr[0];
}
template FeeLeaf_Alloc(){
    signal input raw[LenOfFeeLeaf()];
    signal output arr[LenOfFeeLeaf()] <== raw;
    _ <== Num2Bits(BitsAmount())(arr[0] + (1 << BitsUnsignedAmt())); 
}
function LenOfFeeUnit(){
    return LenOfUnit(LenOfFeeLeaf(), FeeTreeHeight());
}
template FeeUnit(){
    signal input arr[LenOfFeeUnit()];
    signal output leafId[1];
    signal output oriLeaf[LenOfFeeLeaf()], newLeaf[LenOfFeeLeaf()];
    signal output oriRoot[1], newRoot[1], mkPrf[FeeTreeHeight()];
    (leafId, oriLeaf, newLeaf, oriRoot, newRoot, mkPrf) <== Unit(LenOfFeeLeaf(), FeeTreeHeight())(arr);
}
template FeeUnit_Alloc(){
    signal input raw[LenOfFeeUnit()];
    signal output arr[LenOfFeeUnit()] <== raw;
    component fee_unit = FeeUnit();
    fee_unit.arr <== arr;
    _ <== FeeLeaf_Alloc()(fee_unit.oriLeaf);
    _ <== FeeLeaf_Alloc()(fee_unit.newLeaf);
}
function LenOfTSBTokenLeaf(){
    return 2;
}
template TSBTokenLeaf(){
    signal input arr[LenOfTSBTokenLeaf()];
    signal output (baseTokenId, maturity) <== (arr[0], arr[1]);
}
template TSBTokenLeaf_Alloc(){
    signal input raw[LenOfTSBTokenLeaf()];
    signal output arr[LenOfTSBTokenLeaf()] <== raw;
    _ <== Num2Bits(BitsTokenId())(arr[0]);
    _ <== Num2Bits(BitsTime())(arr[1]);
}
function LenOfTSBTokenUnit(){
    return LenOfUnit(LenOfTSBTokenLeaf(), TSBTokenTreeHeight());
}
template TSBTokenUnit(){
    signal input arr[LenOfTSBTokenUnit()];
    signal output leafId[1];
    signal output oriLeaf[LenOfTSBTokenLeaf()], newLeaf[LenOfTSBTokenLeaf()];
    signal output oriRoot[1], newRoot[1], mkPrf[TSBTokenTreeHeight()];
    (leafId, oriLeaf, newLeaf, oriRoot, newRoot, mkPrf) <== Unit(LenOfTSBTokenLeaf(), TSBTokenTreeHeight())(arr);
}
template TSBTokenUnit_Alloc(){
    signal input raw[LenOfTSBTokenUnit()];
    signal output arr[LenOfTSBTokenUnit()] <== raw;
    component tSBToken_unit = TSBTokenUnit();
    tSBToken_unit.arr <== arr;
    _ <== TSBTokenLeaf_Alloc()(tSBToken_unit.oriLeaf);
    _ <== TSBTokenLeaf_Alloc()(tSBToken_unit.newLeaf);
}
function LenOfNullifierLeaf(){
    return 8;
}
function LenOfNullifierUnit(){
    return LenOfUnit(LenOfNullifierLeaf(), NullifierTreeHeight());
}
template NullifierUnit(){
    signal input arr[LenOfNullifierUnit()];
    signal output (leafId[1], oriLeaf[LenOfNullifierLeaf()], newLeaf[LenOfNullifierLeaf()], oriRoot[1], newRoot[1], mkPrf[NullifierTreeHeight()]) <== Unit(LenOfNullifierLeaf(), NullifierTreeHeight())(arr);
}
template NullifierUnit_Alloc(){
    signal input raw[LenOfNullifierUnit()];
    signal output arr[LenOfNullifierUnit()] <== raw;
}
function LenOfUnitSet(){
    return LenOfTokenUnit() * MaxTokenUnitsPerReq() + 
    LenOfAccUnit() * MaxAccUnitsPerReq() + 
    LenOfOrderUnit() * MaxOrderUnitsPerReq() + 
    LenOfFeeUnit() * MaxFeeUnitsPerReq() + 
    LenOfTSBTokenUnit() * MaxTSBTokenUnitsPerReq() + 
    LenOfNullifierUnit() * MaxNullifierUnitsPerReq();
}
template UnitSet(){
    signal input arr[LenOfUnitSet()];
    signal output tokenUnits[MaxTokenUnitsPerReq()][LenOfTokenUnit()];
    signal output accUnits[MaxAccUnitsPerReq()][LenOfAccUnit()];
    signal output orderUnits[MaxOrderUnitsPerReq()][LenOfOrderUnit()];
    signal output feeUnits[MaxFeeUnitsPerReq()][LenOfFeeUnit()];
    signal output tSBTokenUnits[MaxTSBTokenUnitsPerReq()][LenOfTSBTokenUnit()];
    signal output nullifierUnits[MaxNullifierUnitsPerReq()][LenOfNullifierUnit()];
    var offsets[6] = [LenOfTokenUnit() * MaxTokenUnitsPerReq(), LenOfAccUnit() * MaxAccUnitsPerReq(), LenOfOrderUnit() * MaxOrderUnitsPerReq(), LenOfFeeUnit() * MaxFeeUnitsPerReq(), LenOfTSBTokenUnit() * MaxTSBTokenUnitsPerReq(), LenOfNullifierUnit() * MaxNullifierUnitsPerReq()];

    for (var i = 0; i < MaxTokenUnitsPerReq()     ; i++)
        tokenUnits[i]       <== Slice(LenOfUnitSet(), Cum(0, offsets) + i * LenOfTokenUnit()    , LenOfTokenUnit()    )(arr);
    for (var i = 0; i < MaxAccUnitsPerReq()       ; i++)
        accUnits[i]         <== Slice(LenOfUnitSet(), Cum(1, offsets) + i * LenOfAccUnit()      , LenOfAccUnit()      )(arr);
    for (var i = 0; i < MaxOrderUnitsPerReq()     ; i++)
        orderUnits[i]       <== Slice(LenOfUnitSet(), Cum(2, offsets) + i * LenOfOrderUnit()    , LenOfOrderUnit()    )(arr);
    for (var i = 0; i < MaxFeeUnitsPerReq()       ; i++)
        feeUnits[i]         <== Slice(LenOfUnitSet(), Cum(3, offsets) + i * LenOfFeeUnit()      , LenOfFeeUnit()      )(arr);
    for (var i = 0; i < MaxTSBTokenUnitsPerReq()      ; i++)
        tSBTokenUnits[i]        <== Slice(LenOfUnitSet(), Cum(4, offsets) + i * LenOfTSBTokenUnit()     , LenOfTSBTokenUnit()     )(arr);
    for (var i = 0; i < MaxNullifierUnitsPerReq() ; i++)
        nullifierUnits[i]   <== Slice(LenOfUnitSet(), Cum(5, offsets) + i * LenOfNullifierUnit(), LenOfNullifierUnit())(arr);
}
template UnitSet_Alloc(){
    signal input raw[LenOfUnitSet()];
    signal output arr[LenOfUnitSet()] <== raw;
    component unit_set = UnitSet();
    unit_set.arr <== arr;
    for (var i = 0; i < MaxTokenUnitsPerReq()     ; i++)
        _ <== TokenUnit_Alloc()(unit_set.tokenUnits[i]);
    for (var i = 0; i < MaxAccUnitsPerReq()       ; i++)
        _ <== AccUnit_Alloc()(unit_set.accUnits[i]);
    for (var i = 0; i < MaxOrderUnitsPerReq()     ; i++)
        _ <== OrderUnit_Alloc()(unit_set.orderUnits[i]);
    for (var i = 0; i < MaxFeeUnitsPerReq()       ; i++)
        _ <== FeeUnit_Alloc()(unit_set.feeUnits[i]);
    for (var i = 0; i < MaxTSBTokenUnitsPerReq()      ; i++)   
        _ <== TSBTokenUnit_Alloc()(unit_set.tSBTokenUnits[i]);
    for (var i = 0; i < MaxNullifierUnitsPerReq() ; i++)
        _ <== NullifierUnit_Alloc()(unit_set.nullifierUnits[i]);
}
function LenOfPreprocessedReq(){
    return LenOfReq() + LenOfSig() + LenOfUnitSet() + MaxChunksPerReq() + 1 + 1 + 1;
}
template PreprocessedReq(){
    signal input arr[LenOfPreprocessedReq()];
    var offsets[7] = [LenOfReq(), LenOfSig(), LenOfUnitSet(), MaxChunksPerReq(), 1, 1, 1];
    signal output req             [offsets[0]] <== Slice(LenOfPreprocessedReq(), Cum(0, offsets), offsets[0])(arr);
    signal output sig             [offsets[1]] <== Slice(LenOfPreprocessedReq(), Cum(1, offsets), offsets[1])(arr);
    signal output unitSet         [offsets[2]] <== Slice(LenOfPreprocessedReq(), Cum(2, offsets), offsets[2])(arr);
    signal output chunks          [offsets[3]] <== Slice(LenOfPreprocessedReq(), Cum(3, offsets), offsets[3])(arr);
    signal output nullifierTreeId [offsets[4]] <== Slice(LenOfPreprocessedReq(), Cum(4, offsets), offsets[4])(arr);
    signal output nullifierElemId [offsets[5]] <== Slice(LenOfPreprocessedReq(), Cum(5, offsets), offsets[5])(arr);
    signal output matchedTime     [offsets[6]] <== Slice(LenOfPreprocessedReq(), Cum(6, offsets), offsets[6])(arr);
}
template PreprocessedReq_Alloc(){
    signal input raw[LenOfPreprocessedReq()];
    signal output arr[LenOfPreprocessedReq()] <== raw;
    component prep_req = PreprocessedReq();
    prep_req.arr <== arr;
    _ <== Req_Alloc()(prep_req.req);
    _ <== Sig_Alloc()(prep_req.sig);
    _ <== UnitSet_Alloc()(prep_req.unitSet);
    _ <== Num2Bits(1)(prep_req.nullifierTreeId[0]);
    _ <== Num2Bits(log2(LenOfNullifierLeaf()))(prep_req.nullifierElemId[0]);
    _ <== Num2Bits(BitsTime())(prep_req.matchedTime[0]);
}
function LenOfChannel(){
    return LenOfOrderLeaf() + 5;
}
template Channel(){
    signal input arr[LenOfChannel()];
    var offsets[2] = [LenOfOrderLeaf(), 5];
    signal output orderLeaf [offsets[0]] <== Slice(LenOfChannel(), Cum(0, offsets), offsets[0])(arr);
    signal output args      [offsets[1]] <== Slice(LenOfChannel(), Cum(1, offsets), offsets[1])(arr);
}
template Channel_Alloc(){
    signal input raw[LenOfChannel()];
    signal output arr[LenOfChannel()] <== raw;
    component channel = Channel();
    channel.arr <== arr;
    _ <== OrderLeaf_Alloc()(channel.orderLeaf);
}









