pragma circom 2.1.5;

template PreprocessedReq_GetOpType(){
    signal input preprocessedReq[LenOfPreprocessedReq()];
    signal output opType <== preprocessedReq[0]; 
}