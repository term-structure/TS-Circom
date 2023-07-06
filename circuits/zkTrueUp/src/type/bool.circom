pragma circom 2.1.5;

template And(){
    signal input {bool} a, b;
    signal output {bool} out <== a * b;
}
template Not(){
    signal input {bool} a;
    signal output {bool} out <== (1 - a);
}
template Or(){
    signal input {bool} a, b;
    signal output {bool} out <== (a + b - a * b);
}
template MultiAnd(n){
    signal input {bool} in[n];
    var sum = 0;
    for(var i = 0; i < n ; i++)
        sum += in[n];
    signal output {bool} out <== TagIsEqual()([sum, n]);
}
template MultiOr(n){
    signal input {bool} in[n];
    var sum = 0;
    for(var i = 0; i < n ; i++)
        sum += in[n];
    signal output {bool} out <== Not()(TagIsEqual()([sum, 0]));
}