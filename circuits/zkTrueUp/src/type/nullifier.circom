pragma circom 2.1.5;

template NullifierLeaf_Place(){
    signal input nullifierLeaf[LenOfNullifierLeaf()], digest, nullifierElemId;
    signal output arr[LenOfNullifierLeaf()];
    signal is_eq[LenOfNullifierLeaf()];
    for(var i = 0; i < LenOfNullifierLeaf(); i++){
        is_eq[i] <== TagIsEqual()([i, nullifierElemId]);
        arr[i] <== (digest - nullifierLeaf[i]) * is_eq[i] + nullifierLeaf[i];
    }
}
template NullifierLeaf_CheckCollision(){
    signal input nullifierLeaf[LenOfNullifierLeaf()], enabled, digest;
    signal temp[LenOfNullifierLeaf()];
    temp[0] <== digest - nullifierLeaf[0];
    for(var i = 1; i < LenOfNullifierLeaf(); i++)
        temp[i] <== temp[i - 1] * (digest - nullifierLeaf[i]);

    ImplyEq()(enabled, 0, TagIsEqual()([0, temp[LenOfNullifierLeaf() - 2]]));  
}
template Digest2NulliferLeafId(){
    signal input digest;
    signal output nullifierLeafId;
    signal digest2Bits[ConstFieldBitsFull()] <== Num2Bits_strict()(digest);
    var tmp[NullifierTreeHeight()];
    for(var i = 0; i < NullifierTreeHeight(); i ++)
        tmp[i] = digest2Bits[i];
    nullifierLeafId <== Bits2Num(NullifierTreeHeight())(tmp);
}