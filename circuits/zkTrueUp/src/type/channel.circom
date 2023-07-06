pragma circom 2.1.5;

template Channel_New(){
    signal input order[LenOfOrderLeaf()];
    signal input arg[LenOfChannel() - LenOfOrderLeaf()];
    var tmp[LenOfChannel()];
    for(var i = 0; i < LenOfOrderLeaf(); i++)
        tmp[i] = order[i];
    for(var i = LenOfOrderLeaf(); i < LenOfChannel(); i++){
        tmp[i] = arg[i - LenOfOrderLeaf()];
        _ <== Num2Bits(BitsAmount())(tmp[i]);
    }
    signal output arr[LenOfChannel()] <== tmp;
}
template Channel_Default(){
    signal output arr[LenOfChannel()];
    for(var i = 0; i < LenOfChannel(); i++)
        arr[i] <== 0;
}