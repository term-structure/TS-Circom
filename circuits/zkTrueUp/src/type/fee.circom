pragma circom 2.1.5;

template FeeLeaf_Incoming(){
    signal input feeLeaf[LenOfFeeLeaf()];
    signal input enabled;
    signal input amount;
    _ <== Num2Bits(BitsUnsignedAmt())(amount * enabled);
    _ <== Num2Bits(BitsUnsignedAmt())((feeLeaf[0] + amount) * enabled);
    signal output arr[LenOfFeeLeaf()] <== [feeLeaf[0] + amount];
}