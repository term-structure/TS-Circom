pragma circom 2.0.2;

function OrderTreeHeight(){
    return 24;
}
function AccTreeHeight(){
    return 32;
}
function TokenTreeHeight(){
    return 16;
}
function NullifierTreeHeight(){
    return 24;
}
function FeeTreeHeight(){
    return 16;
}
function NumOfReqs(){
    return 256;
}
function NumOfChunks(){
    return 1024;
}

function DefaultNullifierRoot(){
    //This value is the Root of the Nullifier Tree in our published initial State Tree.
    return 17442189262588877922573347453104862303711672093150317392397950911190231782258;
}

function TSBTokenTreeHeight(){
    return 16;
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
