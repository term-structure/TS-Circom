pragma circom 2.1.2;

include "./src/const/_mod.circom";
include "./src/type/_mod.circom";
include "./src/gadgets/_mod.circom";
include "./src/request.circom";
include "../../node_modules/circomlib/circuits/sha256/sha256.circom";
include "../../node_modules/circomlib/circuits/eddsaposeidon.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";

function NumOfChunksForEvacuation(){
    return 2;
}
template CalcCommitment(){
    signal input oriStateRoot, newStateRoot, newTsRoot, currentTime, chunks[NumOfChunksForEvacuation()], isCriticalChunk[NumOfChunksForEvacuation()];
    signal output commitment;

    var bits_slot = 256;
    var target_len = bits_slot * 4 + (BitsChunk() + 8) * (NumOfChunksForEvacuation());
    signal target[5 + NumOfChunksForEvacuation() * 2][target_len];
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

    var bits_tag = 8;
    for(var i = 0; i < NumOfChunksForEvacuation(); i++){
        idx += bits_tag - 1;
        target[counter] <== Arr_CopyRange(target_len, idx, 1)(target[counter - 1], [isCriticalChunk[i]]);
        counter += 1;
        idx += 1;
    }

    for(var i = 0; i < NumOfChunksForEvacuation(); i++){
        target[counter] <== Arr_CopyRange(target_len, idx, BitsChunk())(target[counter - 1], Arr_Reverse(BitsChunk())(Num2Bits(BitsChunk())(chunks[i])));
        counter += 1;
        idx += BitsChunk();
    }

    commitment <== Bits2Num(256)(Arr_Reverse(256)(Sha256(target_len)(target[counter - 1])));
}
template Evacuation(){
    signal input stateRoot;
    signal input tsRoot;
    signal input accRoot;
    signal input accId;
    signal input tsAddr;
    signal input nonce;
    signal input tokenRoot;
    signal input tokenId;
    signal input avlAmt;
    signal input lockedAmt;
    signal input accMkPrf[AccTreeHeight()];
    signal input tokenMkPrf[TokenTreeHeight()];
    signal input currentTime;
    signal output commitment;

    signal expectedStateRoot <== Poseidon(2)([tsRoot, accRoot]);
    expectedStateRoot === stateRoot;
    VerifyExists(AccTreeHeight())(accId, PoseidonSpecificLen(LenOfAccLeaf())([tsAddr, nonce, tokenRoot]), accMkPrf, accRoot);
    VerifyExists(TokenTreeHeight())(tokenId, PoseidonSpecificLen(LenOfTokenLeaf())([avlAmt, lockedAmt]), tokenMkPrf, tokenRoot);

    signal bits_opType[1 * 8] <== Num2Bits(1 * 8)(OpTypeNumEvacuation());
    signal bits_accId[4 * 8] <== Num2Bits(4 * 8)(accId);
    signal bits_tokenId[2 * 8] <== Num2Bits(2 * 8)(tokenId);
    signal bits_amount[16 * 8] <== Num2Bits(16 * 8)(avlAmt + lockedAmt);

    signal bits_chunks[2* BitsChunk()];
    for(var i = 0; i < 1 * 8; i++)
        bits_chunks[i] <== bits_opType[1 * 8 - i - 1];
    for(var i = 0; i < 4 * 8; i++)
        bits_chunks[1 * 8 + i] <== bits_accId[4 * 8 - i - 1];
    for(var i = 0; i < 2 * 8; i++)
        bits_chunks[5 * 8 + i] <== bits_tokenId[2 * 8 - i - 1];
    for(var i = 0; i < 16 * 8; i++)
        bits_chunks[7 * 8 + i] <== bits_amount[16 * 8 - i - 1];
    for(var i = 23 * 8; i < 2 * BitsChunk(); i++)
        bits_chunks[i] <== 0;
    signal chunks[NumOfChunksForEvacuation()];
    var tmp[BitsChunk()];
    for(var i = 0; i < NumOfChunksForEvacuation(); i++){
        for(var j = 0; j < BitsChunk(); j++)
            tmp[j] = bits_chunks[BitsChunk() * (i + 1) - j - 1];
        chunks[i] <== Bits2Num(BitsChunk())(tmp);
    }
    commitment <== CalcCommitment()(
        stateRoot,
        stateRoot,
        tsRoot,
        currentTime,
        chunks,
        [1,0]
    );
}