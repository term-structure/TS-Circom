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
    return 18012398889380698404717924600148162801214704165566367634751429990523171457715;
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