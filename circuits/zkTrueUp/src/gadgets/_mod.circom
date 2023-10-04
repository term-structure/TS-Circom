pragma circom 2.1.2;

include "fp.circom";
include "indexer.circom";
include "merkle_tree_poseidon.circom";
include "tag_comparators.circom";
include "../../../../node_modules/circomlib/circuits/poseidon.circom";
include "../../../../node_modules/circomlib/circuits/comparators.circom";

function log2(a) {
    if (a==0) {
        return 0;
    }
    var r = 0;
    while ((1 << r) < a) 
        r++;
    return r;
}
template DaysFrom(){
    signal input currentTime, maturityTime;
    signal output days;
    // No matter what input is given, `intDivide` will always output successfully.
    // Unreasonable values will not be used in subsequent processes.
    (days, _) <== IntDivide(BitsTime())(((maturityTime + ConstSecondsPerDay() - 1) - currentTime), ConstSecondsPerDay());
}
template Min(bits){
    signal input in[2];
    signal slt <== TagLessThan(bits)(in);
    signal output out <== Mux(2)([in[1], in[0]], slt);
}
template Max(bits){
    signal input in[2];
    signal slt <== TagLessThan(bits)(in);
    signal output out <== Mux(2)([in[0], in[1]], slt);
}
template ImplyEq(){
    signal input enabled;
    signal input in_0;
    signal input in_1;
    signal tmp <== Mux(2)([in_0, in_1], enabled);
    tmp === in_0;
}
template ImplyEqArr(len){
    signal input enabled;
    signal input in_0[len];
    signal input in_1[len];
    for(var i = 0; i < len; i++)
        ImplyEq()(enabled, in_0[i], in_1[i]);
}
template IntDivide(bits_divisor){
    // def: if dividend is >= 2^253 or divisor = 0, then the quotient and remainder are both 0
    // No matter what input is given, `intDivide` will always output successfully.
    signal input dividend;
    signal input divisor;
    signal output quotient;
    signal output remainder;
    _ <== Num2Bits(bits_divisor)(divisor);
    signal bits_dividend[ConstFieldBitsFull()] <== Num2Bits_strict()(dividend);
    signal mask <== Not()(Or()(TagIsZero()(divisor), Bool()(bits_dividend[ConstFieldBitsFull() - 1])));
    signal dividend_ <== dividend * mask;
    (quotient, remainder) <-- (mask ? dividend_ \ divisor : 0, mask ? dividend_ % divisor : 0);
    quotient * divisor + remainder === dividend_;
    signal slt <== TagLessThan(bits_divisor)([remainder, divisor]);
    slt === 1;
    _ <== Num2Bits(ConstFieldBits() - bits_divisor)(quotient);
}
template PoseidonArbitraryLen(len){
    signal input inputs[len];
    signal output out;
    signal temp;
    var batch = 16;
    if(len < batch){
        out <== Poseidon(len)(inputs);
    }
    else{
        temp <== Poseidon(batch)([inputs[0], inputs[1], inputs[2], inputs[3], inputs[4], inputs[5], inputs[6], inputs[7], inputs[8], inputs[9], inputs[10], inputs[11], inputs[12], inputs[13], inputs[14], inputs[15]]);
        var t[len - batch + 1];
        t[0] = temp;
        for(var i = batch; i < len; i++) {
            t[i - batch + 1] = inputs[i];
        }
        out <== PoseidonArbitraryLen(len - batch + 1)(t);
    }
}
template PoseidonSpecificLen(len){
    signal input inputs[len];
    signal output out;
    var new_len = len + 1;
    var new_inputs[new_len];
    new_inputs[0] = len;
    for(var i = 1; i < new_len; i++)
        new_inputs[i] = inputs[i - 1];
    out <== PoseidonArbitraryLen(new_len)(new_inputs);
}
template TsPubKey2TsAddr(){
    signal input in[2];
    signal temp <== Poseidon(2)(in);
    signal n2B[ConstFieldBitsFull()] <== Num2Bits_strict()(temp);
    var t[160];
    for(var i = 0; i < 160; i++)
        t[i] = n2B[i];

    signal output out <== Bits2Num(160)(t);
}