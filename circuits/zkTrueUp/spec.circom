pragma circom 2.0.2;

function OrderTreeHeight(){
    return 8;
}
function AccTreeHeight(){
    return 10;
}
function TokenTreeHeight(){
    return 8;
}
function NullifierTreeHeight(){
    return 6;
}
function FeeTreeHeight(){
    return 3;
}
function NumOfReqs(){
    return 3;
}
function NumOfChunks(){
    return 32;
}

function DefaultNullifierRoot(){
    //This value is the Root of the Nullifier Tree in our published initial State Tree.
    return 12657967895078469224578163781222964703015536623478048995515841804870723496262;
}

function TSBTokenTreeHeight(){
    return TokenTreeHeight();
}

function MinChunksPerReq(){
    return 5;
}
function MaxOrderUnitsPerReq(){
    return 1;
}
function MaxAccUnitsPerReq(){
    return 2;
}
function MaxTokenUnitsPerReq(){
    return 2;
}
function MaxNullifierUnitsPerReq(){
    return 1;
}
function MaxFeeUnitsPerReq(){
    return 1;
}
function MaxTSBTokenUnitsPerReq(){
    return 1;
}
function MaxChunksPerReq(){
    return 9;
}