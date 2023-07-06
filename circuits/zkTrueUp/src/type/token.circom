pragma circom 2.1.5;

template TokenLeaf_Incoming(){
    signal input tokenLeaf[LenOfTokenLeaf()];
    signal input enabled;
    signal input amount;
    _ <== Num2Bits(BitsUnsignedAmt())(amount * enabled);
    signal output arr[LenOfTokenLeaf()] <== TokenLeaf_Alloc()([(tokenLeaf[0] + amount) * enabled, tokenLeaf[1] * enabled]);
}
template TokenLeaf_Outgoing(){
    signal input tokenLeaf[LenOfTokenLeaf()];
    signal input enabled;
    signal input amount;
    _ <== Num2Bits(BitsUnsignedAmt())(amount * enabled);
    signal output arr[LenOfTokenLeaf()] <== TokenLeaf_Alloc()([(tokenLeaf[0] - amount) * enabled, tokenLeaf[1] * enabled]);
}
template TokenLeaf_Lock(){
    signal input tokenLeaf[LenOfTokenLeaf()];
    signal input enabled;
    signal input amount;
    _ <== Num2Bits(BitsUnsignedAmt())(amount * enabled);
    signal output arr[LenOfTokenLeaf()] <== TokenLeaf_Alloc()([(tokenLeaf[0] - amount) * enabled, (tokenLeaf[1] + amount) * enabled]);
}
template TokenLeaf_Unlock(){
    signal input tokenLeaf[LenOfTokenLeaf()];
    signal input enabled;
    signal input amount;
    _ <== Num2Bits(BitsUnsignedAmt())(amount * enabled);
    signal output arr[LenOfTokenLeaf()] <== TokenLeaf_Alloc()([(tokenLeaf[0] + amount) * enabled, (tokenLeaf[1] - amount) * enabled]);
}
template TokenLeaf_Deduct(){
    signal input tokenLeaf[LenOfTokenLeaf()];
    signal input enabled;
    signal input amount;
    _ <== Num2Bits(BitsUnsignedAmt())(amount * enabled);
    signal output arr[LenOfTokenLeaf()] <== TokenLeaf_Alloc()([tokenLeaf[0] * enabled, (tokenLeaf[1] - amount) * enabled]);
}
template TokenLeaf_SufficientCheck(){
    signal input tokenLeaf[LenOfTokenLeaf()];
    signal input enabled;
    signal input amount;

    component token = TokenLeaf();
    token.arr <== tokenLeaf;

    var offset = (1 << BitsUnsignedAmt());
    ImplyEq()(enabled, 1, TagGreaterEqThan(BitsAmount())([token.avl_amt + offset, amount + offset]));
}