pragma circom 2.1.2;

include "../../../../node_modules/circomlib/circuits/bitify.circom";
include "../../../../node_modules/circomlib/circuits/multiplexer.circom";

template TenToPowerOf(){
    signal input in;
    signal n2B[5] <== Num2Bits(5)(in);
    var temp[5];
    signal temp2[5];
    signal output out;

    var t[5];
    t[0] = 10;
    for(var i = 1; i < 5; i++)
        t[i] = t[i - 1] * t[i - 1];
    for(var i = 0; i < 5; i++)
        temp[i] = (t[i] - 1) * n2B[i] + 1;
    temp2[0] <== 1;
    for(var i = 1; i < 5; i++)
        temp2[i] <== temp2[i - 1] * temp[i - 1];
    out <== temp2[4] * temp[4];
}
template Float2Fix(){
    /* Mapping from Float to Fix not necessary 1-1. */
    signal input in;
    signal output out;
    signal n2B_in[40] <== Num2Bits(40)(in);
    signal exp <== Bits2Num(5)([n2B_in[35], n2B_in[36], n2B_in[37], n2B_in[38], n2B_in[39]]);
    signal temp <== TenToPowerOf()(exp);

    var t[35];
    for(var i = 0; i < 35; i++)
        t[i] = n2B_in[i];
    signal mantissa <== Bits2Num(35)(t);
    out <== mantissa * temp;
}
template Fix2Float(){
    signal input in;
    signal output out;
    var val_in = in;
    var val_exp = 0;
    if(val_in != 0){
        while(val_in % 10 == 0){
            val_in /= 10;
            val_exp++;
        }
    }
    out <-- val_in + (val_exp << 35);
    signal temp <== Float2Fix()(out);
    temp === in;
}
template Fix2FloatCond(){
    signal input {bool} enabled;
    signal input in;
    signal output out;
    out <== Fix2Float()(in * enabled);
}
