pragma circom 2.1.5;

template AccLeaf_Register(){
    signal input accLeaf[LenOfAccLeaf()];
    signal input addr;

    component acc = AccLeaf();
    acc.arr <== accLeaf;

    signal output arr[LenOfAccLeaf()] <== [addr, acc.nonce, acc.tokens];
}
template AccLeaf_NonceIncrease(){
    signal input accLeaf[LenOfAccLeaf()];
    signal output arr[LenOfAccLeaf()] <== [accLeaf[0], accLeaf[1] + 1, accLeaf[2]];
}
template AccLeaf_MaskTokens(){
    signal input accLeaf[LenOfAccLeaf()];
    signal output arr[LenOfAccLeaf()] <== [accLeaf[0], accLeaf[1], 0];
}
template AccLeaf_EnforceDefault(){
    signal input accLeaf[LenOfAccLeaf()];
    signal input {bool} enabled;
    ImplyEq()(enabled, accLeaf[0], 0);
}
template AccLeaf_NonceCheck(){
    signal input accLeaf[LenOfAccLeaf()];
    signal input {bool} enabled;
    signal input nonce;
    ImplyEq()(enabled, accLeaf[1], nonce);
}