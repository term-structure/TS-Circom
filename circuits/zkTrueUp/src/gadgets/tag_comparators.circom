pragma circom 2.1.2;

include "../../../../node_modules/circomlib/circuits/comparators.circom";

template TagIsZero(){
    signal input in;
    signal output {bool} out <== IsZero()(in);
}
template TagIsEqual(){
    signal input in[2];
    signal output {bool} out <== IsEqual()(in);
}
template TagLessThan(bits){
    signal input in[2];
    signal output {bool} out <== LessThan(bits)(in);
}
template TagGreaterThan(bits){
    signal input in[2];
    signal output {bool} out <== GreaterThan(bits)(in);
}
template TagLessEqThan(bits){
    signal input in[2];
    signal output {bool} out <== LessEqThan(bits)(in);
}
template TagGreaterEqThan(bits){
    signal input in[2];
    signal output {bool} out <== GreaterEqThan(bits)(in);
}