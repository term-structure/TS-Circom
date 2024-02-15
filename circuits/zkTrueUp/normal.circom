pragma circom 2.1.5;

include "./src/const/_mod.circom";
include "./src/type/_mod.circom";
include "./src/gadgets/_mod.circom";
include "./src/request.circom";
include "../../node_modules/circomlib/circuits/sha256/sha256.circom";
include "../../node_modules/circomlib/circuits/eddsaposeidon.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";

template DoRequest(){
    signal input currentTime, channelIn[LenOfChannel()], oriState[LenOfState()], newState[LenOfState()], preprocessedReq[LenOfPreprocessedReq()];
    signal output channelOut[LenOfChannel()], r_chunks[MaxChunksPerReq()], chunkCount, isNoopReq, isCriticalReq;

    component ori_state = State();
    ori_state.arr <== oriState;
    component new_state = State();
    new_state.arr <== newState;
    component p_req = PreprocessedReq();
    p_req.arr <== preprocessedReq;
    component req_ = Req();
    req_.arr <== p_req.req;

    r_chunks <== p_req.chunks;
    signal opType <== PreprocessedReq_GetOpType()(preprocessedReq);
    var const_chunk_count[OpTypeCount()] = ConstChunkCount();
    chunkCount <== Mux(OpTypeCount())(const_chunk_count, opType);
    isNoopReq <== IsEqual()([opType, OpTypeNumNoop()]);
    var const_is_critical_req[OpTypeCount()] = ConstIsCriticalReq();
    isCriticalReq <== Mux(OpTypeCount())(const_is_critical_req, opType);

    signal slt <== TagLessThan(BitsOpType())([opType, OpTypeCount()]);
    slt === 1;

    ori_state.txCount + 1 === new_state.txCount;

    var const_is_admin_req[OpTypeCount()] = ConstIsAdminReq();
    signal {bool} isAdminReq <== Bool()(Mux(OpTypeCount())(const_is_admin_req, opType));
    signal {bool} isAdminAddrDefault <== TagIsZero()(ori_state.adminTsAddr);
    signal tsAddr <== Sig_Verify()(p_req.sig, Or()(Not()(isAdminReq), Not()(isAdminAddrDefault)), Req_Digest()(p_req.req));
    
    ImplyEq()(isAdminReq, req_.accId, 0);
    ImplyEq()(And()(Not()(isAdminAddrDefault), isAdminReq), ori_state.adminTsAddr, tsAddr);
    ImplyEq()(Not()(isAdminReq), UnitSet_ExtractSignerTsAddr()(p_req.unitSet), tsAddr);

    UnitSet_Enforce()(p_req.unitSet);

    // Dispatch
    signal channel[OpTypeCount()][LenOfChannel()];
    channel[ 0] <== DoReqNoop                 ()(TagIsEqual()([opType, OpTypeNumNoop()])                 , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[ 1] <== DoReqRegister             ()(TagIsEqual()([opType, OpTypeNumRegister()])             , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[ 2] <== DoReqDeposit              ()(TagIsEqual()([opType, OpTypeNumDeposit()])              , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[ 3] <== DoReqForcedWithdraw       ()(TagIsEqual()([opType, OpTypeNumForcedWithdraw()])       , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[ 4] <== DoReqTransfer             ()(TagIsEqual()([opType, OpTypeNumTransfer()])             , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[ 5] <== DoReqWithdraw             ()(TagIsEqual()([opType, OpTypeNumWithdraw()])             , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[ 6] <== DoReqPlaceOrder           ()(TagIsEqual()([opType, OpTypeNumAuctionLend()])          , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[ 7] <== DoReqPlaceOrder           ()(TagIsEqual()([opType, OpTypeNumAuctionBorrow()])        , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[ 8] <== DoReqStart                ()(TagIsEqual()([opType, OpTypeNumAuctionStart()])         , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[ 9] <== DoReqInteract             ()(TagIsEqual()([opType, OpTypeNumAuctionMatch()])         , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[10] <== DoReqEnd                  ()(TagIsEqual()([opType, OpTypeNumAuctionEnd()])           , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[11] <== DoReqPlaceOrder           ()(TagIsEqual()([opType, OpTypeNumSecondLimitOrder()])     , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[12] <== DoReqStart                ()(TagIsEqual()([opType, OpTypeNumSecondLimitStart()])     , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[13] <== DoReqInteract             ()(TagIsEqual()([opType, OpTypeNumSecondLimitExchange()])  , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[14] <== DoReqEnd                  ()(TagIsEqual()([opType, OpTypeNumSecondLimitEnd()])       , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[15] <== DoReqSecondMarketOrder    ()(TagIsEqual()([opType, OpTypeNumSecondMarketOrder()])    , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[16] <== DoReqInteract             ()(TagIsEqual()([opType, OpTypeNumSecondMarketExchange()]) , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[17] <== DoReqSecondMarketEnd      ()(TagIsEqual()([opType, OpTypeNumSecondMarketEnd()])      , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[18] <== DoReqAdminCancel          ()(TagIsEqual()([opType, OpTypeNumAdminCancelOrder()])     , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[19] <== DoReqUserCancel           ()(TagIsEqual()([opType, OpTypeNumUserCancelOrder()])      , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[20] <== DoReqIncreaseEpoch        ()(TagIsEqual()([opType, OpTypeNumIncreaseEpoch()])        , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[21] <== DoReqCreateTSBToken       ()(TagIsEqual()([opType, OpTypeNumCreateTSBToken()])       , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[22] <== DoReqRedeem               ()(TagIsEqual()([opType, OpTypeNumRedeem()])               , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[23] <== DoReqWithdrawFee          ()(TagIsEqual()([opType, OpTypeNumWithdrawFee()])          , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[24] <== DoReqEvacuation           ()(TagIsEqual()([opType, OpTypeNumEvacuation()])           , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[25] <== DoReqSetAdminTsAddr       ()(TagIsEqual()([opType, OpTypeNumSetAdminTsAddr()])       , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[26] <== DoReqRollBorrowOrder      ()(TagIsEqual()([opType, OpTypeNumRollBorrowOrder()])      , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[27] <== DoReqRollOverStart        ()(TagIsEqual()([opType, OpTypeNumRollOverStart()])        , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[28] <== DoReqInteract             ()(TagIsEqual()([opType, OpTypeNumRollOverMatch()])        , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[29] <== DoReqRollOverEnd          ()(TagIsEqual()([opType, OpTypeNumRollOverEnd()])          , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[30] <== DoReqCancelRollOrder      ()(TagIsEqual()([opType, OpTypeNumUserCancelRollOrder()])  , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[31] <== DoReqCancelRollOrder      ()(TagIsEqual()([opType, OpTypeNumAdminCancelRollOrder()]) , currentTime, channelIn, oriState, newState, preprocessedReq);
    channel[32] <== DoReqCancelRollOrder      ()(TagIsEqual()([opType, OpTypeNumForceCancelRollOrder()]) , currentTime, channelIn, oriState, newState, preprocessedReq);

    channelOut <== Multiplexer(LenOfChannel(), OpTypeCount())(channel, opType);
}
template CalcCommitment(){
    signal input oriStateRoot, newStateRoot, newTsRoot, currentTime, chunks[NumOfChunks()], isCriticalChunk[NumOfChunks()];
    signal output commitment;

    var bits_slot = 256;
    var bits_tag = 1;
    assert((bits_tag * NumOfChunks()) % 8 == 0);
    var target_len = bits_slot * 4 + (BitsChunk() + bits_tag) * (NumOfChunks());
    signal target[5 + NumOfChunks() * 2][target_len];
    var idx = 0;
    var counter = 0;
    assert(ConstFieldBitsFull() <= bits_slot);

    target[counter] <== Arr_Zero(target_len)();
    counter += 1;

    var slots[4]= [oriStateRoot, newStateRoot, newTsRoot, currentTime];
    for(var i = 0; i < 4; i++){
        idx += bits_slot - ConstFieldBitsFull();
        target[counter] <== Arr_CopyRange(target_len, idx, ConstFieldBitsFull())(target[counter - 1], Arr_Reverse(ConstFieldBitsFull())(Num2Bits_strict()(slots[i])));
        counter += 1;
        idx += ConstFieldBitsFull();
    }

    for(var i = 0; i < NumOfChunks(); i++){
        idx += bits_tag - 1;
        target[counter] <== Arr_CopyRange(target_len, idx, 1)(target[counter - 1], [isCriticalChunk[i]]);
        counter += 1;
        idx += 1;
    }

    for(var i = 0; i < NumOfChunks(); i++){
        target[counter] <== Arr_CopyRange(target_len, idx, BitsChunk())(target[counter - 1], Arr_Reverse(BitsChunk())(Num2Bits(BitsChunk())(chunks[i])));
        counter += 1;
        idx += BitsChunk();
    }

    commitment <== Bits2Num(256)(Arr_Reverse(256)(Sha256(target_len)(target[counter - 1])));
}
template Normal(){
    signal input currentTime;
    signal input state[NumOfReqs() + 1][LenOfState()];
    signal input preprocessedReq[NumOfReqs()][LenOfPreprocessedReq()];
    signal input isCriticalChunk[NumOfChunks()];
    signal input o_chunks[NumOfChunks()];
    signal output commitment;

    signal channelData[NumOfReqs() + 1][LenOfChannel()];
    signal r_chunks[NumOfReqs()][MaxChunksPerReq()];
    signal chunkCount[NumOfReqs()];
    signal cumChunkCount[NumOfReqs() + 1];
    signal isNoopReq[NumOfReqs()];
    signal isCriticalReq[NumOfReqs()];
    signal chunkMasks[NumOfReqs()][MaxChunksPerReq()];

    // Parameter Allocation: only signals that have been allocated can be correctly placed into the comparator
    for(var i = 0; i < NumOfReqs() + 1; i++)
        _ <== State_Alloc()(state[i]);
    for(var i = 0; i < NumOfReqs(); i++)
        _ <== PreprocessedReq_Alloc()(preprocessedReq[i]);

    channelData[0] <== Channel_Default()();
    cumChunkCount[0] <== 0;
    for(var i = 0; i < NumOfReqs(); i++){
        // Request Execution
        log("i= ", i);
        (channelData[i + 1], r_chunks[i], chunkCount[i], isNoopReq[i], isCriticalReq[i]) <== DoRequest()(currentTime, channelData[i], state[i], state[i + 1], preprocessedReq[i]);
        
        // Perform cumulative addition on chunkCount
        cumChunkCount[i + 1] <== cumChunkCount[i] + chunkCount[i];
        
        // Handling Remaining Requests: Each req following an noop must also be noop.
        if(i > 1)
            ImplyEq()(isNoopReq[i - 1], isNoopReq[i], 1);

        // Chunk Packing: Interface btwn r_chunks and o_chunks
        for(var j = 0; j < MaxChunksPerReq(); j++){
            chunkMasks[i][j] <== TagLessThan(log2(MaxChunksPerReq()))([j, chunkCount[i]]);
            Indexer(NumOfChunks())(chunkMasks[i][j], r_chunks[i][j], cumChunkCount[i] + j, o_chunks);
            if(j == 0)
                Indexer(NumOfChunks())(chunkMasks[i][j], isCriticalReq[i], cumChunkCount[i] + j, isCriticalChunk);
            else
                Indexer(NumOfChunks())(chunkMasks[i][j], 0, cumChunkCount[i] + j, isCriticalChunk);
        }
    }
    ImplyEqArr(LenOfChannel())(1, channelData[NumOfReqs()], Channel_Default()());

    // Request and Chunk Handling: Each chunk following an noop must also be noop. Noop is not the critical chunk.
    signal isDefaultChunk[NumOfChunks()];
    for(var i = 0; i < NumOfChunks(); i++){
        isDefaultChunk[i] <== TagLessEqThan(log2(NumOfChunks()))([cumChunkCount[NumOfReqs()], i]);
        ImplyEq()(isDefaultChunk[i], o_chunks[i], 0);
        ImplyEq()(isDefaultChunk[i], isCriticalChunk[i], 0);
    }

    // Commitment Calculation
    signal (oriStateRoot, oriTsRoot) <== State_GetDigest()(state[0]);
    signal (newStateRoot, newTsRoot) <== State_GetDigest()(state[NumOfReqs()]);
    commitment <== CalcCommitment()(oriStateRoot, newStateRoot, newTsRoot, currentTime, o_chunks, isCriticalChunk);
}