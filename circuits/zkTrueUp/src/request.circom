pragma circom 2.1.5;

include "./const/_mod.circom";
include "./type/_mod.circom";
include "./gadgets/_mod.circom";
include "./mechanism.circom";
include "../../../node_modules/circomlib/circuits/bitify.circom";

template Conn(fee_unit_switch, bond_unit_switch, order_unit_switch, acc_unit_switch, nullifier_unit_switch, token_unit_switch, epoch_switch, admin_ts_addr_swtich){
    signal input {bool} enabled;
    signal input oriState[LenOfState()], newState[LenOfState()], unitSet[LenOfUnitSet()];
    signal input nullifierTreeId;

    assert(MaxFeeUnitsPerReq() == 1);
    assert(MaxBondUnitsPerReq() == 1);
    assert(MaxOrderUnitsPerReq() == 1);
    assert(MaxNullifierUnitsPerReq() == 1);
    assert(MaxTokenUnitsPerReq() == 2);
    assert(MaxAccUnitsPerReq() == 2);
    
    component ori_state = State();
    ori_state.arr <== oriState;
    component new_state = State();
    new_state.arr <== newState;
    component unit_set = UnitSet();
    unit_set.arr <== unitSet;

    component fee_unit = FeeUnit();
    fee_unit.arr <== unit_set.feeUnits[0];
    ImplyEq()(enabled, ori_state.feeRoot, Mux(2)([new_state.feeRoot, fee_unit.oriRoot[0]], fee_unit_switch));
    ImplyEq()(enabled, new_state.feeRoot, Mux(2)([ori_state.feeRoot, fee_unit.newRoot[0]], fee_unit_switch));

    component bond_unit = BondUnit();
    bond_unit.arr <== unit_set.bondUnits[0];
    ImplyEq()(enabled, ori_state.bondRoot, Mux(2)([new_state.bondRoot, bond_unit.oriRoot[0]], bond_unit_switch));
    ImplyEq()(enabled, new_state.bondRoot, Mux(2)([ori_state.bondRoot, bond_unit.newRoot[0]], bond_unit_switch));

    component order_unit = OrderUnit();
    order_unit.arr <== unit_set.orderUnits[0];
    ImplyEq()(enabled, ori_state.orderRoot, Mux(2)([new_state.orderRoot, order_unit.oriRoot[0]], order_unit_switch));
    ImplyEq()(enabled, new_state.orderRoot, Mux(2)([ori_state.orderRoot, order_unit.newRoot[0]], order_unit_switch));

    component acc_unit[MaxAccUnitsPerReq()]; // _[2]
    component acc_leaf[MaxAccUnitsPerReq()][2]; // _[2][2]
    for(var i = 0; i < MaxAccUnitsPerReq(); i++){
        acc_unit[i] = AccUnit();
        acc_unit[i].arr <== unit_set.accUnits[i];
        acc_leaf[i][0] = AccLeaf();
        acc_leaf[i][1] = AccLeaf();
        acc_leaf[i][0].arr <== acc_unit[i].oriLeaf;
        acc_leaf[i][1].arr <== acc_unit[i].newLeaf;
    }
    ImplyEq()(enabled, ori_state.accRoot     , Mux(3)([new_state.accRoot     , acc_unit[0].oriRoot[0], acc_unit[0].oriRoot[0]], acc_unit_switch));
    ImplyEq()(enabled, acc_unit[0].newRoot[0], Mux(3)([acc_unit[0].newRoot[0], acc_unit[0].newRoot[0], acc_unit[1].oriRoot[0]], acc_unit_switch));
    ImplyEq()(enabled, new_state.accRoot     , Mux(3)([ori_state.accRoot     , acc_unit[0].newRoot[0], acc_unit[1].newRoot[0]], acc_unit_switch));

    component nullifier_unit = NullifierUnit();
    nullifier_unit.arr <== unit_set.nullifierUnits[0];
    signal oriNullifierTreeRoot <== Mux(2)([ori_state.nullifierRoot[0], ori_state.nullifierRoot[1]], nullifierTreeId);
    signal newNullifierTreeRoot <== Mux(2)([new_state.nullifierRoot[0], new_state.nullifierRoot[1]], nullifierTreeId);
    ImplyEq()(enabled, oriNullifierTreeRoot * (1 - epoch_switch), Mux(2)([newNullifierTreeRoot * (1 - epoch_switch), nullifier_unit.oriRoot[0]], nullifier_unit_switch));
    ImplyEq()(enabled, newNullifierTreeRoot * (1 - epoch_switch), Mux(2)([oriNullifierTreeRoot * (1 - epoch_switch), nullifier_unit.newRoot[0]], nullifier_unit_switch));

    component token_unit[MaxTokenUnitsPerReq()]; //[2]
    token_unit[0] = TokenUnit();
    token_unit[1] = TokenUnit();
    token_unit[0].arr <== unit_set.tokenUnits[0];
    token_unit[1].arr <== unit_set.tokenUnits[1];
    
    ImplyEq()(enabled, acc_leaf[0][0].tokens   , Mux(4)([acc_leaf[0][1].tokens   , token_unit[0].oriRoot[0], token_unit[0].oriRoot[0], token_unit[0].oriRoot[0]], token_unit_switch));
    ImplyEq()(enabled, token_unit[0].newRoot[0], Mux(4)([token_unit[0].newRoot[0], token_unit[0].newRoot[0], token_unit[1].oriRoot[0], token_unit[0].newRoot[0]], token_unit_switch));
    ImplyEq()(enabled, acc_leaf[0][1].tokens   , Mux(4)([acc_leaf[0][0].tokens   , token_unit[0].newRoot[0], token_unit[1].newRoot[0], token_unit[0].newRoot[0]], token_unit_switch));
    ImplyEq()(enabled, acc_leaf[1][0].tokens   , Mux(4)([acc_leaf[1][0].tokens   , acc_leaf[1][0].tokens   , acc_leaf[1][0].tokens   , token_unit[1].oriRoot[0]], token_unit_switch));
    ImplyEq()(enabled, acc_leaf[1][1].tokens   , Mux(4)([acc_leaf[1][1].tokens   , acc_leaf[1][1].tokens   , acc_leaf[1][1].tokens   , token_unit[1].newRoot[0]], token_unit_switch));

    ImplyEq()(enabled * (1 - epoch_switch), ori_state.epoch[0], new_state.epoch[0]);
    ImplyEq()(enabled * (1 - epoch_switch), ori_state.epoch[1], new_state.epoch[1]);

    ImplyEq()(enabled * (1 - admin_ts_addr_swtich), ori_state.adminTsAddr, new_state.adminTsAddr);

    ImplyEq()(enabled, ori_state.txCount + 1, new_state.txCount);

    signal output epoch[2][2] <== [[ori_state.epoch[0], new_state.epoch[0]], [ori_state.epoch[1], new_state.epoch[1]]];
    signal output nullifierRoot[2][2] <== [[ori_state.nullifierRoot[0], new_state.nullifierRoot[0]], [ori_state.nullifierRoot[1], new_state.nullifierRoot[1]]];
    signal output adminTsAddr[2] <== [ori_state.adminTsAddr, new_state.adminTsAddr];
    signal output txId <== ori_state.txCount;
    signal output feeLeafId[1] <== [fee_unit.leafId[0]];
    signal output feeLeaf[1][2][LenOfFeeLeaf()] <== [[fee_unit.oriLeaf, fee_unit.newLeaf]];
    signal output bondLeafId[1] <== [bond_unit.leafId[0]];
    signal output bondLeaf[1][2][LenOfBondLeaf()] <== [[bond_unit.oriLeaf, bond_unit.newLeaf]];
    signal output orderLeafId[1] <== [order_unit.leafId[0]];
    signal output orderLeaf[1][2][LenOfOrderLeaf()] <== [[order_unit.oriLeaf, order_unit.newLeaf]];
    signal output accLeafId[2] <== [acc_unit[0].leafId[0], acc_unit[1].leafId[0]];
    signal output accLeaf[2][2][LenOfAccLeaf()] <== [[acc_leaf[0][0].arr, acc_leaf[0][1].arr], [acc_leaf[1][0].arr, acc_leaf[1][1].arr]];
    signal output tokenLeafId[2] <== [token_unit[0].leafId[0], token_unit[1].leafId[0]];
    signal output tokenLeaf[2][2][LenOfTokenLeaf()] <== [[token_unit[0].oriLeaf, token_unit[0].newLeaf], [token_unit[1].oriLeaf, token_unit[1].newLeaf]];
    signal output nullifierLeafId[1] <== [nullifier_unit.leafId[0]];
    signal output nullifierLeaf[1][2][LenOfNullifierLeaf()] <== [[nullifier_unit.oriLeaf, nullifier_unit.newLeaf]];
}
template Chunkify(arg_count, bits_args){
    signal input {bool} enabled;
    signal input chunks[MaxChunksPerReq()];
    signal input args[arg_count];
    signal tmpChunks[MaxChunksPerReq()];
    signal bits[MaxChunksPerReq()][BitsChunk()];
    var counter = 0;
    component n2B[arg_count];
    for(var i = 0; i < arg_count; i++){
        n2B[i] = Num2Bits(bits_args[i]);
        n2B[i].in <== args[i];
        for(var j = 0; j < bits_args[i]; j++)
            bits[(counter + j) \ BitsChunk()][BitsChunk() - 1 - ((counter + j) % BitsChunk())] <== n2B[i].out[bits_args[i] - j - 1];
        counter = counter + bits_args[i];
    }
    for(var i = counter ; i < MaxChunksPerReq() * BitsChunk(); i++)
        bits[i \ BitsChunk()][BitsChunk() - 1 - (i % BitsChunk())] <== 0;
    for(var i = 0; i < MaxChunksPerReq(); i++)
        tmpChunks[i] <== Bits2Num(BitsChunk())(bits[i]);
    ImplyEqArr(MaxChunksPerReq())(enabled, tmpChunks, chunks);
}
template DoReqNoop(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(0, 0, 0, 0, 0, 0, 0, 0);
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);

    Chunkify(1, [FmtOpcode()])(enabled, p_req.chunks, [req.opType]);

    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}
template DoReqRegister(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(0, 0, 0, 1, 0, 0, 0, 0);// Update acc leaf once
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);

    /* legality */
    AccLeaf_EnforceDefault()(conn.accLeaf[0][0], enabled);

    /* correctness */
    ImplyEq()(enabled, conn.accLeafId[0], req.arg[0]/*receiver id*/);
    ImplyEqArr(LenOfAccLeaf())(enabled, AccLeaf_Register()(conn.accLeaf[0][0], req.arg[6]/*ts-addr*/), conn.accLeaf[0][1]);

    Chunkify(3, [FmtOpcode(), FmtAccId(), FmtHashedPubKey()])(enabled, p_req.chunks, [req.opType, conn.accLeafId[0], req.arg[6]/*ts-addr*/]);

    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}
template DoReqDeposit(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(0, 0, 0, 1, 0, 1, 0, 0);// Update acc leaf once and token leaf once
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);

    /* correctness */
    ImplyEq()(enabled, conn.accLeafId[0], req.arg[0]/*receiver id*/);
    ImplyEq()(enabled, conn.tokenLeafId[0], req.tokenId);
    ImplyEqArr(LenOfAccLeaf())(enabled, AccLeaf_MaskTokens()(conn.accLeaf[0][0]), AccLeaf_MaskTokens()(conn.accLeaf[0][1]));
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Incoming()(conn.tokenLeaf[0][0], enabled, req.amount), conn.tokenLeaf[0][1]);

    Chunkify(4, [FmtOpcode(), FmtAccId(), FmtTokenId(), FmtStateAmount()])(enabled, p_req.chunks, [req.opType, conn.accLeafId[0], req.tokenId, req.amount]);

    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}
template DoReqTransfer(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(0, 0, 0, 2, 0, 3, 0, 0);// Update acc leaf twice and token leaf thrice
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);

    /* legality */
    AccLeaf_NonceCheck()(conn.accLeaf[0][0], enabled, req.nonce);
    TokenLeaf_SufficientCheck()(conn.tokenLeaf[0][0], enabled, req.amount);

    /* correctness */
    ImplyEq()(enabled, conn.accLeafId[0], req.accId);
    ImplyEq()(enabled, conn.accLeafId[1], req.arg[0]/*receiver id*/);
    ImplyEq()(enabled, conn.tokenLeafId[0], req.tokenId);
    ImplyEq()(enabled, conn.tokenLeafId[1], req.tokenId);
    ImplyEqArr(LenOfAccLeaf())(enabled, AccLeaf_NonceIncrease()(AccLeaf_MaskTokens()(conn.accLeaf[0][0])), AccLeaf_MaskTokens()(conn.accLeaf[0][1]));
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Outgoing()(conn.tokenLeaf[0][0], enabled, req.amount), conn.tokenLeaf[0][1]);

    ImplyEqArr(LenOfAccLeaf())(enabled, AccLeaf_MaskTokens()(conn.accLeaf[1][0]), AccLeaf_MaskTokens()(conn.accLeaf[1][1]));
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Incoming()(conn.tokenLeaf[1][0], enabled, req.amount), conn.tokenLeaf[1][1]);

    signal packedAmt <== Fix2FloatCond()(enabled, req.amount);
    Chunkify(5, [FmtOpcode(), FmtAccId(), FmtTokenId(), FmtPacked(), FmtAccId()])(enabled, p_req.chunks, [req.opType, req.accId, req.tokenId, packedAmt, req.arg[0]/*receiver id*/]);

    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}
template DoReqWithdraw(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(0, 0, 0, 1, 0, 1, 0, 0);// Update acc leaf once and token leaf once
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);

    /* legality */
    AccLeaf_NonceCheck()(conn.accLeaf[0][0], enabled, req.nonce);
    TokenLeaf_SufficientCheck()(conn.tokenLeaf[0][0], enabled, req.amount);

    /* correctness */
    ImplyEq()(enabled, conn.accLeafId[0], req.accId);
    ImplyEq()(enabled, conn.tokenLeafId[0], req.tokenId);
    ImplyEqArr(LenOfAccLeaf())(enabled, AccLeaf_NonceIncrease()(AccLeaf_MaskTokens()(conn.accLeaf[0][0])), AccLeaf_MaskTokens()(conn.accLeaf[0][1]));
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Outgoing()(conn.tokenLeaf[0][0], enabled, req.amount), conn.tokenLeaf[0][1]);

    Chunkify(4, [FmtOpcode(), FmtAccId(), FmtTokenId(), FmtStateAmount()])(enabled, p_req.chunks, [req.opType, conn.accLeafId[0], req.tokenId, req.amount]);

    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}
template DoReqForcedWithdraw(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(0, 0, 0, 1, 0, 1, 0, 0);// Update acc leaf once and token leaf once
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);
    component token = TokenLeaf();
    token.arr <== conn.tokenLeaf[0][0];

    /* correctness */
    ImplyEq()(enabled, conn.accLeafId[0], req.arg[0]/*receiver id*/);
    ImplyEq()(enabled, conn.tokenLeafId[0], req.tokenId);
    ImplyEqArr(LenOfAccLeaf())(enabled, AccLeaf_MaskTokens()(conn.accLeaf[0][0]), AccLeaf_MaskTokens()(conn.accLeaf[0][1]));
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Outgoing()(conn.tokenLeaf[0][0], enabled, token.avl_amt), conn.tokenLeaf[0][1]);

    Chunkify(4, [FmtOpcode(), FmtAccId(), FmtTokenId(), FmtStateAmount()])(enabled, p_req.chunks, [req.opType, conn.accLeafId[0], conn.tokenLeafId[0], token.avl_amt]);

    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}
template DoReqPlaceOrder(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(0, 1, 1, 1, 1, 1, 0, 0);
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);
    component bond = BondLeaf();
    bond.arr <== conn.bondLeaf[0][0];


    signal digest <== Req_Digest()(p_req.req);
    
    /* calc lock amt */
    signal isLend <== TagIsEqual()([req.opType, OpTypeNumAuctionLend()]);
    signal isBorrow <== TagIsEqual()([req.opType, OpTypeNumAuctionBorrow()]);
    signal isAuc <== Or()(isLend, isBorrow);
    signal is2nd <== TagIsEqual()([req.opType, OpTypeNumSecondLimitOrder()]);
    signal is2ndBuy <== And()(is2nd, Not()(Bool()(req.arg[8]/*side*/)));
    signal is2ndSell <== And()(is2nd, Bool()(req.arg[8]/*side*/));

    signal daysFromMatched <== DaysFrom()(p_req.matchedTime[0], bond.maturity);
    signal daysFromExpired <== Req_DaysFromExpired()(p_req.req, bond.maturity);
    signal isNegInterestIf2ndBuy <== And()(is2ndBuy, TagLessThan(BitsAmount())([req.arg[5]/*target amout*/, req.amount]));

    signal lockFeeAmtIfLend <== AuctionCalcFee()(req.fee0, req.amount, req.arg[9]/*default interest*/, daysFromMatched);
    var lockAmtIfLend = req.amount + lockFeeAmtIfLend;
    signal expectedSellAmtIf2ndBuy <== CalcNewBQ()(enabled, req.arg[5]/*target amout*/, req.amount, req.arg[5]/*target amout*/, req.amount, daysFromExpired);
    signal lockFeeIf2ndBuy <== SecondCalcFee()(req.arg[5]/*target amout*/, Max(BitsRatio())([req.fee0, req.fee1]), Mux(2)([daysFromExpired, daysFromMatched], isNegInterestIf2ndBuy));
    signal lockAmtIf2ndBuy <== expectedSellAmtIf2ndBuy + lockFeeIf2ndBuy;
    signal lock_amt <== Mux(4)([lockAmtIfLend, req.amount, lockAmtIf2ndBuy, req.amount], isLend * 0 + isBorrow * 1 + is2ndBuy * 2 + is2ndSell * 3);
    _ <== Num2Bits(BitsUnsignedAmt())(lock_amt);

    /* legality */
    TokenLeaf_SufficientCheck()(conn.tokenLeaf[0][0], enabled, lock_amt);
    Req_CheckExpiration()(p_req.req, enabled, p_req.matchedTime[0]);
    ImplyEq()(enabled, req.arg[7]/*epoch*/, Mux(2)([conn.epoch[0][0], conn.epoch[1][0]], p_req.nullifierTreeId[0]));
    NullifierLeaf_CheckCollision()(conn.nullifierLeaf[0][0], enabled, digest);
    ImplyEq()(enabled, 0, Mux(LenOfNullifierLeaf())(conn.nullifierLeaf[0][0], p_req.nullifierElemId[0]));
    ImplyEq()(enabled, 1, TagLessEqThan(BitsTime())([p_req.matchedTime[0], currentTime]));
    ImplyEq()(enabled, 1, TagLessThan(BitsTime())([currentTime - p_req.matchedTime[0], ConstSecondsPerDay()]));
    ImplyEq()(isAuc, 1, TagLessEqThan(BitsTime())([req.arg[2] + 86400, bond.maturity]));
    ImplyEq()(is2nd, 1, TagLessEqThan(BitsTime())([req.arg[2], bond.maturity]));

    /* correctness */
    ImplyEq()(enabled, conn.accLeafId[0], req.accId);
    ImplyEq()(enabled, conn.tokenLeafId[0], req.tokenId);
    ImplyEq()(enabled, conn.nullifierLeafId[0], Digest2NulliferLeafId()(digest));
    ImplyEq()(isLend, bond.baseTokenId, req.tokenId);
    ImplyEq()(isBorrow, bond.baseTokenId, req.arg[4]);
    ImplyEq()(isAuc, bond.maturity, req.arg[1]);
    ImplyEq()(is2nd, conn.bondLeafId[0], Mux(2)([req.arg[4], req.tokenId], req.arg[8]));
    ImplyEqArr(LenOfAccLeaf())(enabled, AccLeaf_MaskTokens()(conn.accLeaf[0][0]), AccLeaf_MaskTokens()(conn.accLeaf[0][1]));
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Lock()(conn.tokenLeaf[0][0], enabled, lock_amt), conn.tokenLeaf[0][1]);
    ImplyEqArr(LenOfNullifierLeaf())(enabled, NullifierLeaf_Place()(conn.nullifierLeaf[0][0], digest, p_req.nullifierElemId[0]), conn.nullifierLeaf[0][1]);
    ImplyEqArr(LenOfOrderLeaf())(enabled, OrderLeaf_Place()(p_req.req, 0, 0, conn.txId, lock_amt), conn.orderLeaf[0][1]);

    signal packedAmount0 <== Fix2FloatCond()(enabled, req.amount);
    signal packedAmount1 <== Fix2FloatCond()(enabled, req.arg[5]/*target amout*/);
    signal packedFee0 <== Fix2FloatCond()(enabled, req.fee0);
    signal packedFee1 <== Fix2FloatCond()(enabled, req.fee1);

    Chunkify(7, [FmtOpcode(), FmtAccId(), FmtTokenId(), FmtPacked(), FmtPacked(), FmtTime(), FmtTime()])(And()(enabled, isLend), p_req.chunks, [req.opType, req.accId, req.tokenId, packedAmount0, packedFee0, req.arg[1]/*maturity time*/, p_req.matchedTime[0]]);
    Chunkify(7, [FmtOpcode(), FmtAccId(), FmtTokenId(), FmtPacked(), FmtPacked(), FmtPacked(), FmtTime()])(And()(enabled, isBorrow), p_req.chunks, [req.opType, req.accId, req.tokenId, packedAmount0, packedFee0, packedAmount1, p_req.matchedTime[0]]);
    Chunkify(10, [FmtOpcode(), FmtAccId(), FmtTokenId(), FmtPacked(), FmtPacked(), FmtPacked(), FmtTokenId(), FmtPacked(), FmtTime(), FmtTime()])(And()(enabled, is2nd), p_req.chunks, [req.opType, req.accId, req.tokenId, packedAmount0, packedFee0, packedFee1, req.arg[4]/*target token id*/, packedAmount1, req.arg[2]/*expired time*/, p_req.matchedTime[0]]);

    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}
template DoReqStart(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(0, 0, 1, 0, 0, 0, 0, 0);// Update order leaf once
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);
    component order = OrderLeaf();
    order.arr <== conn.orderLeaf[0][0];
    component order_req = Req();
    order_req.arr <== order.req;

    signal isAuctionStart <== TagIsEqual()([req.opType, OpTypeNumAuctionStart()]);

    /* legality */
    ImplyEq()(enabled, order_req.opType, Mux(2)([OpTypeNumSecondLimitOrder(), OpTypeNumAuctionBorrow()], isAuctionStart));
    Req_CheckExpiration()(order.req, enabled, p_req.matchedTime[0]);

    /* correctness */
    ImplyEqArr(LenOfOrderLeaf())(enabled, OrderLeaf_Default()(), conn.orderLeaf[0][1]);

    signal packedInterest <== Fix2FloatCond()(enabled, req.arg[3]/*matched interest*/);
    Chunkify(3, [FmtOpcode(), FmtTxOffset(), FmtPacked()])(And()(enabled, isAuctionStart), p_req.chunks, [req.opType, conn.txId - order.txId, packedInterest]);
    Chunkify(2, [FmtOpcode(), FmtTxOffset()])(And()(enabled, Not()(isAuctionStart)), p_req.chunks, [req.opType, conn.txId - order.txId]);

    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    channelOut <== Channel_New()(conn.orderLeaf[0][0], [order.cumAmt0, order.cumAmt1, req.arg[3]/*matched interest*/ * isAuctionStart, 0, 0]);
}
template DoReqInteract(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(1, 1, 1, 1, 0, 2, 0, 0);// Update fee leaf, bond leaf, order leaf, acc leaf once and token leaf twice
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);
    component bond = BondLeaf();
    bond.arr <== conn.bondLeaf[0][0];
    component ori_order1 = OrderLeaf();
    ori_order1.arr <== conn.orderLeaf[0][0];
    component ori_order1_req = Req();
    ori_order1_req.arr <== ori_order1.req;
    component channel_in = Channel();
    channel_in.arr <== channelIn;
    component ori_order0 = OrderLeaf();
    ori_order0.arr <== channel_in.orderLeaf;
    component ori_order0_req = Req();
    ori_order0_req.arr <== ori_order0.req;

    signal isAuction <== TagIsEqual()([req.opType, OpTypeNumAuctionMatch()]);
    signal isSecondaryLimit <== TagIsEqual()([req.opType, OpTypeNumSecondLimitExchange()]);
    signal isSecondaryMarket <== TagIsEqual()([req.opType, OpTypeNumSecondMarketExchange()]);
    
    signal days <== DaysFrom()(p_req.matchedTime[0], bond.maturity);
    signal newLend[LenOfOrderLeaf()], newBorrow[LenOfOrderLeaf()], isMatchedIfAuction;
    var matchedInterest = channel_in.args[2];
    (newLend, newBorrow, isMatchedIfAuction) <== AuctionInteract()(ori_order1.arr, ori_order0.arr, Mux(2)([1, matchedInterest], isAuction), days);
    signal newTaker[LenOfOrderLeaf()], newMaker[LenOfOrderLeaf()], isMatchedIfSecondary;
    (newTaker, newMaker, isMatchedIfSecondary) <== SecondaryInteract()(ori_order0.arr, ori_order1.arr, days);

    component new_order0 = OrderLeaf();
    new_order0.arr <== Multiplexer(LenOfOrderLeaf(), 2)([newTaker, newBorrow], TagIsEqual()([req.opType, OpTypeNumAuctionMatch()]));
    component new_order1 = OrderLeaf();
    new_order1.arr <== Multiplexer(LenOfOrderLeaf(), 2)([newMaker, newLend], TagIsEqual()([req.opType, OpTypeNumAuctionMatch()]));

    var matched_amt0 = new_order1.cumAmt0 - ori_order1.cumAmt0;
    var matched_amt1 = new_order1.cumAmt1 - ori_order1.cumAmt1;
    signal feeFromLocked, feeFromTarget, fee;
    (feeFromLocked, feeFromTarget, fee) <== CalcFee()(new_order1.arr, enabled, ori_order1.cumAmt0, ori_order1.cumAmt1, p_req.matchedTime[0], bond.maturity, Mux(2)([1, ori_order0_req.arg[9]/*default interest*/], isAuction));
    
    signal enabledAndIsAuction <== And()(enabled, isAuction);
    signal enabledAndIsSecondaryLimit <== And()(enabled, isSecondaryLimit);
    signal enabledAndIsSecondaryMarket <== And()(enabled, isSecondaryMarket);

    /* legality */
    Req_CheckExpiration()(ori_order1.req, enabled, p_req.matchedTime[0]);
    ImplyEq()(enabledAndIsAuction, ori_order0_req.opType, OpTypeNumAuctionBorrow());
    ImplyEq()(enabledAndIsAuction, ori_order1_req.opType, OpTypeNumAuctionLend());
    ImplyEq()(enabledAndIsAuction, 1, TagGreaterEqThan(BitsRatio())([ori_order1_req.arg[3]/*interest*/, channel_in.args[3]]));
    ImplyEq()(enabledAndIsSecondaryLimit, ori_order0_req.opType, OpTypeNumSecondLimitOrder());
    ImplyEq()(enabledAndIsSecondaryLimit, ori_order1_req.opType, OpTypeNumSecondLimitOrder());
    ImplyEq()(enabledAndIsSecondaryMarket, ori_order0_req.opType, OpTypeNumSecondMarketOrder());
    ImplyEq()(enabledAndIsSecondaryMarket, ori_order1_req.opType, OpTypeNumSecondLimitOrder());
    ImplyEq()(enabled, 1, Mux(2)([isMatchedIfSecondary, isMatchedIfAuction], TagIsEqual()([req.opType, OpTypeNumAuctionMatch()])));
    ImplyEq()(enabled, 1, TagLessEqThan(BitsAmount())([feeFromTarget, matched_amt1]));
    ImplyEq()(enabled, 1, TagLessThan(BitsTime())([currentTime - p_req.matchedTime[0], ConstSecondsPerDay()]));

    /* correctness */
    ImplyEq()(enabled, conn.accLeafId[0], ori_order1_req.accId);
    ImplyEq()(enabledAndIsAuction, conn.feeLeafId[0], ori_order1_req.tokenId);
    ImplyEq()(And()(enabled, Or()(isSecondaryLimit, isSecondaryMarket)), conn.feeLeafId[0], Mux(2)([ori_order1_req.tokenId, ori_order1_req.arg[4]/*target token id*/], ori_order1_req.arg[8]/*side*/));
    ImplyEq()(enabledAndIsAuction, bond.baseTokenId, ori_order1_req.tokenId);
    ImplyEq()(enabledAndIsAuction, bond.maturity, ori_order1_req.arg[1]/*maturity time*/);
    ImplyEq()(And()(enabled, Or()(isSecondaryLimit, isSecondaryMarket)), conn.bondLeafId[0], Mux(2)([ori_order1_req.arg[4]/*target token id*/, ori_order1_req.tokenId], ori_order1_req.arg[8]/*side*/));
    ImplyEq()(enabledAndIsAuction, conn.tokenLeafId[0], conn.bondLeafId[0]);
    ImplyEq()(And()(enabled, Or()(isSecondaryLimit, isSecondaryMarket)), conn.tokenLeafId[0], ori_order1_req.arg[4]/*target token id*/);
    ImplyEq()(enabled, conn.tokenLeafId[1], ori_order1_req.tokenId);
    
    signal newNewOrder1[LenOfOrderLeaf()] <== OrderLeaf_DeductLockedAmt()(new_order1.arr, enabled, feeFromLocked + matched_amt0);
    signal isFull <== OrderLeaf_IsFull()(newNewOrder1);
    component new_new_order1 = OrderLeaf();
    new_new_order1.arr <== newNewOrder1;
    signal refund <== isFull * new_new_order1.lockedAmt;

    ImplyEqArr(LenOfOrderLeaf())(enabled, OrderLeaf_DefaultIf()(newNewOrder1, isFull), conn.orderLeaf[0][1]);
    ImplyEqArr(LenOfBondLeaf())(enabled, conn.bondLeaf[0][0], conn.bondLeaf[0][1]);
    ImplyEqArr(LenOfAccLeaf())(enabled, AccLeaf_MaskTokens()(conn.accLeaf[0][0]), AccLeaf_MaskTokens()(conn.accLeaf[0][1]));
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Incoming()(conn.tokenLeaf[0][0], enabled, matched_amt1 - feeFromTarget), conn.tokenLeaf[0][1]);
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Unlock()(TokenLeaf_Deduct()(conn.tokenLeaf[1][0], enabled, matched_amt0 + feeFromLocked), enabled, refund), conn.tokenLeaf[1][1]);
    ImplyEqArr(LenOfFeeLeaf())(enabled, FeeLeaf_Incoming()(conn.feeLeaf[0][0], enabled, fee), conn.feeLeaf[0][1]);

    signal packedAmt1 <== Fix2FloatCond()(enabled, ori_order1_req.arg[5]/*target amout*/);
    Chunkify(2, [FmtOpcode(), FmtTxOffset()])(enabledAndIsAuction, p_req.chunks, [req.opType, conn.txId - ori_order1.txId]);
    Chunkify(3, [FmtOpcode(), FmtTxOffset(), FmtPacked()])(And()(enabled, Or()(isSecondaryLimit, isSecondaryMarket)), p_req.chunks, [req.opType, conn.txId - ori_order1.txId, packedAmt1]);

    signal channelOutIfAuction[LenOfChannel()] <== Channel_New()(newBorrow, [channel_in.args[0], channel_in.args[1], channel_in.args[2], ori_order1_req.arg[3]/*interest*/, 0]);
    signal channelOutIfSecondary[LenOfChannel()] <== Channel_New()(newTaker, [channel_in.args[0], channel_in.args[1], channel_in.args[2], 0, 0]);
    channelOut <== Multiplexer(LenOfChannel(), 2)([channelOutIfSecondary, channelOutIfAuction], isAuction);
}
template DoReqEnd(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(1, 1, 1, 1, 0, 2, 0, 0);// Update fee leaf, bond leaf, order leaf, acc leaf once and token leaf twice
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);
    component bond = BondLeaf();
    bond.arr <== conn.bondLeaf[0][0];
    component channel_in = Channel();
    channel_in.arr <== channelIn;
    component order = OrderLeaf();
    order.arr <== channel_in.orderLeaf;
    component order_req = Req();
    order_req.arr <== order.req;
    
    signal isAuction <== TagIsEqual()([req.opType, OpTypeNumAuctionEnd()]);
    signal isSecondaryLimit <== TagIsEqual()([req.opType, OpTypeNumSecondLimitEnd()]);
    signal isSecondaryMarket <== TagIsEqual()([req.opType, OpTypeNumSecondMarketEnd()]);
    signal feeFromLocked, feeFromTarget, fee;
    (feeFromLocked, feeFromTarget, fee) <== CalcFee()(order.arr, enabled, channel_in.args[0], channel_in.args[1], p_req.matchedTime[0], bond.maturity,  Mux(2)([0, channel_in.args[2]], isAuction));
    
    var matched_amt0 = order.cumAmt0 - channel_in.args[0];
    var matched_amt1 = order.cumAmt1 - channel_in.args[1];

    signal enabledAndIsAuction <== And()(enabled, isAuction);

    /* legality */
    ImplyEq()(enabledAndIsAuction, order_req.opType, OpTypeNumAuctionBorrow());
    ImplyEq()(And()(enabled, isSecondaryLimit), order_req.opType, OpTypeNumSecondLimitOrder());
    ImplyEq()(enabledAndIsAuction, channel_in.args[2], channel_in.args[3]);
    ImplyEqArr(LenOfOrderLeaf())(enabled, OrderLeaf_Default()(), conn.orderLeaf[0][0]);
    ImplyEq()(enabled, 1, TagLessEqThan(BitsAmount())([feeFromTarget, matched_amt1]));
    ImplyEq()(enabled, 1, TagLessThan(BitsTime())([currentTime - p_req.matchedTime[0], ConstSecondsPerDay()]));

    /* correctness */
    ImplyEq()(enabled, conn.accLeafId[0], order_req.accId);
    ImplyEq()(enabledAndIsAuction, conn.feeLeafId[0], order_req.arg[4]/*target token id*/);
    ImplyEq()(And()(enabled, isSecondaryLimit), conn.feeLeafId[0], Mux(2)([order_req.tokenId, order_req.arg[4]/*target token id*/], order_req.arg[8]/*side*/));
    ImplyEq()(enabledAndIsAuction, bond.baseTokenId, order_req.arg[4]/*target token id*/);
    ImplyEq()(enabledAndIsAuction, bond.maturity, order_req.arg[1]/*maturity time*/);
    ImplyEq()(And()(enabled, isSecondaryLimit), conn.bondLeafId[0], Mux(2)([order_req.arg[4]/*target token id*/, order_req.tokenId], order_req.arg[8]/*side*/));
    ImplyEq()(enabled, conn.tokenLeafId[0], order_req.arg[4]/*target token id*/);
    ImplyEq()(enabled, conn.tokenLeafId[1], order_req.tokenId);

    signal newOrder[LenOfOrderLeaf()] <== OrderLeaf_DeductLockedAmt()(order.arr, enabled, feeFromLocked + matched_amt0);
    signal isFull <== OrderLeaf_IsFull()(newOrder);
    component new_order = OrderLeaf();
    new_order.arr <== newOrder;
    signal refund <== isFull * new_order.lockedAmt;
    ImplyEqArr(LenOfOrderLeaf())(enabled, OrderLeaf_DefaultIf()(newOrder, isFull), conn.orderLeaf[0][1]);
    ImplyEqArr(LenOfBondLeaf())(enabled, conn.bondLeaf[0][0], conn.bondLeaf[0][1]);
    ImplyEqArr(LenOfAccLeaf())(enabled, AccLeaf_MaskTokens()(conn.accLeaf[0][0]), AccLeaf_MaskTokens()(conn.accLeaf[0][1]));
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Incoming()(conn.tokenLeaf[0][0], enabled, matched_amt1 - feeFromTarget), conn.tokenLeaf[0][1]);
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Unlock()(TokenLeaf_Deduct()(conn.tokenLeaf[1][0], enabled, matched_amt0 + feeFromLocked), enabled, refund), conn.tokenLeaf[1][1]);
    ImplyEqArr(LenOfFeeLeaf())(enabled, FeeLeaf_Incoming()(conn.feeLeaf[0][0], enabled, fee), conn.feeLeaf[0][1]);

    signal debtAmtIfAuction <== AuctionCalcDebtAmt()(channel_in.args[2], matched_amt1, DaysFrom()(p_req.matchedTime[0], bond.maturity));
    Chunkify(7, [FmtOpcode(), FmtAccId(), FmtTokenId(), FmtStateAmount(), FmtTokenId(), FmtStateAmount(), FmtTime()])(enabledAndIsAuction, p_req.chunks, [req.opType, order_req.accId, order_req.tokenId, matched_amt0, conn.bondLeafId[0], debtAmtIfAuction, p_req.matchedTime[0]]);
    Chunkify(2, [FmtOpcode(), FmtTime()])(And()(enabled, isSecondaryLimit), p_req.chunks, [req.opType, p_req.matchedTime[0]]);

    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}
template DoReqSecondMarketOrder(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(0, 0, 0, 1, 1, 0, 0, 0);// Update acc leaf and nullifier leaf once
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);
    
    signal digest <== Req_Digest()(p_req.req);
    
    /* legality */
    Req_CheckExpiration()(req.arr, enabled, p_req.matchedTime[0]);
    ImplyEq()(enabled, req.arg[7]/*epoch*/, Mux(2)([conn.epoch[0][0], conn.epoch[1][0]], p_req.nullifierTreeId[0]));
    NullifierLeaf_CheckCollision()(conn.nullifierLeaf[0][0], enabled, digest);
    ImplyEq()(enabled, 0, Mux(LenOfNullifierLeaf())(conn.nullifierLeaf[0][0], p_req.nullifierElemId[0]));

    /* correctness */
    ImplyEq()(enabled, conn.accLeafId[0], req.accId);
    ImplyEq()(enabled, conn.nullifierLeafId[0], Digest2NulliferLeafId()(digest));
    ImplyEqArr(LenOfAccLeaf())(enabled, conn.accLeaf[0][0], conn.accLeaf[0][1]);
    ImplyEqArr(LenOfNullifierLeaf())(enabled, NullifierLeaf_Place()(conn.nullifierLeaf[0][0], digest, p_req.nullifierElemId[0]), conn.nullifierLeaf[0][1]);
    
    signal packedAmount0 <== Fix2FloatCond()(enabled, req.amount);
    signal packedAmount1 <== Fix2FloatCond()(enabled, req.arg[5]/*target amout*/);
    signal packedFee0 <== Fix2FloatCond()(enabled, req.fee0);
    Chunkify(8, [FmtOpcode(), FmtAccId(), FmtTokenId(), FmtPacked(), FmtPacked(), FmtTokenId(), FmtPacked(), FmtTime()])(enabled, p_req.chunks, [req.opType, req.accId, req.tokenId, packedAmount0, packedFee0, req.arg[4]/*target token id*/, packedAmount1, req.arg[2]/*expired time*/]);

    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    channelOut <== Channel_New()(OrderLeaf_Place()(p_req.req, 0, 0, conn.txId, 0), [0, 0, 0, 0, 0]);
}
template DoReqSecondMarketEnd(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(1, 1, 0, 1, 0, 2, 0, 0);// Update fee leaf, bond leaf, acc leaf once and token leaf twice
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);
    component bond = BondLeaf();
    bond.arr <== conn.bondLeaf[0][0];
    component channel_in = Channel();
    channel_in.arr <== channelIn;
    component order = OrderLeaf();
    order.arr <== channel_in.orderLeaf;
    component order_req = Req();
    order_req.arr <== order.req;
    
    signal feeFromLocked, feeFromTarget, fee;
    (feeFromLocked, feeFromTarget, fee) <== CalcFee()(order.arr, enabled, channel_in.args[0], channel_in.args[1], p_req.matchedTime[0], bond.maturity, channel_in.args[2]);
    
    var matched_amt0 = order.cumAmt0 - channel_in.args[0];
    var matched_amt1 = order.cumAmt1 - channel_in.args[1];

    /* legality */
    ImplyEq()(enabled, order_req.opType, OpTypeNumSecondMarketOrder());
    ImplyEq()(enabled, 1, TagLessEqThan(BitsAmount())([feeFromTarget, matched_amt1]));
    TokenLeaf_SufficientCheck()(conn.tokenLeaf[1][0], enabled, matched_amt0 + feeFromLocked);
    ImplyEq()(enabled, 1, TagLessThan(BitsTime())([currentTime - p_req.matchedTime[0], ConstSecondsPerDay()]));

    /* correctness */
    ImplyEq()(enabled, conn.accLeafId[0], order_req.accId);
    ImplyEq()(enabled, conn.feeLeafId[0], Mux(2)([order_req.tokenId, order_req.arg[4]/*target token id*/], order_req.arg[8]/*side*/));
    ImplyEq()(enabled, conn.bondLeafId[0], Mux(2)([order_req.arg[4]/*target token id*/, order_req.tokenId], order_req.arg[8]/*side*/));
    ImplyEq()(enabled, conn.tokenLeafId[0], order_req.arg[4]/*target token id*/);
    ImplyEq()(enabled, conn.tokenLeafId[1], order_req.tokenId);

    ImplyEqArr(LenOfBondLeaf())(enabled, conn.bondLeaf[0][0], conn.bondLeaf[0][1]);
    ImplyEqArr(LenOfAccLeaf())(enabled, AccLeaf_MaskTokens()(conn.accLeaf[0][0]), AccLeaf_MaskTokens()(conn.accLeaf[0][1]));
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Incoming()(conn.tokenLeaf[0][0], enabled, matched_amt1 - feeFromTarget), conn.tokenLeaf[0][1]);
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Outgoing()(conn.tokenLeaf[1][0], enabled, matched_amt0 + feeFromLocked), conn.tokenLeaf[1][1]);
    ImplyEqArr(LenOfFeeLeaf())(enabled, FeeLeaf_Incoming()(conn.feeLeaf[0][0], enabled, fee), conn.feeLeaf[0][1]);

    Chunkify(2, [FmtOpcode(), FmtTime()])(enabled, p_req.chunks, [req.opType, p_req.matchedTime[0]]);

    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}
template DoReqCancel(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(0, 0, 1, 1, 0, 1, 0, 0);// Update order leaf, acc leaf once and token leaf once
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);
    component order = OrderLeaf();
    order.arr <== conn.orderLeaf[0][0];
    component o_req = Req();
    o_req.arr <== order.req;

    /* legality */
    ImplyEq()(And()(enabled, TagIsEqual()([req.opType, OpTypeNumUserCancelOrder()])), req.accId, o_req.accId);

    /* correctness */
    ImplyEq()(enabled, conn.accLeafId[0], o_req.accId);
    ImplyEq()(enabled, conn.tokenLeafId[0], o_req.tokenId);
    ImplyEq()(And()(enabled, TagIsEqual()([req.opType, OpTypeNumUserCancelOrder()])), order.txId, req.arg[1]/*order tx-id*/);
    ImplyEqArr(LenOfAccLeaf())(enabled, AccLeaf_MaskTokens()(conn.accLeaf[0][0]), AccLeaf_MaskTokens()(conn.accLeaf[0][1]));
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Unlock()(conn.tokenLeaf[0][0], enabled, order.lockedAmt), conn.tokenLeaf[0][1]);
    ImplyEqArr(LenOfOrderLeaf())(enabled, OrderLeaf_Default()(), conn.orderLeaf[0][1]);

    Chunkify(2, [FmtOpcode(), FmtTxId()])(enabled, p_req.chunks, [req.opType, order.txId]);

    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}
template DoReqSetAdminTsAddr(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(0, 0, 0, 0, 0, 0, 0, 1);// Update admin_ts_addr once
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);

    /* correctness */
    ImplyEq()(enabled, conn.adminTsAddr[1], req.arg[6]/*ts-addr*/);

    Chunkify(1, [FmtOpcode()])(enabled, p_req.chunks, [req.opType]);

    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}
template DoReqIncreaseEpoch(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(0, 0, 0, 0, 0, 0, 1, 0);// Update epoch once
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);

    /* correctness */
    signal treeId <== TagIsEqual()([conn.epoch[1][0] - conn.epoch[0][0], 1]);
    ImplyEq()(enabled, conn.epoch[0][0] + 2 * treeId, conn.epoch[0][1]);
    ImplyEq()(enabled, conn.epoch[1][0] + 2 * (1 - treeId), conn.epoch[1][1]);
    ImplyEq()(enabled * treeId, conn.nullifierRoot[0][1], DefaultNullifierRoot());
    ImplyEq()(enabled * (1 - treeId), conn.nullifierRoot[1][1], DefaultNullifierRoot());

    Chunkify(1, [FmtOpcode()])(enabled, p_req.chunks, [req.opType]);

    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}
template DoReqCreateBondToken(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(0, 1, 0, 0, 0, 0, 0, 0);// Update bond leaf once
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);
    component bond = BondLeaf();
    bond.arr <== conn.bondLeaf[0][1];

    /* correctness */
    ImplyEq()(enabled, conn.bondLeafId[0], req.tokenId);
    ImplyEq()(enabled, bond.baseTokenId, req.arg[4]/*target token id*/);
    ImplyEq()(enabled, bond.maturity, req.arg[1]/*maturity time*/);

    Chunkify(4, [FmtOpcode(), FmtTime(), FmtTokenId(), FmtTokenId()])(enabled, p_req.chunks, [req.opType, bond.maturity, bond.baseTokenId, conn.bondLeafId[0]]);
    
    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}
template DoReqRedeem(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(0, 1, 0, 1, 0, 2, 0, 0);// Update bond leaf, acc leaf once and token leaf twice
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);
    component bond = BondLeaf();
    bond.arr <== conn.bondLeaf[0][0];

    /* legality */
    AccLeaf_NonceCheck()(conn.accLeaf[0][0], enabled, req.nonce);
    TokenLeaf_SufficientCheck()(conn.tokenLeaf[0][0], enabled, req.amount);
    ImplyEq()(enabled, 1, TagGreaterThan(BitsTime())([currentTime, bond.maturity]));

    /* correctness */
    ImplyEq()(enabled, conn.accLeafId[0], req.accId);
    ImplyEq()(enabled, conn.bondLeafId[0], req.tokenId);
    ImplyEq()(enabled, conn.tokenLeafId[0], req.tokenId);
    ImplyEq()(enabled, conn.tokenLeafId[1], bond.baseTokenId);
    ImplyEqArr(LenOfBondLeaf())(enabled, conn.bondLeaf[0][0], conn.bondLeaf[0][1]);
    ImplyEqArr(LenOfAccLeaf())(enabled, AccLeaf_NonceIncrease()(AccLeaf_MaskTokens()(conn.accLeaf[0][0])), AccLeaf_MaskTokens()(conn.accLeaf[0][1]));
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Outgoing()(conn.tokenLeaf[0][0], enabled, req.amount), conn.tokenLeaf[0][1]);
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Incoming()(conn.tokenLeaf[1][0], enabled, req.amount), conn.tokenLeaf[1][1]);

    Chunkify(4, [FmtOpcode(), FmtAccId(), FmtTokenId(), FmtStateAmount()])(enabled, p_req.chunks, [req.opType, req.accId, req.tokenId, req.amount]);

    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}
template DoReqWithdrawFee(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(1, 0, 0, 0, 0, 0, 0, 0);// Update fee leaf once
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);
    component fee = FeeLeaf();
    fee.arr <== conn.feeLeaf[0][0];

    /* correctness */
    ImplyEq()(enabled, conn.feeLeafId[0], req.tokenId);
    ImplyEqArr(LenOfFeeLeaf())(enabled, conn.feeLeaf[0][1], [0]);

    Chunkify(3, [FmtOpcode(), FmtTokenId(), FmtStateAmount()])(enabled, p_req.chunks, [req.opType, req.tokenId, fee.amount]);

    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}
template DoReqEvacuation(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(0, 0, 0, 1, 0, 1, 0, 0);// Update acc leaf once and token leaf once
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);
    component token = TokenLeaf();
    token.arr <== conn.tokenLeaf[0][0];

    /* correctness */
    ImplyEq()(enabled, conn.accLeafId[0], req.arg[0]/*receiver id*/);
    ImplyEq()(enabled, conn.tokenLeafId[0], req.tokenId);
    ImplyEqArr(LenOfAccLeaf())(enabled, AccLeaf_MaskTokens()(conn.accLeaf[0][0]), AccLeaf_MaskTokens()(conn.accLeaf[0][1]));
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Outgoing()(conn.tokenLeaf[0][0], enabled, token.avl_amt + token.locked_amt), conn.tokenLeaf[0][1]);

    Chunkify(4, [FmtOpcode(), FmtAccId(), FmtTokenId(), FmtStateAmount()])(enabled, p_req.chunks, [req.opType, conn.accLeafId[0], conn.tokenLeafId[0], token.avl_amt + token.locked_amt]);

    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}
