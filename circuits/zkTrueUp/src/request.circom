pragma circom 2.1.5;

include "./const/_mod.circom";
include "./type/_mod.circom";
include "./gadgets/_mod.circom";
include "./mechanism.circom";
include "../../../node_modules/circomlib/circuits/bitify.circom";

/*
    In the template: DoRequest(), we have verified that all Merkle proofs are valid.

    For each request, we issue the same number of merkle tree update units. However, these units may not all be used.

    For example, if a request only updates one account leaf, only one account unit will be used. In this case, we need to ignore the second account unit.

    The way to ignore it is to directly check that 
    the new account root in the first merkle tree update units is equal to the new account root after the request is completed.
    (The former is in preprocessedReq, and the latter is in newState)

    This template is used to check this condition.

    Below are the definitions of each parameter:

    fee_unit_switch: 
        0: do not update fee unit
        1: update once

    tSBToken_unit_switch: 
        0: do not update tSBToken unit 
        1: update once

    order_unit_switch: 
        0: do not update order unit 
        1: update once

    acc_unit_switch: 
        0: do not update acc unit 
        1: update once 
        2: update twice

    nullifier_unit_switch: 
        0: do not update nullifier unit 
        1: update once

    token_unit_switch: 
        0: do not update token unit 
        1: update once 
        2: update twice, within the same acc leaf
        3: update twice, across different acc leaves
*/
template Conn(fee_unit_switch, tSBToken_unit_switch, order_unit_switch, acc_unit_switch, nullifier_unit_switch, token_unit_switch, epoch_switch, admin_ts_addr_swtich){
    signal input {bool} enabled;
    signal input oriState[LenOfState()], newState[LenOfState()], unitSet[LenOfUnitSet()];
    signal input nullifierTreeId;

    assert(MaxFeeUnitsPerReq() == 1);
    assert(MaxTSBTokenUnitsPerReq() == 1);
    assert(MaxOrderUnitsPerReq() == 1);
    assert(MaxNullifierUnitsPerReq() == 1);
    assert(MaxTokenUnitsPerReq() == 2);
    assert(MaxAccUnitsPerReq() == 2);

    assert(fee_unit_switch < 2);
    assert(tSBToken_unit_switch < 2);
    assert(order_unit_switch < 2);
    assert(acc_unit_switch < 3);
    assert(nullifier_unit_switch < 2);
    assert(token_unit_switch < 4);
    assert(epoch_switch < 2);
    assert(admin_ts_addr_swtich < 2);
    
    component ori_state = State();
    ori_state.arr <== oriState;
    component new_state = State();
    new_state.arr <== newState;
    component unit_set = UnitSet();
    unit_set.arr <== unitSet;

    // if the fee unit is not used, then the fee root of original state should be equal to the fee root of new state
    // otherwise, 
    //      the fee root of original state should be equal to the orignal fee root of the fee unit, 
    //      and the fee root of new state should be equal to the new fee root of the fee unit 
    component fee_unit = FeeUnit();
    fee_unit.arr <== unit_set.feeUnits[0];
    ImplyEq()(enabled, ori_state.feeRoot, Mux(2)([new_state.feeRoot, fee_unit.oriRoot[0]], fee_unit_switch));
    ImplyEq()(enabled, new_state.feeRoot, Mux(2)([ori_state.feeRoot, fee_unit.newRoot[0]], fee_unit_switch));

    // if the tSBToken unit is not used, then the tSBToken root of original state should be equal to the tSBToken root of new state
    // otherwise,
    //      the tSBToken root of original state should be equal to the orignal tSBToken root of the tSBToken unit,
    //      and the tSBToken root of new state should be equal to the new tSBToken root of the tSBToken unit
    component tSBToken_unit = TSBTokenUnit();
    tSBToken_unit.arr <== unit_set.tSBTokenUnits[0];
    ImplyEq()(enabled, ori_state.tSBTokenRoot, Mux(2)([new_state.tSBTokenRoot, tSBToken_unit.oriRoot[0]], tSBToken_unit_switch));
    ImplyEq()(enabled, new_state.tSBTokenRoot, Mux(2)([ori_state.tSBTokenRoot, tSBToken_unit.newRoot[0]], tSBToken_unit_switch));

    // if the order unit is not used, then the order root of original state should be equal to the order root of new state
    // otherwise,
    //      the order root of original state should be equal to the orignal order root of the order unit,
    //      and the order root of new state should be equal to the new order root of the order unit
    component order_unit = OrderUnit();
    order_unit.arr <== unit_set.orderUnits[0];
    ImplyEq()(enabled, ori_state.orderRoot, Mux(2)([new_state.orderRoot, order_unit.oriRoot[0]], order_unit_switch));
    ImplyEq()(enabled, new_state.orderRoot, Mux(2)([ori_state.orderRoot, order_unit.newRoot[0]], order_unit_switch));

    // if the acc units are both not used, 
    //      then the acc root of original state should be equal to the acc root of new state
    // if the acc units are both used, 
    //      then the acc root of original state should be equal to the original acc root of the first acc unit,
    //      and the acc root of new state should be equal to the new acc root of the second acc unit
    //      and the new acc root of the first acc unit should be equal to the first acc root of the second acc unit
    // if the first acc unit is used, and the second acc unit is not used,
    //      then the acc root of original state should be equal to the original acc root of the first acc unit,
    //      and the acc root of new state should be equal to the new acc root of the first acc unit
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

    //  if the epoch is not switched,
    //      if the nullifier unit is not used, then the nullifier root of original state should be equal to the nullifier root of new state
    //      otherwise,
    //          the nullifier root of original state should be equal to the orignal nullifier root of the nullifier unit,
    //          and the nullifier root of new state should be equal to the new nullifier root of the nullifier unit
    //  if the epoch is switched,
    //          the nullifier root can be updated without requiring the nullifier unit
    component nullifier_unit = NullifierUnit();
    nullifier_unit.arr <== unit_set.nullifierUnits[0];
    signal oriNullifierTreeRoot <== Mux(2)([ori_state.nullifierRoot[0], ori_state.nullifierRoot[1]], nullifierTreeId);
    signal newNullifierTreeRoot <== Mux(2)([new_state.nullifierRoot[0], new_state.nullifierRoot[1]], nullifierTreeId);
    ImplyEq()(enabled, oriNullifierTreeRoot * (1 - epoch_switch), Mux(2)([newNullifierTreeRoot * (1 - epoch_switch), nullifier_unit.oriRoot[0]], nullifier_unit_switch));
    ImplyEq()(enabled, newNullifierTreeRoot * (1 - epoch_switch), Mux(2)([oriNullifierTreeRoot * (1 - epoch_switch), nullifier_unit.newRoot[0]], nullifier_unit_switch));

    // if the token units are both not used,
    //      then the token root of original state should be equal to the token root of new state
    // if the first token unit is used, and the second token unit is not used,
    //      then the orignal token root of the first acc unit should be equal to the orignal token root of the first token unit
    //      and the new token root of the first acc unit should be equal to the new token root of the first token unit
    // if the token units are both used,
    //      if it's within the same acc leaf,
    //          then the orignal token root of the first acc unit should be equal to the orignal token root of the first token unit
    //          and the new token root of the first acc unit should be equal to the new token root of the second token unit
    //          and the new token root of the first token unit should be equal to the orignal token root of the second token unit
    //      if it's across different acc leaves,
    //          then the orignal token root of the first acc unit should be equal to the orignal token root of the first token unit
    //          and the new token root of the first acc unit should be equal to the new token root of the first token unit
    //          and the orignal token root of the second acc unit should be equal to the orignal token root of the second token unit
    //          and the new token root of the second acc unit should be equal to the new token root of the second token unit
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

    // if the epochs is not switched, then the epochs of original state should be equal to the epochs of new state
    ImplyEq()(enabled * (1 - epoch_switch), ori_state.epoch[0], new_state.epoch[0]);
    ImplyEq()(enabled * (1 - epoch_switch), ori_state.epoch[1], new_state.epoch[1]);

    // if the admin TS addr is switched, then the admin TS addr of original state should be equal to the admin TS addr of new state
    ImplyEq()(enabled * (1 - admin_ts_addr_swtich), ori_state.adminTsAddr, new_state.adminTsAddr);

    // the tx count need to be increased by 1
    ImplyEq()(enabled, ori_state.txCount + 1, new_state.txCount);

    signal output epoch[2][2] <== [[ori_state.epoch[0], new_state.epoch[0]], [ori_state.epoch[1], new_state.epoch[1]]];
    signal output nullifierRoot[2][2] <== [[ori_state.nullifierRoot[0], new_state.nullifierRoot[0]], [ori_state.nullifierRoot[1], new_state.nullifierRoot[1]]];
    signal output adminTsAddr[2] <== [ori_state.adminTsAddr, new_state.adminTsAddr];
    signal output txId <== ori_state.txCount;
    signal output feeLeafId[1] <== [fee_unit.leafId[0]];
    signal output feeLeaf[1][2][LenOfFeeLeaf()] <== [[fee_unit.oriLeaf, fee_unit.newLeaf]];
    signal output tSBTokenLeafId[1] <== [tSBToken_unit.leafId[0]];
    signal output tSBTokenLeaf[1][2][LenOfTSBTokenLeaf()] <== [[tSBToken_unit.oriLeaf, tSBToken_unit.newLeaf]];
    signal output orderLeafId[1] <== [order_unit.leafId[0]];
    signal output orderLeaf[1][2][LenOfOrderLeaf()] <== [[order_unit.oriLeaf, order_unit.newLeaf]];
    signal output accLeafId[2] <== [acc_unit[0].leafId[0], acc_unit[1].leafId[0]];
    signal output accLeaf[2][2][LenOfAccLeaf()] <== [[acc_leaf[0][0].arr, acc_leaf[0][1].arr], [acc_leaf[1][0].arr, acc_leaf[1][1].arr]];
    signal output tokenLeafId[2] <== [token_unit[0].leafId[0], token_unit[1].leafId[0]];
    signal output tokenLeaf[2][2][LenOfTokenLeaf()] <== [[token_unit[0].oriLeaf, token_unit[0].newLeaf], [token_unit[1].oriLeaf, token_unit[1].newLeaf]];
    signal output nullifierLeafId[1] <== [nullifier_unit.leafId[0]];
    signal output nullifierLeaf[1][2][LenOfNullifierLeaf()] <== [[nullifier_unit.oriLeaf, nullifier_unit.newLeaf]];
}

/*
    The Backend will pack all the requests it has constructed or received, 
    along with their execution results, 
    and upload them to the rollup contract. 

    The Circuit then verifies whether the contents of the package comply with our packing rules.

    Please refer to the packing rules: xxx

    And this template is used to perform the aforementioned Verifiecation.

*/
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

/* 
    The various templates below are the verification of how the Backend handles all types of requests. 

    Please refer to "Backend Request Handling and Circuit Verification": xxx

    The following annotations use numerical identifiers corresponding to the documentation above. Omitted numbers signify items in the circuit that do not require inspection.

    Please note, 
    the implementation of a validation point may necessitate coordination across multiple sections. 
    Every location pertinent to the validation point will be marked with the respective identifier. 
    However, sections of code marked with these identifiers do not necessarily represent the entirety of the validation logic.

*/

/* 
    This template is used to verify NOOP requests.

    Items that require verification: none

*/
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


/* 
    This template is used to verify Register requests.

    Items that require verification: 
    1. Backend constructs L1 request: Register
        *   Validate the signature in template: DoRequest()
        *   In this template, read request based on this format.
    3. Backend checks the default valud of the account leaf	   
    4. Backend updates the account leaf	   

*/
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

    //  3. Backend checks the default valud of the account leaf
    AccLeaf_EnforceDefault()(conn.accLeaf[0][0], enabled);

    /* correctness */

    //  4. Backend updates the account leaf
    ImplyEq()(enabled, conn.accLeafId[0], req.arg[0]/*receiver id*/);
    ImplyEqArr(LenOfAccLeaf())(enabled, AccLeaf_Register()(conn.accLeaf[0][0], req.arg[6]/*ts-addr*/), conn.accLeaf[0][1]);

    Chunkify(3, [FmtOpcode(), FmtAccId(), FmtHashedPubKey()])(enabled, p_req.chunks, [req.opType, conn.accLeafId[0], req.arg[6]/*ts-addr*/]);

    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}

/*
    This template is used to verify Deposit requests.

    Items that require verification:
    1. Backend constructs L1 request: Deposit
        *   Validate the signature in template: DoRequest()
        *   In this template, read request based on this format.
    2. Backend updates the token leaf

*/
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

    //  2. Backend updates the token leaf
    ImplyEq()(enabled, conn.accLeafId[0], req.arg[0]/*receiver id*/);
    ImplyEq()(enabled, conn.tokenLeafId[0], req.tokenId);
    ImplyEqArr(LenOfAccLeaf())(enabled, AccLeaf_MaskTokens()(conn.accLeaf[0][0]), AccLeaf_MaskTokens()(conn.accLeaf[0][1]));
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Incoming()(conn.tokenLeaf[0][0], enabled, req.amount), conn.tokenLeaf[0][1]);

    Chunkify(4, [FmtOpcode(), FmtAccId(), FmtTokenId(), FmtStateAmount()])(enabled, p_req.chunks, [req.opType, conn.accLeafId[0], req.tokenId, req.amount]);

    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}

/*
    This template is used to verify Transfer requests.

    Items that require verification:
    0. Backend receives a signed L2 user request: Transfer from a user
        *   Validate the signature in template: DoRequest()
        *   In this template, read request based on this format.
    1. Backend checks if the sender has enough balance
    2. Backend checks if the nonce is correct
    3. Backend updates the sender's account leaf and token leaves
    4. Backend updates receiver's token leaves

*/
template DoReqTransfer(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(0, 0, 0, 2, 0, 3, 0, 0);// Update acc leaf twice, with each acc leaf updating the token leaf once
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);

    /* legality */

    // 1. Backend checks if the sender has enough balance
    TokenLeaf_SufficientCheck()(conn.tokenLeaf[0][0], enabled, req.amount);

    // 2. Backend checks if the nonce is correct
    AccLeaf_NonceCheck()(conn.accLeaf[0][0], enabled, req.nonce);

    /* correctness */

    // 3. Backend updates the sender's account leaf and token leaves
    ImplyEq()(enabled, conn.accLeafId[0], req.accId);
    ImplyEq()(enabled, conn.tokenLeafId[0], req.tokenId);
    ImplyEqArr(LenOfAccLeaf())(enabled, AccLeaf_NonceIncrease()(AccLeaf_MaskTokens()(conn.accLeaf[0][0])), AccLeaf_MaskTokens()(conn.accLeaf[0][1]));
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Outgoing()(conn.tokenLeaf[0][0], enabled, req.amount), conn.tokenLeaf[0][1]);

    // 4. Backend updates receiver's token leaves
    ImplyEq()(enabled, conn.accLeafId[1], req.arg[0]/*receiver id*/);
    ImplyEq()(enabled, conn.tokenLeafId[1], req.tokenId);
    ImplyEqArr(LenOfAccLeaf())(enabled, AccLeaf_MaskTokens()(conn.accLeaf[1][0]), AccLeaf_MaskTokens()(conn.accLeaf[1][1]));
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Incoming()(conn.tokenLeaf[1][0], enabled, req.amount), conn.tokenLeaf[1][1]);

    signal packedAmt <== Fix2FloatCond()(enabled, req.amount);
    Chunkify(5, [FmtOpcode(), FmtAccId(), FmtTokenId(), FmtPacked(), FmtAccId()])(enabled, p_req.chunks, [req.opType, req.accId, req.tokenId, packedAmt, req.arg[0]/*receiver id*/]);

    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}

/*
    This template is used to verify Withdraw requests.

    Items that require verification:
    0. Backend receives a signed L2 user request: Withdraw from a user
        *   Validate the signature in template: DoRequest()
        *   In this template, read request based on this format.
    1. Backend checks if the sender has enough balance to withdraw
    2. Backend checks if the sender has enough balance for the fee
    3. Backend checks if the nonce is correct
    4. Backend updates the sender's account leaf and token leaves

*/
template DoReqWithdraw(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(1, 0, 0, 1, 0, 2, 0, 0);// Update fe leaf one, acc leaf once and token leaf twice
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);

    /* legality */
    
    // 3. Backend checks if the nonce is correct
    AccLeaf_NonceCheck()(conn.accLeaf[0][0], enabled, req.nonce);

    // 1. Backend checks if the sender has enough balance to withdraw
    TokenLeaf_SufficientCheck()(conn.tokenLeaf[0][0], enabled, req.amount);

    // 2. Backend checks if the sender has enough balance for the fee
    TokenLeaf_SufficientCheck()(conn.tokenLeaf[1][0], enabled, req.txFeeAmt);

    /* correctness */

    // 4. Backend updates the sender's account leaf and token leaves
    ImplyEq()(enabled, conn.accLeafId[0], req.accId);
    ImplyEq()(enabled, conn.tokenLeafId[0], req.tokenId);
    ImplyEq()(enabled, conn.tokenLeafId[1], req.txFeeTokenId);
    ImplyEqArr(LenOfAccLeaf())(enabled, AccLeaf_NonceIncrease()(AccLeaf_MaskTokens()(conn.accLeaf[0][0])), AccLeaf_MaskTokens()(conn.accLeaf[0][1]));
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Outgoing()(conn.tokenLeaf[0][0], enabled, req.amount), conn.tokenLeaf[0][1]);
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Outgoing()(conn.tokenLeaf[1][0], enabled, req.txFeeAmt), conn.tokenLeaf[1][1]);
    
    ImplyEq()(enabled, conn.feeLeafId[0], req.txFeeTokenId);
    ImplyEqArr(LenOfFeeLeaf())(enabled, FeeLeaf_Incoming()(conn.feeLeaf[0][0], enabled, req.txFeeAmt), conn.feeLeaf[0][1]);

    signal packedTxFeeAmt <== Fix2FloatCond()(enabled, req.txFeeAmt);
    Chunkify(6, [FmtOpcode(), FmtAccId(), FmtTokenId(), FmtStateAmount(), FmtTokenId(), FmtPacked()])(enabled, p_req.chunks, [req.opType, conn.accLeafId[0], req.tokenId, req.amount, req.txFeeTokenId, packedTxFeeAmt]);

    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}

/*
    This template is used to verify ForcedWithdraw requests.

    Items that require verification:
    1. Backend constructs L1 request: ForceWithdraw
        *   Validate the signature in template: DoRequest()
        *   In this template, read request based on this format.
    2. Backend updates the token leaf

*/
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

    // 2. Backend updates the token leaf
    ImplyEq()(enabled, conn.accLeafId[0], req.arg[0]/*receiver id*/);
    ImplyEq()(enabled, conn.tokenLeafId[0], req.tokenId);
    ImplyEqArr(LenOfAccLeaf())(enabled, AccLeaf_MaskTokens()(conn.accLeaf[0][0]), AccLeaf_MaskTokens()(conn.accLeaf[0][1]));
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Outgoing()(conn.tokenLeaf[0][0], enabled, token.avl_amt), conn.tokenLeaf[0][1]);

    Chunkify(4, [FmtOpcode(), FmtAccId(), FmtTokenId(), FmtStateAmount()])(enabled, p_req.chunks, [req.opType, conn.accLeafId[0], conn.tokenLeafId[0], token.avl_amt]);

    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}

/*
    This template is used to verify AuctionBorrow (AB), AuctionLend (AL), SecondLimitOrder (SL) requests.

    --------------------------------
    Items that require verification for AuctionBorrow:
    AB-0. Backend receives a signed L2 user request: AuctionBorrow from a user
        *   Validate the signature in template: DoRequest()
        *   In this template, read request based on this format.
    AB-1. Check if the market exists
    AB-2. Check if borrowingAmt, feeRate, collateralAmt, PIR can be converted to floating point numbers
    AB-3. Check if duplicated orders exist
    AB-5. Check if expiredTime is legal
    AB-6. Check if the order is expired
    AB-7. Check interest lower limit
        *   In this template, read request based on this format. So PIR must be greater than zero.
        *   This template implements the second lower limit restriction.
                (PIR / one) > (-365 / (daysFromMatched - 1))
                => (PIR * daysFromMatched - PIR) > (-365 * one)
                => (PIR * daysFromMatched + 365 * one) > PIR
    AB-10.Check if there is enough asset as collateral in the wallet
    AB-11.Backend updates the sender's token leaf
|   AB-12.Backend updates nullifier
    AB-13.Backend adds this order to the order list

    Locked amount for AuctionBorrow (Collateral):
    $$ lockedFeeAmt := lendAmt * \lfloor \frac {defaultMatchedPIR * (d_OTM - 1)}{365} \rfloor $$
    $$ lockedAmt = lendAmt + lockedFeeAmt $$

    --------------------------------
    Items that require verification for AuctionLend:
    AL-0. Backend receives a signed L2 user request: AuctionLend from a user
        *   Validate the signature in template: DoRequest()
        *   In this template, read request based on this format.
    AL-1. Check if the market exists
    AL-2. Check if lendingAmt, feeRate, defaultPIR can be converted to floating point numbers
    AL-3. Check if duplicated orders exist
    AL-5. Check if t_e is valid
    AL-6. Check if the order is expired
    AL-7. Check interest lower limit
        *   In this template, read request based on this format. So PIR must be greater than zero.
        *   This template implements the second lower limit restriction.
                ((PIR - one) / one) > (-365 / (daysFromMatched - 1))
                => (PIR - one) * (daysFromMatched - 1) > -365 * one
                => (PIR * daysFromMatched - daysFromMatched * one - PIR + one) > (-365 * one)
                => (PIR * daysFromMatched + 366 * one) > daysFromMatched * one + PIR
    AL-8. Check if there is enough asset in the wallet for lending
    AL-9. Backend updates the sender's token leaf
|   AL-10.Backend updates nullifier
    AL-11.Backend adds this order to the order list

    Locked amount for AuctionLend (Lending Token):
    $$ lockedAmt = collateralAmt $$

    --------------------------------
    Items that require verification for SecondLimitOrder:
    SL-0. Backend receives a signed L2 user request: SecondLimitOrder from a user
        *   Validate the signature in template: DoRequest()
        *   In this template, read request based on this format.
    SL-1. Check if the market exists
    SL-2. Check if MQ, BQ, feeRate can be converted to floating point numbers
    SL-3. Check if duplicated orders exist
    SL-5. Check if t_e is valid
    SL-6. Check if the order is expired
    SL-7. Check interest lower limit
        *   In this template, read request based on this format. So PIR must be greater than zero.
        *   This template implements the second lower limit restriction.
                (MQ / BQ - 1) > (-365 / daysFromMatched)
                => ((MQ - BQ) * daysFromMatched) > (-365 * BQ)
                => (MQ * daysFromMatched + 365 * BQ) > (BQ * daysFromMatched)
    SL-9. If it is a buyer's order, check if there's enough BQ in the wallet
    SL-10.If it is a seller's order, check if there's enough MQ in the wallet
    SL-11.If it is a buyer, lock BQ
    SL-12.If it is a seller, lock MQ
|   SL-13.Backend updates nullifier
    SL-14.Backend adds this order to the order list

    Locked amount for SecondLimitOrder (Base Token):
    (buy side)
    $$ days := 
        \begin{cases}
            d_{ETM}&, PIR < 0 \\
            d_{OTM}&, otherwise \\
        \end{cases}
    $$
    $$ lockedAmt := \lfloor \frac{365 * MQ * BQ}{d_{ETM} * (MQ - BQ) + 365 * BQ} \rfloor + \lfloor \frac{MQ * Max(takerFeeRate, makerFeeRate) * days}{365 * 10^8} \rfloor $$

    (sell side)
    $$ lockedAmt := MQ $$

*/
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
    component tSBToken = TSBTokenLeaf();
    tSBToken.arr <== conn.tSBTokenLeaf[0][0];


    signal digest <== Req_Digest()(p_req.req);
    
    signal isLend <== TagIsEqual()([req.opType, OpTypeNumAuctionLend()]);
    signal isBorrow <== TagIsEqual()([req.opType, OpTypeNumAuctionBorrow()]);
    signal isAuc <== Or()(isLend, isBorrow);
    signal is2nd <== TagIsEqual()([req.opType, OpTypeNumSecondLimitOrder()]);
    signal is2ndBuy <== And()(is2nd, Not()(Bool()(req.arg[8]/*side*/)));
    signal is2ndSell <== And()(is2nd, Bool()(req.arg[8]/*side*/));

    /* calc lock amt */
    // Please refer to the lockedAmt formula for each request mentioned above.
    signal daysFromMatched <== DaysFrom()(p_req.matchedTime[0], tSBToken.maturity);
    signal daysFromExpired <== Req_DaysFromExpired()(p_req.req, tSBToken.maturity);
    signal isNegPIRIf2ndBuy <== And()(is2ndBuy, TagLessThan(BitsAmount())([req.arg[5]/*target amount*/, req.amount]));

    var one = 10 ** 8;
    signal lockFeeAmtIfLend <== AuctionCalcFee()(req.fee0, req.amount, req.arg[9] + one/*default PIR*/, daysFromMatched);
    var lockAmtIfLend = req.amount + lockFeeAmtIfLend;
    signal expectedSellAmtIf2ndBuy <== CalcNewBQ()(enabled, req.arg[5]/*target amount*/, req.arg[5]/*target amount*/, req.amount, Mux(2)([daysFromExpired, daysFromMatched], isNegPIRIf2ndBuy));
    signal lockFeeIf2ndBuy <== SecondCalcFee()(req.arg[5]/*target amount*/, Max(BitsRatio())([req.fee0, req.fee1]), daysFromMatched);
    signal lockAmtIf2ndBuy <== expectedSellAmtIf2ndBuy + lockFeeIf2ndBuy;
    signal lock_amt <== Mux(4)([lockAmtIfLend, req.amount, lockAmtIf2ndBuy, req.amount], isLend * 0 + isBorrow * 1 + is2ndBuy * 2 + is2ndSell * 3);
    assert(BitsAmount() + 1 <= ConstFieldBits());
    _ <== Num2Bits(BitsUnsignedAmt())(lock_amt);

    /* legality */

    // AB-10.Check if there is enough asset as collateral in the wallet
    // AL-8. Check if there is enough asset in the wallet for lending
    // SL-9. If it is a buyer's order, check if there's enough BQ in the wallet
    // SL-10.If it is a seller's order, check if there's enough MQ in the wallet
    TokenLeaf_SufficientCheck()(conn.tokenLeaf[0][0], enabled, lock_amt);
    
    // AB-6. Check if the order is expired
    // AL-6. Check if the order is expired
    // SL-6. Check if the order is expired
    Req_CheckExpiration()(p_req.req, enabled, p_req.matchedTime[0]);
    
    // AB-3. Check if duplicated orders exist
    // AL-3. Check if duplicated orders exist
    // SL-3. Check if duplicated orders exist
    ImplyEq()(enabled, req.arg[7]/*epoch*/, Mux(2)([conn.epoch[0][0], conn.epoch[1][0]], p_req.nullifierTreeId[0]));
    NullifierLeaf_CheckCollision()(conn.nullifierLeaf[0][0], enabled, digest);
    ImplyEq()(enabled, 0, Mux(LenOfNullifierLeaf())(conn.nullifierLeaf[0][0], p_req.nullifierElemId[0]));
    
    // Ensure that the matched time of the order does not differ from the current time (rollup time) by more than one day.
    ImplyEq()(enabled, 1, TagLessEqThan(BitsTime())([p_req.matchedTime[0], currentTime]));
    ImplyEq()(enabled, 1, TagLessThan(BitsTime())([currentTime - p_req.matchedTime[0], ConstSecondsPerDay()]));
    
    // AB-5. Check if expiredTime is legal
    // AL-5. Check if t_e is valid
    ImplyEq()(isAuc, 1, TagLessEqThan(BitsTime())([req.arg[2] + 86400, tSBToken.maturity]));
    
    // SL-5. Check if t_e is valid
    ImplyEq()(is2nd, 1, TagLessEqThan(BitsTime())([req.arg[2], tSBToken.maturity]));

    // AB-7. Check interest lower limit
    // (PIR * daysFromMatched + 366 * one) > daysFromMatched * one + PIR
    signal daysFromMatchedIfEnabled <== daysFromMatched * enabled;
    ImplyEq()(isAuc, 1, TagGreaterEqThan(BitsRatio() + BitsTime())([req.arg[3]/*PIR*/ * daysFromMatchedIfEnabled + 366 * one, daysFromMatchedIfEnabled * one + req.arg[3]/*PIR*/]));

    // SL-7. Check interest lower limit
    // (MQ * daysFromMatched + 365 * BQ) > (BQ * daysFromMatched)
    signal MQ <== Mux(2)([req.arg[5]/*target amount*/, req.amount], is2ndSell);
    signal BQ <== Mux(2)([req.arg[5]/*target amount*/, req.amount], is2ndBuy);
    ImplyEq()(is2nd, 1, TagGreaterThan(BitsRatio() + BitsTime())([MQ * daysFromMatchedIfEnabled + 365 * BQ, BQ * daysFromMatchedIfEnabled]));

    /* correctness */

    // AB-1. Check if the market exists
    // AL-1. Check if the market exists
    ImplyEq()(isLend, tSBToken.baseTokenId, req.tokenId);
    ImplyEq()(isBorrow, tSBToken.baseTokenId, req.arg[4]);
    ImplyEq()(isAuc, tSBToken.maturity, req.arg[1]);

    // SL-1. Check if the market exists
    ImplyEq()(is2nd, conn.tSBTokenLeafId[0], Mux(2)([req.arg[4], req.tokenId], req.arg[8]));

    // AB-11.Backend updates the sender's token leaf
    // AL-9. Backend updates the sender's token leaf
    // SL-11.If it is a buyer, lock BQ
    // SL-12.If it is a seller, lock MQ
    ImplyEq()(enabled, conn.accLeafId[0], req.accId);
    ImplyEq()(enabled, conn.tokenLeafId[0], req.tokenId);
    ImplyEqArr(LenOfAccLeaf())(enabled, AccLeaf_MaskTokens()(conn.accLeaf[0][0]), AccLeaf_MaskTokens()(conn.accLeaf[0][1]));
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Lock()(conn.tokenLeaf[0][0], enabled, lock_amt), conn.tokenLeaf[0][1]);

    // AB-12.Backend updates nullifier
    // AL-10.Backend updates nullifier
    // SL-13.Backend updates nullifier
    ImplyEq()(enabled, conn.nullifierLeafId[0], Digest2NulliferLeafId()(digest));
    ImplyEqArr(LenOfNullifierLeaf())(enabled, NullifierLeaf_Place()(conn.nullifierLeaf[0][0], digest, p_req.nullifierElemId[0]), conn.nullifierLeaf[0][1]);
    
    // AB-13.Backend adds this order to the order list
    // AL-11.Backend adds this order to the order list
    // SL-14.Backend adds this order to the order list
    ImplyEqArr(LenOfOrderLeaf())(enabled, OrderLeaf_Default()(), conn.orderLeaf[0][0]);
    ImplyEqArr(LenOfOrderLeaf())(enabled, OrderLeaf_Place()(p_req.req, 0, 0, conn.txId, lock_amt), conn.orderLeaf[0][1]);

    // AB-2. Check if borrowingAmt, feeRate, collateralAmt, PIR can be converted to floating point numbers
    // AL-2. Check if lendingAmt, feeRate, defaultPIR can be converted to floating point numbers
    // SL-2. Check if MQ, BQ, feeRate can be converted to floating point numbers
    signal packedAmount0 <== Fix2FloatCond()(enabled, req.amount);
    signal packedAmount1 <== Fix2FloatCond()(enabled, req.arg[5]/*target amount*/);
    signal packedFee0 <== Fix2FloatCond()(enabled, req.fee0);
    signal packedFee1 <== Fix2FloatCond()(enabled, req.fee1);

    Chunkify(8, [FmtOpcode(), FmtAccId(), FmtTokenId(), FmtPacked(), FmtPacked(), FmtPacked(), FmtTime(), FmtTime()])(And()(enabled, isLend), p_req.chunks, [req.opType, req.accId, req.tokenId, packedAmount0, packedFee0, req.arg[9], req.arg[1]/*maturity time*/, p_req.matchedTime[0]]);
    Chunkify(7, [FmtOpcode(), FmtAccId(), FmtTokenId(), FmtPacked(), FmtPacked(), FmtPacked(), FmtTime()])(And()(enabled, isBorrow), p_req.chunks, [req.opType, req.accId, req.tokenId, packedAmount0, packedFee0, packedAmount1, p_req.matchedTime[0]]);
    Chunkify(10, [FmtOpcode(), FmtAccId(), FmtTokenId(), FmtPacked(), FmtPacked(), FmtPacked(), FmtTokenId(), FmtPacked(), FmtTime(), FmtTime()])(And()(enabled, is2nd), p_req.chunks, [req.opType, req.accId, req.tokenId, packedAmount0, packedFee0, packedFee1, req.arg[4]/*target token id*/, packedAmount1, req.arg[2]/*expired time*/, p_req.matchedTime[0]]);

    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}

/*
    This template is used to verify AuctionStart (AS), SecondLimitStart (SS) requests.

    ChannelOut is not initialized, so these two requests cannot be used as the end of a batch.

    Items that require verification for AuctionStart:
    AS-0. List orders in a market
    AS-1. Exclude the expired orders
    AS-3. Check if the borrow order with the highest priority matches with the lend order or not. If not, exclude this borrow order and repeat step 2
    AS-4. If a new borrow order is processed in a matching round, Backend constructs L2 admin request: AuctionStart
        *   Validate the signature in template: DoRequest()
        *   In this template, read request based on this format.
    
    Items that require verification for SecondLimitStart:
    SSS-15. Backend constructs L2 admin request: SecondLimitStart
    SSS-16. Include all orders in this market to process
    SSS-17. Exclude the expired orders

*/
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

    // AS-0. List orders in a market
    // SSS-16. Include all orders in this market to process
    ImplyEq()(enabled, order_req.opType, Mux(2)([OpTypeNumSecondLimitOrder(), OpTypeNumAuctionBorrow()], isAuctionStart));
    
    // AS-1. Exclude the expired orders
    // SL-6. Check if the order is expired
    Req_CheckExpiration()(order.req, enabled, p_req.matchedTime[0]);

    /* correctness */
    // AS-4. If a new borrow order is processed in a matching round, Backend constructs L2 admin request: AuctionStart
    // SSS-15. Backend constructs L2 admin request: SecondLimitStart
    //      This step will temporarily remove the order from the order tree. It will be reinserted during AuctionEnd or SecondLimitEnd.
    ImplyEqArr(LenOfOrderLeaf())(enabled, OrderLeaf_Default()(), conn.orderLeaf[0][1]);

    signal packedPIR <== Fix2FloatCond()(enabled, req.arg[3]/*matched PIR*/);
    Chunkify(3, [FmtOpcode(), FmtTxOffset(), FmtPacked()])(And()(enabled, isAuctionStart), p_req.chunks, [req.opType, conn.txId - order.txId, packedPIR]);
    Chunkify(2, [FmtOpcode(), FmtTxOffset()])(And()(enabled, Not()(isAuctionStart)), p_req.chunks, [req.opType, conn.txId - order.txId]);

    // AS-0. List orders in a market
    // SSS-16. Include all orders in this market to process
    //      The information in Channel includes the order details, including the current Market being processed.
    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    channelOut <== Channel_New()(conn.orderLeaf[0][0], [order.cumAmt0, order.cumAmt1, req.arg[3]/*matched PIR*/ * isAuctionStart, 0, 0]);
}

/*
    This template is used to verify SecondMarketOrder (SM) requests.

    ChannelOut is not initialized, so this request cannot be used as the end of a batch.

    Items that require verification for AuctionStart:
    SM-0. Backend receives a signed L2 user request: SecondMarketOrder from a user
        *   Validate the signature in template: DoRequest()
        *   In this template, read request based on this format.
    SM-1. Check if the market exists
    SM-2. Check if MQ, BQ, makerFeeRate, takerFeeRate can be converted to floating point numbers
    SM-3. Check if duplicated orders exist
    SM-5. Check if t_e is valid
    SM-6. Check if it is expired
    SM-7. If it's a buy order, check if there is enough BQ in the wallet
        *   Checked in template: DoSecondMarketEnd()
    SM-22. Backend updates nullifier
*/
template DoReqSecondMarketOrder(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(0, 1, 0, 0, 1, 0, 0, 0);// Update acc leaf and nullifier leaf once
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);
    component tSBToken = TSBTokenLeaf();
    tSBToken.arr <== conn.tSBTokenLeaf[0][0];

    signal digest <== Req_Digest()(p_req.req);
    
    /* legality */

    // SM-6. Check if it is expired	t_o < t_e
    Req_CheckExpiration()(req.arr, enabled, p_req.matchedTime[0]);

    // SM-3. Check if duplicated orders exist	nullifier check	Y
    ImplyEq()(enabled, req.arg[7]/*epoch*/, Mux(2)([conn.epoch[0][0], conn.epoch[1][0]], p_req.nullifierTreeId[0]));
    NullifierLeaf_CheckCollision()(conn.nullifierLeaf[0][0], enabled, digest);
    ImplyEq()(enabled, 0, Mux(LenOfNullifierLeaf())(conn.nullifierLeaf[0][0], p_req.nullifierElemId[0]));
    
    // SM-5. Check if t_e is valid
    ImplyEq()(enabled, 1, TagLessEqThan(BitsTime())([req.arg[2], tSBToken.maturity]));

    /* correctness */

    // SM-1. Check if the market exists
    ImplyEq()(enabled, conn.tSBTokenLeafId[0], Mux(2)([req.arg[4], req.tokenId], req.arg[8]));
    
    // SM-22. Backend updates nullifier
    ImplyEq()(enabled, conn.nullifierLeafId[0], Digest2NulliferLeafId()(digest));
    ImplyEqArr(LenOfNullifierLeaf())(enabled, NullifierLeaf_Place()(conn.nullifierLeaf[0][0], digest, p_req.nullifierElemId[0]), conn.nullifierLeaf[0][1]);
    
    // SM-2. Check if MQ, BQ, makerFeeRate, takerFeeRate can be converted to floating point numbers
    signal packedAmount0 <== Fix2FloatCond()(enabled, req.amount);
    signal packedAmount1 <== Fix2FloatCond()(enabled, req.arg[5]/*target amount*/);
    signal packedFee0 <== Fix2FloatCond()(enabled, req.fee0);

    Chunkify(8, [FmtOpcode(), FmtAccId(), FmtTokenId(), FmtPacked(), FmtPacked(), FmtTokenId(), FmtPacked(), FmtTime()])(enabled, p_req.chunks, [req.opType, req.accId, req.tokenId, packedAmount0, packedFee0, req.arg[4]/*target token id*/, packedAmount1, req.arg[2]/*expired time*/]);

    // SM-7. If it's a buy order, check if there is enough BQ in the wallet
    //      This step is checked in DoSecondMarketEnd()
    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    channelOut <== Channel_New()(OrderLeaf_Place()(p_req.req, 0, 0, conn.txId, 0), [0, 0, 0, 0, 0]);
}

/*
    This template is used to verify AuctionMatch (AM), SecondLimitExchange (SLI), SecondMarketExchange (SMI) requests.

    Items that require verification for AuctionMatch:
    AM-5. Perform Interact operation on the specified borrow and lend orders
    AM-6. Charge the fee from the lender
    AM-7. Deduct the matched lending amount from the previously locked lending amount
    AM-8. If the lend order is completed, return the remaining locked amount in the lend order
    AM-9. Distribute TSB tokens to the lender
    AM-10.Backend constructs L2 admin request: AuctionMatch
        *   Validate the signature in template: DoRequest()
        *   In this template, read request based on this format.

    Items that require verification for SecondLimitExchange:
    SLI-16. Include all orders in this market to process
    SLI-17. Exclude the expired orders
    SLI-19. Check if a maker with the highest priority matches his/her orders or not
    SLI-20. Perform Interaction with the matched buyer's orders and seller's orders
    SLI-21. If the maker is the seller, check if matchedBQ is greater than or equal to the maker's fee
    SLI-22. Execute the transaction result
    SLI-23. Charge the maker fee
    SLI-24. If a maker's order has been completed, return the remaining locked amount in the order
    SLI-25. Backend constructs L2 admin request: SecondLimitExchange
        *   Validate the signature in template: DoRequest()
        *   In this template, read request based on this format.

    Items that require verification for SecondMarketExchange:
    SMI-8. Include all orders in this market to process
    SMI-9. Exclude the expired orders
    SMI-11. Check if the maker with the highest priority matches with this order or not
    SMI-12. Perform Interaction on the specified buy order and sell order
    SMI-13. If the maker is the seller, check if matchedBQ is greater than or equal to the maker's fee
    SMI-14. Execute the trading result
    SMI-15. Charge the maker fee
    SMI-16. If the maker order is completed, return the remaining locked amount in the maker order
    SMI-17. Backend constructs L2 admin request: SecondMarketExchange   
        *   Validate the signature in template: DoRequest()
        *   In this template, read request based on this format.

*/
template DoReqInteract(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(1, 1, 1, 1, 0, 2, 0, 0);// Update fee leaf, tSBToken leaf, order leaf, acc leaf once and token leaf twice
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);
    component tSBToken = TSBTokenLeaf();
    tSBToken.arr <== conn.tSBTokenLeaf[0][0];
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
    
    // AM-5. Perform Interact operation on the specified borrow and lend orders
    // SLI-20. Perform Interaction with the matched buyer's orders and seller's orders
    // SMI-12. Perform Interact on the specified buy order and sell order   
    signal days <== DaysFrom()(p_req.matchedTime[0], tSBToken.maturity);
    signal newLend[LenOfOrderLeaf()], newBorrow[LenOfOrderLeaf()], isMatchedIfAuction;
    var matchedPIR = channel_in.args[2];
    (newLend, newBorrow, isMatchedIfAuction) <== AuctionInteract()(ori_order1.arr, ori_order0.arr, Mux(2)([1, matchedPIR], isAuction), days);
    signal newTaker[LenOfOrderLeaf()], newMaker[LenOfOrderLeaf()], isMatchedIfSecondary;
    (newTaker, newMaker, isMatchedIfSecondary) <== SecondaryInteract()(ori_order0.arr, ori_order1.arr, days);
    
    component new_order0 = OrderLeaf();
    new_order0.arr <== Multiplexer(LenOfOrderLeaf(), 2)([newTaker, newBorrow], TagIsEqual()([req.opType, OpTypeNumAuctionMatch()]));
    component new_order1 = OrderLeaf();
    new_order1.arr <== Multiplexer(LenOfOrderLeaf(), 2)([newMaker, newLend], TagIsEqual()([req.opType, OpTypeNumAuctionMatch()]));

    var matched_amt0 = new_order1.cumAmt0 - ori_order1.cumAmt0;
    var matched_amt1 = new_order1.cumAmt1 - ori_order1.cumAmt1;

    /* Calc fee */
    // There are two ways to collect fees.
    //      One is deducted from the money originally locked. (feeFromLocked)
    //      The other is deducted from the money obtained this time. (feeFromTarget)
    var one = 10 ** 8;
    signal feeFromLocked, feeFromTarget, fee;
    (feeFromLocked, feeFromTarget, fee) <== CalcFee()(new_order1.arr, enabled, ori_order1.cumAmt0, ori_order1.cumAmt1, p_req.matchedTime[0], tSBToken.maturity, Mux(2)([1, ori_order1_req.arg[9] + one/*default PIR*/], isAuction));
    
    signal enabledAndIsAuction <== And()(enabled, isAuction);
    signal enabledAndIsSecondaryLimit <== And()(enabled, isSecondaryLimit);
    signal enabledAndIsSecondaryMarket <== And()(enabled, isSecondaryMarket);

    /* legality */

    // AS-1. Exclude the expired orders
    // SLI-17. Exclude the expired orders
    // SMI-9. Exclude the expired orders
    Req_CheckExpiration()(ori_order1.req, enabled, p_req.matchedTime[0]);
    
    // AS-3. Check if the borrow order with the highest priority matches with the lend order or not. If not, exclude this borrow order and repeat step 2
    ImplyEq()(enabledAndIsAuction, ori_order0_req.opType, OpTypeNumAuctionBorrow());
    ImplyEq()(enabledAndIsAuction, ori_order1_req.opType, OpTypeNumAuctionLend());
    ImplyEq()(enabledAndIsAuction, 1, TagGreaterEqThan(BitsRatio())([ori_order1_req.arg[3]/*PIR*/, channel_in.args[3]]));

    // SLI-19. Check if a maker with the highest priority matches his/her orders or not
    ImplyEq()(enabledAndIsSecondaryLimit, ori_order0_req.opType, OpTypeNumSecondLimitOrder());
    ImplyEq()(enabledAndIsSecondaryLimit, ori_order1_req.opType, OpTypeNumSecondLimitOrder());

    // SMI-11. Check if a maker with the highest priority matches his/her orders or not
    ImplyEq()(enabledAndIsSecondaryMarket, ori_order0_req.opType, OpTypeNumSecondMarketOrder());
    ImplyEq()(enabledAndIsSecondaryMarket, ori_order1_req.opType, OpTypeNumSecondLimitOrder());

    // AS-3. Check if the borrow order with the highest priority matches with the lend order or not. If not, exclude this borrow order and repeat step 2
    // SLI-19. Check if a maker with the highest priority matches his/her orders or not
    // SMI-11. Check if a maker with the highest priority matches his/her orders or not
    ImplyEq()(enabled, 1, Mux(2)([isMatchedIfSecondary, isMatchedIfAuction], TagIsEqual()([req.opType, OpTypeNumAuctionMatch()])));
    
    // SLI-21. If the maker is the seller, check if matchedBQ is greater than or equal to the maker's fee
    // SMI-13. If the maker is the seller, check if matchedBQ is greater than or equal to the maker's fee
    ImplyEq()(enabled, 1, TagLessEqThan(BitsAmount())([feeFromTarget, matched_amt1]));

    // Ensure that the matched time of the order does not differ from the current time (rollup time) by more than one day.
    ImplyEq()(enabled, 1, TagLessEqThan(BitsTime())([p_req.matchedTime[0], currentTime]));
    ImplyEq()(enabled, 1, TagLessThan(BitsTime())([currentTime - p_req.matchedTime[0], ConstSecondsPerDay()]));

    /* correctness */

    // AM-6. Charge the fee from the lender
    // AM-7. Deduct the matched lending amount from the previously locked lending amount
    // AM-8. If the lend order is completed, return the remaining locked amount in the lend order
    // AM-9. Distribute TSB tokens to the lender
    // SLI-22. Execute the transaction result
    //     This step only handle the maker's order. The taker's order will be handled in DoReqEnd().
    // SLI-23. Charge the maker fee
    // SLI-24. If a maker's order has been completed, return the remaining locked amount in the order
    // SMI-14. Execute the trading 
    //     This step only handle the maker's order. The taker's order will be handled in DoReqEnd().
    // SMI-15. Charge the maker's fee
    // SMI-16. If the maker order is completed, return the remaining locked amt in the order
    assert(BitsAmount() + 1 <= ConstFieldBits());
    signal newNewOrder1[LenOfOrderLeaf()] <== OrderLeaf_DeductLockedAmt()(new_order1.arr, enabled, feeFromLocked + matched_amt0);
    signal isFull <== OrderLeaf_IsFull()(newNewOrder1);
    component new_new_order1 = OrderLeaf();
    new_new_order1.arr <== newNewOrder1;
    signal refund <== isFull * new_new_order1.lockedAmt;
    ImplyEq()(enabled, conn.accLeafId[0], ori_order1_req.accId);
    ImplyEq()(And()(enabled, Or()(isSecondaryLimit, isSecondaryMarket)), conn.tokenLeafId[0], ori_order1_req.arg[4]/*target token id*/);
    ImplyEq()(enabled, conn.tokenLeafId[1], ori_order1_req.tokenId);
    ImplyEqArr(LenOfAccLeaf())(enabled, AccLeaf_MaskTokens()(conn.accLeaf[0][0]), AccLeaf_MaskTokens()(conn.accLeaf[0][1]));
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Incoming()(conn.tokenLeaf[0][0], enabled, matched_amt1 - feeFromTarget), conn.tokenLeaf[0][1]);
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Unlock()(TokenLeaf_Deduct()(conn.tokenLeaf[1][0], enabled, matched_amt0 + feeFromLocked), enabled, refund), conn.tokenLeaf[1][1]);

    // AM-6. Charge the fee from the lender
    // SLI-23. Charge the maker fee
    // SMI-15. Charge the maker's fee
    ImplyEq()(enabledAndIsAuction, conn.feeLeafId[0], ori_order1_req.tokenId);
    ImplyEq()(And()(enabled, Or()(isSecondaryLimit, isSecondaryMarket)), conn.feeLeafId[0], Mux(2)([ori_order1_req.tokenId, ori_order1_req.arg[4]/*target token id*/], ori_order1_req.arg[8]/*side*/));
    ImplyEqArr(LenOfFeeLeaf())(enabled, FeeLeaf_Incoming()(conn.feeLeaf[0][0], enabled, fee), conn.feeLeaf[0][1]);
    
    // AS-0. Specifies a market, considering all orders within it
    // SLI-16. Include all orders in this market to process
    // SMI-8. Include all orders in this market to process
    //      Check that both orders contain the same tSBToken token
    ImplyEq()(enabledAndIsAuction, tSBToken.baseTokenId, ori_order1_req.tokenId);
    ImplyEq()(enabledAndIsAuction, tSBToken.maturity, ori_order1_req.arg[1]/*maturity time*/);
    ImplyEq()(And()(enabled, Or()(isSecondaryLimit, isSecondaryMarket)), conn.tSBTokenLeafId[0], Mux(2)([ori_order1_req.arg[4]/*target token id*/, ori_order1_req.tokenId], ori_order1_req.arg[8]/*side*/));
    ImplyEq()(enabledAndIsAuction, conn.tokenLeafId[0], conn.tSBTokenLeafId[0]);
    ImplyEqArr(LenOfTSBTokenLeaf())(enabled, conn.tSBTokenLeaf[0][0], conn.tSBTokenLeaf[0][1]);
    
    // AM-5. Perform Interact operation on the specified borrow and lend orders
    // SLI-20. Perform Interaction with the matched buyer's orders and seller's orders
    // SMI-12. Perform Interact on the specified buy order and sell order
    ImplyEqArr(LenOfOrderLeaf())(enabled, OrderLeaf_DefaultIf()(newNewOrder1, isFull), conn.orderLeaf[0][1]);

    // AB-2. Check if borrowingAmt, feeRate, collateralAmt, PIR can be converted to floating point numbers
    // AL-2. Check if lendingAmt, feeRate, defaultPIR can be converted to floating point numbers
    // SL-2. Check if MQ, BQ, feeRate can be converted to floating point numbers
    // SM-2. Check if MQ, BQ, makerFeeRate, takerFeeRate can be converted to floating point numbers
    signal packedAmt1 <== Fix2FloatCond()(enabled, ori_order1_req.arg[5]/*target amount*/);

    Chunkify(2, [FmtOpcode(), FmtTxOffset()])(enabledAndIsAuction, p_req.chunks, [req.opType, conn.txId - ori_order1.txId]);
    Chunkify(2, [FmtOpcode(), FmtTxOffset()])(And()(enabled, Or()(isSecondaryLimit, isSecondaryMarket)), p_req.chunks, [req.opType, conn.txId - ori_order1.txId]);

    signal channelOutIfAuction[LenOfChannel()] <== Channel_New()(newBorrow, [channel_in.args[0]/*oriCumAmt0*/, channel_in.args[1]/*oricumamt1*/, channel_in.args[2], ori_order1_req.arg[3]/*PIR*/, 0]);
    signal channelOutIfSecondary[LenOfChannel()] <== Channel_New()(newTaker, [channel_in.args[0]/*oriCumAmt0*/, channel_in.args[1]/*oricumamt1*/, channel_in.args[2], 0, 0]);
    channelOut <== Multiplexer(LenOfChannel(), 2)([channelOutIfSecondary, channelOutIfAuction], isAuction);
}


/*
    This template is used to verify AuctionEnd (AE), SecondLimitEnd (SLE) requests.

    Items that require verification for AuctionEnd:
    AE-11. If the borrow order has no more matches in this round, check that matched borrowing amount > fee
    AE-12. If the borrow order has no more matches in this round, distribute the matched loan to borrower	
    AE-13. If the borrow order has no more matches in this round, calculate the fee to charge the borrower	
    AE-14. If the borrow order has no more matches in this round, deduct the collateral amount in the matched orders from the total locked collateral amount	
    AE-15. If the borrow order has no more matches in this round, the Backend constructs L2 admin request: AuctionEnd
        *   Validate the signature in template: DoRequest()
        *   In this template, read request based on this format.
    AE-16. If the borrow order is completed, return the remaining locked amount in the borrow order

    Items that require verification for SecondLimitEnd:
    SLE-26.If there is no more maker to match with a taker and if the taker is a seller, check if matchedBQ is greater than or equal to the taker's fees	
    SLE-27.If there is no more maker to match with a taker, charge fee from the taker		
    SLE-28.If there is no more maker to match with a taker, and if the taker's order has been completed, return the remaining locked amount in the order		
    SLE-29.If there is no more maker to match with a taker, the Backend constructs L2 admin request: SecondLimitEnd
        *   Validate the signature in template: DoRequest()
        *   In this template, read request based on this format.
    SLE-30.If there is no more maker to match with a taker, add the taker to the maker list

*/
template DoReqEnd(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(1, 1, 1, 1, 0, 2, 0, 0);// Update fee leaf, tSBToken leaf, order leaf, acc leaf once and token leaf twice
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);
    component tSBToken = TSBTokenLeaf();
    tSBToken.arr <== conn.tSBTokenLeaf[0][0];
    component channel_in = Channel();
    channel_in.arr <== channelIn;
    component order = OrderLeaf();
    order.arr <== channel_in.orderLeaf;
    component order_req = Req();
    order_req.arr <== order.req;
    
    signal isAuction <== TagIsEqual()([req.opType, OpTypeNumAuctionEnd()]);
    signal isSecondaryLimit <== TagIsEqual()([req.opType, OpTypeNumSecondLimitEnd()]);
    signal isSecondaryMarket <== TagIsEqual()([req.opType, OpTypeNumSecondMarketEnd()]);
    
    /* Calc fee */
    // There are two ways to collect fees.
    //      One is deducted from the money originally locked. (feeFromLocked)
    //      The other is deducted from the money obtained this time. (feeFromTarget)
    signal feeFromLocked, feeFromTarget, fee;
    (feeFromLocked, feeFromTarget, fee) <== CalcFee()(order.arr, enabled, channel_in.args[0]/*oriCumAmt0*/, channel_in.args[1]/*oricumamt1*/, p_req.matchedTime[0], tSBToken.maturity,  Mux(2)([0, channel_in.args[2]], isAuction));
    
    var matched_amt0 = order.cumAmt0 - channel_in.args[0]/*oriCumAmt0*/;
    var matched_amt1 = order.cumAmt1 - channel_in.args[1]/*oricumamt1*//*oriCumAmt0*/;

    signal enabledAndIsAuction <== And()(enabled, isAuction);

    /* legality */
    
    // AS-3. Check if the borrow order with the highest priority matches with the lend order or not. If not, exclude this borrow order and repeat step 2
    ImplyEq()(enabledAndIsAuction, order_req.opType, OpTypeNumAuctionBorrow());
    
    // SLI-19. Check if a maker with the highest priority matches his/her orders or not
    ImplyEq()(And()(enabled, isSecondaryLimit), order_req.opType, OpTypeNumSecondLimitOrder());
    
    // AM-5. Perform Interact operation on the specified borrow and lend orders
    //   This step esures that matchedPIR is correct
    ImplyEq()(enabledAndIsAuction, channel_in.args[2], channel_in.args[3]);
    
    // AS-4. If a new borrow order is processed in a matching round, Backend constructs L2 admin request: AuctionStart
    // SSS-15. Backend constructs L2 admin request: SecondLimitStart
    //      We will reinsert the order into order tree, check if it's a empty order leaf.
    ImplyEqArr(LenOfOrderLeaf())(enabled, OrderLeaf_Default()(), conn.orderLeaf[0][0]);

    // AE-11. If the borrow order has no more matches in this round, check that matched borrowing amount > fee
    // SLE-26.If there is no more maker to match with a taker and if the taker is a seller, check if matchedBQ is greater than or equal to the taker's fees	
    ImplyEq()(enabled, 1, TagLessEqThan(BitsAmount())([feeFromTarget, matched_amt1]));

    // Ensure that the matched time of the order does not differ from the current time (rollup time) by more than one day.
    ImplyEq()(enabled, 1, TagLessEqThan(BitsTime())([p_req.matchedTime[0], currentTime]));
    ImplyEq()(enabled, 1, TagLessThan(BitsTime())([currentTime - p_req.matchedTime[0], ConstSecondsPerDay()]));

    /* correctness */

    // AE-12. If the borrow order has no more matches in this round, distribute the matched loan to borrower	
    // AE-13. If the borrow order has no more matches in this round, calculate the fee to charge the borrower	
    // AE-14. If the borrow order has no more matches in this round, deduct the collateral amount in the matched orders from the total locked collateral amount	
    // AE-16. If the borrow order is completed, return the remaining locked amount in the borrow order
    // SLE-27.If there is no more maker to match with a taker, charge fee from the taker
    // SLE-28.If there is no more maker to match with a taker, and if the taker's order has been completed, return the remaining locked amount in the order
    assert(BitsAmount() + 1 <= ConstFieldBits());
    signal newOrder[LenOfOrderLeaf()] <== OrderLeaf_DeductLockedAmt()(order.arr, enabled, feeFromLocked + matched_amt0);
    signal isFull <== OrderLeaf_IsFull()(newOrder);
    component new_order = OrderLeaf();
    new_order.arr <== newOrder;
    signal refund <== isFull * new_order.lockedAmt;
    ImplyEq()(enabled, conn.accLeafId[0], order_req.accId);
    ImplyEq()(enabled, conn.tokenLeafId[0], order_req.arg[4]/*target token id*/);
    ImplyEq()(enabled, conn.tokenLeafId[1], order_req.tokenId);
    ImplyEqArr(LenOfAccLeaf())(enabled, AccLeaf_MaskTokens()(conn.accLeaf[0][0]), AccLeaf_MaskTokens()(conn.accLeaf[0][1]));
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Incoming()(conn.tokenLeaf[0][0], enabled, matched_amt1 - feeFromTarget), conn.tokenLeaf[0][1]);
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Unlock()(TokenLeaf_Deduct()(conn.tokenLeaf[1][0], enabled, matched_amt0 + feeFromLocked), enabled, refund), conn.tokenLeaf[1][1]);

    // AE-13. If the borrow order has no more matches in this round, calculate the fee to charge the borrower	
    // SLE-27.If there is no more maker to match with a taker, charge fee from the taker
    ImplyEq()(enabledAndIsAuction, conn.feeLeafId[0], order_req.arg[4]/*target token id*/);
    ImplyEq()(And()(enabled, isSecondaryLimit), conn.feeLeafId[0], Mux(2)([order_req.tokenId, order_req.arg[4]/*target token id*/], order_req.arg[8]/*side*/));
    ImplyEqArr(LenOfOrderLeaf())(enabled, OrderLeaf_DefaultIf()(newOrder, isFull), conn.orderLeaf[0][1]);
    ImplyEqArr(LenOfFeeLeaf())(enabled, FeeLeaf_Incoming()(conn.feeLeaf[0][0], enabled, fee), conn.feeLeaf[0][1]);
    
    
    // AS-4. If a new borrow order is processed in a matching round, Backend constructs L2 admin request: AuctionStart
    // SSS-15. Backend constructs L2 admin request: SecondLimitStart
    // SLE-30.If there is no more maker to match with a taker, add the taker to the maker list
    //      reinsert the order into order tree
    ImplyEq()(enabledAndIsAuction, tSBToken.baseTokenId, order_req.arg[4]/*target token id*/);
    ImplyEq()(enabledAndIsAuction, tSBToken.maturity, order_req.arg[1]/*maturity time*/);
    ImplyEq()(And()(enabled, isSecondaryLimit), conn.tSBTokenLeafId[0], Mux(2)([order_req.arg[4]/*target token id*/, order_req.tokenId], order_req.arg[8]/*side*/));
    ImplyEqArr(LenOfTSBTokenLeaf())(enabled, conn.tSBTokenLeaf[0][0], conn.tSBTokenLeaf[0][1]);

    signal debtAmtIfAuction <== AuctionCalcDebtAmt()(channel_in.args[2], matched_amt1, DaysFrom()(p_req.matchedTime[0], tSBToken.maturity));
    Chunkify(7, [FmtOpcode(), FmtAccId(), FmtTokenId(), FmtStateAmount(), FmtTokenId(), FmtStateAmount(), FmtTime()])(enabledAndIsAuction, p_req.chunks, [req.opType, order_req.accId, order_req.tokenId, matched_amt0, conn.tSBTokenLeafId[0], debtAmtIfAuction, p_req.matchedTime[0]]);
    Chunkify(2, [FmtOpcode(), FmtTime()])(And()(enabled, isSecondaryLimit), p_req.chunks, [req.opType, p_req.matchedTime[0]]);

    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}

/*
    This template is used to verify SecondMarketEnd requests.

    Items that require verification:
    SME-18. If there is no maker matched with the taker, and if the taker is a seller, check if matchedBQ is greater than or equal to the taker's fee
    SME-19. If there is no maker matched with the taker, charge the taker fee
    SME-20. If there is no maker matched with the taker, and if the taker order is completed, return the remaining locked amount in the taker order
    SME-21. If there is no maker matched with the taker, the Backend constructs L2 admin request: SecondMarketEnd
        *   Validate the signature in template: DoRequest()
        *   In this template, read request based on this format.

*/
template DoReqSecondMarketEnd(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(1, 1, 0, 1, 0, 2, 0, 0);// Update fee leaf, tSBToken leaf, acc leaf once and token leaf twice
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);
    component tSBToken = TSBTokenLeaf();
    tSBToken.arr <== conn.tSBTokenLeaf[0][0];
    component channel_in = Channel();
    channel_in.arr <== channelIn;
    component order = OrderLeaf();
    order.arr <== channel_in.orderLeaf;
    component order_req = Req();
    order_req.arr <== order.req;
    
    signal feeFromLocked, feeFromTarget, fee;
    (feeFromLocked, feeFromTarget, fee) <== CalcFee()(order.arr, enabled, channel_in.args[0]/*oriCumAmt0*/, channel_in.args[1]/*oricumamt1*/, p_req.matchedTime[0], tSBToken.maturity, channel_in.args[2]);
    
    var matched_amt0 = order.cumAmt0 - channel_in.args[0]/*oriCumAmt0*/;
    var matched_amt1 = order.cumAmt1 - channel_in.args[1]/*oricumamt1*/;

    /* legality */

    // SMI-11. Check if a maker with the highest priority matches his/her orders or not
    ImplyEq()(enabled, order_req.opType, OpTypeNumSecondMarketOrder());

    // EME-20. If there is no maker matched with the taker, and if the taker is a seller, check if matchedBQ is greater than or equal to the taker's fee
    ImplyEq()(enabled, 1, TagLessEqThan(BitsAmount())([feeFromTarget, matched_amt1]));
    
    // SM-7. If it's a buy order, check if there is enough BQ in the wallet
    TokenLeaf_SufficientCheck()(conn.tokenLeaf[1][0], enabled, matched_amt0 + feeFromLocked);
    
    // Ensure that the matched time of the order does not differ from the current time (rollup time) by more than one day.
    ImplyEq()(enabled, 1, TagLessEqThan(BitsTime())([p_req.matchedTime[0], currentTime]));
    ImplyEq()(enabled, 1, TagLessThan(BitsTime())([currentTime - p_req.matchedTime[0], ConstSecondsPerDay()]));

    /* correctness */
    
    // SME-19. If there is no maker matched with the taker, charge the taker fee
    // SME-20. If there is no maker matched with the taker, and if the taker order is completed, return the remaining locked amount in the taker order
    ImplyEq()(enabled, conn.accLeafId[0], order_req.accId);
    ImplyEq()(enabled, conn.tokenLeafId[0], order_req.arg[4]/*target token id*/);
    ImplyEq()(enabled, conn.tokenLeafId[1], order_req.tokenId);
    ImplyEqArr(LenOfAccLeaf())(enabled, AccLeaf_MaskTokens()(conn.accLeaf[0][0]), AccLeaf_MaskTokens()(conn.accLeaf[0][1]));
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Incoming()(conn.tokenLeaf[0][0], enabled, matched_amt1 - feeFromTarget), conn.tokenLeaf[0][1]);
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Outgoing()(conn.tokenLeaf[1][0], enabled, matched_amt0 + feeFromLocked), conn.tokenLeaf[1][1]);

    // SME-19. If there is no maker matched with the taker, charge the taker fee
    ImplyEq()(enabled, conn.feeLeafId[0], Mux(2)([order_req.tokenId, order_req.arg[4]/*target token id*/], order_req.arg[8]/*side*/));
    ImplyEqArr(LenOfFeeLeaf())(enabled, FeeLeaf_Incoming()(conn.feeLeaf[0][0], enabled, fee), conn.feeLeaf[0][1]);
    
    // AS-0. Specifies a market, considering all orders within it
    // SLI-16. Include all orders in this market to process
    // SMI-8. Include all orders in this market to process
    //      Check that both orders contain the same tSBToken token
    ImplyEq()(enabled, conn.tSBTokenLeafId[0], Mux(2)([order_req.arg[4]/*target token id*/, order_req.tokenId], order_req.arg[8]/*side*/));
    ImplyEqArr(LenOfTSBTokenLeaf())(enabled, conn.tSBTokenLeaf[0][0], conn.tSBTokenLeaf[0][1]);

    Chunkify(2, [FmtOpcode(), FmtTime()])(enabled, p_req.chunks, [req.opType, p_req.matchedTime[0]]);

    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}

/*
    This template is used to verify AdminCancel requests.

    Items that require verification:
    0. Backend deletes a specified order
    1. Backend constructs L2 admin request: AdminCancel
        *   Validate the signature in template: DoRequest()
        *   In this template, read request based on this format.
    2. Backend updates the token leaf

*/
template DoReqAdminCancel(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(0, 0, 1, 1, 0, 1, 0, 0);// Update fee leaf, order leaf, acc leaf once and token leaf once
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);
    component order = OrderLeaf();
    order.arr <== conn.orderLeaf[0][0];
    component o_req = Req();
    o_req.arr <== order.req;

    /* correctness */

    // 2. Backend updates the token leaf
    ImplyEq()(enabled, conn.accLeafId[0], o_req.accId);
    ImplyEq()(enabled, conn.tokenLeafId[0], o_req.tokenId);
    ImplyEqArr(LenOfAccLeaf())(enabled, AccLeaf_MaskTokens()(conn.accLeaf[0][0]), AccLeaf_MaskTokens()(conn.accLeaf[0][1]));
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Unlock()(conn.tokenLeaf[0][0], enabled, order.lockedAmt), conn.tokenLeaf[0][1]);

    // 0. Backend deletes a specified order
    ImplyEqArr(LenOfOrderLeaf())(enabled, OrderLeaf_Default()(), conn.orderLeaf[0][1]);

    Chunkify(2, [FmtOpcode(), FmtTxId()])(enabled, p_req.chunks, [req.opType, order.txId]);

    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}

/*
    This template is used to verify UserCancel requests.

    Items that require verification:
    0. Backend receives a signed L2 user request: UserCancel from a user
        *   Validate the signature in template: DoRequest()
        *   In this template, read request based on this format.
    1. Search an order matching the order hash in the request
    2. Check if the sender ID in the order matches the sender ID in the request
    3. Backend checks if the sender has enough balance for the fee
    4. Backend deletes a specified order
    5. Backend updates the token leaf

*/
template DoReqUserCancel(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(1, 0, 1, 1, 0, 2, 0, 0);// Update order leaf, acc leaf once and token leaf once
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);
    component order = OrderLeaf();
    order.arr <== conn.orderLeaf[0][0];
    component o_req = Req();
    o_req.arr <== order.req;

    /* legality */

    // 2. Check if the sender ID in the order matches the sender ID in the request
    ImplyEq()(enabled, req.accId, o_req.accId);

    // 3. Backend checks if the sender has enough balance for the fee
    TokenLeaf_SufficientCheck()(conn.tokenLeaf[1][0], enabled, req.txFeeAmt);

    /* correctness */
    
    // 5. Backend updates the token leaf
    ImplyEq()(enabled, conn.accLeafId[0], o_req.accId);
    ImplyEq()(enabled, conn.tokenLeafId[0], o_req.tokenId);
    ImplyEq()(enabled, conn.tokenLeafId[1], req.txFeeTokenId);
    ImplyEqArr(LenOfAccLeaf())(enabled, AccLeaf_MaskTokens()(conn.accLeaf[0][0]), AccLeaf_MaskTokens()(conn.accLeaf[0][1]));
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Unlock()(conn.tokenLeaf[0][0], enabled, order.lockedAmt), conn.tokenLeaf[0][1]);
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Outgoing()(conn.tokenLeaf[1][0], enabled, req.txFeeAmt), conn.tokenLeaf[1][1]);

    ImplyEq()(enabled, conn.feeLeafId[0], req.txFeeTokenId);
    ImplyEqArr(LenOfFeeLeaf())(enabled, FeeLeaf_Incoming()(conn.feeLeaf[0][0], enabled, req.txFeeAmt), conn.feeLeaf[0][1]);
    
    // 1. Search an order matching the order hash in the request
    ImplyEq()(enabled, Req_Digest()(order.req), req.arg[10]/*order hash*/);

    // 4. Backend deletes a specified order
    ImplyEqArr(LenOfOrderLeaf())(enabled, OrderLeaf_Default()(), conn.orderLeaf[0][1]);

    signal packedTxFeeAmt <== Fix2FloatCond()(enabled, req.txFeeAmt);
    Chunkify(4, [FmtOpcode(), FmtTxId(), FmtTokenId(), FmtPacked()])(enabled, p_req.chunks, [req.opType, order.txId, req.txFeeTokenId, packedTxFeeAmt]);

    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}

/*
    This template is used to verify SetAdminTsAddr requests.

    Items that require verification:
    0. Backend constructs L2 admin request: SetAdminTsAddr
        *   Validate the signature in template: DoRequest()
        *   In this template, read request based on this format.
    1. Backend updates Admin TS Addr

*/
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

    // 1. Backend updates Admin TS Addr
    ImplyEq()(enabled, conn.adminTsAddr[1], req.arg[6]/*ts-addr*/);

    Chunkify(1, [FmtOpcode()])(enabled, p_req.chunks, [req.opType]);

    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}

/*
    This template is used to verify IncreaseEpoch requests.

    Items that require verification:
    0. Backend constructs L2 admin request: IncreaseEpoch
        *   Validate the signature in template: DoRequest()
        *   In this template, read request based on this format.
    1. Backend updates the Nullifier Tree

*/
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

    // 2. Backend updates the Nullifier Tree
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

/*
    This template is used to verify CreateTSBToken requests.

    Items that require verification:
    0. Backend constructs L1 request: CreateTsbToken
        *   Validate the signature in template: DoRequest()
        *   In this template, read request based on this format.
    2. Backend checks if maturity is within 80 * 365 days
    3. Backend updates TSB token leaf

*/
template DoReqCreateTSBToken(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(0, 1, 0, 0, 0, 0, 0, 0);// Update tSBToken leaf once
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);
    component tSBToken = TSBTokenLeaf();
    tSBToken.arr <== conn.tSBTokenLeaf[0][1];

    var upper_lim_of_days = 365 * 80;

    /* legality */

    // Ensure that the matched time of the order does not differ from the current time (rollup time) by more than one day.
    ImplyEq()(enabled, 1, TagLessEqThan(BitsTime())([p_req.matchedTime[0], currentTime]));
    ImplyEq()(enabled, 1, TagLessThan(BitsTime())([currentTime - p_req.matchedTime[0], ConstSecondsPerDay()]));

    // 2. Backend checks if maturity is within 80 * 365 days
    ImplyEq()(enabled, 1, TagGreaterThan(BitsTime())([p_req.matchedTime[0] + 86400 * upper_lim_of_days, tSBToken.maturity]));

    /* correctness */

    // 3. Backend updates TSB token leaf
    ImplyEq()(enabled, conn.tSBTokenLeafId[0], req.tokenId);
    ImplyEq()(enabled, tSBToken.baseTokenId, req.arg[4]/*base token id*/);
    ImplyEq()(enabled, tSBToken.maturity, req.arg[1]/*maturity time*/);

    Chunkify(4, [FmtOpcode(), FmtTime(), FmtTokenId(), FmtTokenId()])(enabled, p_req.chunks, [req.opType, tSBToken.maturity, tSBToken.baseTokenId, conn.tSBTokenLeafId[0]]);
    
    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}

/*
    This template is used to verify Redeem requests.

    Items that require verification:
    0. Backend receives a signed L2 user request: Redeem from a user
        *   Validate the signature in template: DoRequest()
        *   In this template, read request based on this format.
    1. Backend checks if the sender has enough balance
    2. Backend checks if the nonce is correct
    3. Backend searches maturity time
    4. Backend checks if the currentTime exceeds maturityTime
    5. Backend updates the sender's account leaf and token leaves
*/
template DoReqRedeem(){
    signal input {bool} enabled;
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()];

    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req = Req();
    req.arr <== p_req.req;
    component conn = Conn(0, 1, 0, 1, 0, 2, 0, 0);// Update tSBToken leaf, acc leaf once and token leaf twice
    (conn.enabled, conn.oriState, conn.newState, conn.unitSet, conn.nullifierTreeId) <== (enabled, oriState, newState, p_req.unitSet, p_req.nullifierTreeId[0]);
    component tSBToken = TSBTokenLeaf();
    tSBToken.arr <== conn.tSBTokenLeaf[0][0];

    /* legality */

    // 2. Backend checks if the nonce is correct
    AccLeaf_NonceCheck()(conn.accLeaf[0][0], enabled, req.nonce);

    // 1. Backend checks if the sender has enough balance
    TokenLeaf_SufficientCheck()(conn.tokenLeaf[0][0], enabled, req.amount);

    // 4. Backend checks if the currentTime exceeds maturityTime
    ImplyEq()(enabled, 1, TagGreaterThan(BitsTime())([currentTime, tSBToken.maturity]));

    /* correctness */

    // 3. Backend searches maturity time
    ImplyEq()(enabled, conn.tSBTokenLeafId[0], req.tokenId);
    ImplyEqArr(LenOfTSBTokenLeaf())(enabled, conn.tSBTokenLeaf[0][0], conn.tSBTokenLeaf[0][1]);

    // 5. Backend updates the sender's account leaf and token leaves
    ImplyEq()(enabled, conn.accLeafId[0], req.accId);
    ImplyEq()(enabled, conn.tokenLeafId[0], req.tokenId);
    ImplyEq()(enabled, conn.tokenLeafId[1], tSBToken.baseTokenId);
    ImplyEqArr(LenOfAccLeaf())(enabled, AccLeaf_NonceIncrease()(AccLeaf_MaskTokens()(conn.accLeaf[0][0])), AccLeaf_MaskTokens()(conn.accLeaf[0][1]));
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Outgoing()(conn.tokenLeaf[0][0], enabled, req.amount), conn.tokenLeaf[0][1]);
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Incoming()(conn.tokenLeaf[1][0], enabled, req.amount), conn.tokenLeaf[1][1]);

    Chunkify(4, [FmtOpcode(), FmtAccId(), FmtTokenId(), FmtStateAmount()])(enabled, p_req.chunks, [req.opType, req.accId, req.tokenId, req.amount]);

    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}

/*
    This template is used to verify WithdrawFee requests.

    Items that require verification:
    0. Backend constructs L2 admin request: WithdrawFee
        *   Validate the signature in template: DoRequest()
        *   In this template, read request based on this format.
    1. Backend updates the fee leaf

*/
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

    // 1. Backend updates the fee leaf
    ImplyEq()(enabled, conn.feeLeafId[0], req.tokenId);
    ImplyEqArr(LenOfFeeLeaf())(enabled, conn.feeLeaf[0][1], [0]);

    Chunkify(3, [FmtOpcode(), FmtTokenId(), FmtStateAmount()])(enabled, p_req.chunks, [req.opType, req.tokenId, fee.amount]);

    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}

/*
    This template is used to verify Evacuation requests.

    Items that require verification:
    1. Backend constructs L1 requests: Evacuation
        *   Validate the signature in template: DoRequest()
        *   In this template, read request based on this format.
    2. Backend updates token leaf

*/
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

    // 2. Backend updates token leaf
    ImplyEq()(enabled, conn.accLeafId[0], req.arg[0]/*receiver id*/);
    ImplyEq()(enabled, conn.tokenLeafId[0], req.tokenId);
    ImplyEqArr(LenOfAccLeaf())(enabled, AccLeaf_MaskTokens()(conn.accLeaf[0][0]), AccLeaf_MaskTokens()(conn.accLeaf[0][1]));
    ImplyEqArr(LenOfTokenLeaf())(enabled, TokenLeaf_Outgoing()(conn.tokenLeaf[0][0], enabled, token.avl_amt + token.locked_amt), conn.tokenLeaf[0][1]);

    assert(BitsAmount() + 1 <= ConstFieldBits());
    Chunkify(4, [FmtOpcode(), FmtAccId(), FmtTokenId(), FmtStateAmount()])(enabled, p_req.chunks, [req.opType, conn.accLeafId[0], conn.tokenLeafId[0], token.avl_amt + token.locked_amt]);

    ImplyEqArr(LenOfChannel())(enabled, channelIn, Channel_Default()());
    for(var i = 0; i < LenOfChannel(); i++)
        channelOut[i] <== 0;
}
