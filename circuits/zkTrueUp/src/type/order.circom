pragma circom 2.1.5;

template OrderLeaf_Place(){
    signal input req[LenOfReq()];
    signal input cumAmt0;
    signal input cumAmt1;
    signal input txId;
    signal input lockedAmt;
    signal input cumFeeAmt;
    signal input creditAmt;
    var order[LenOfOrderLeaf()];
    for(var i = 0; i < LenOfReq(); i++)
        order[i] = req[i];
    order[LenOfReq() + 0] = txId;
    order[LenOfReq() + 1] = cumAmt0;
    order[LenOfReq() + 2] = cumAmt1;
    order[LenOfReq() + 3] = lockedAmt;
    order[LenOfReq() + 4] = cumFeeAmt;
    order[LenOfReq() + 5] = creditAmt;
    signal output arr[LenOfOrderLeaf()] <== OrderLeaf_Alloc()(order);
}
template OrderLeaf_Default(){
    signal output arr[LenOfOrderLeaf()];
    for(var i = 0; i < LenOfOrderLeaf(); i++)
        arr[i] <== 0;
}
template OrderLeaf_DefaultIf(){
    signal input orderLeaf[LenOfOrderLeaf()];
    signal input enabled;
    signal output arr[LenOfOrderLeaf()];
    for(var i = 0; i < LenOfOrderLeaf(); i++)
        arr[i] <== orderLeaf[i] * (1 - enabled);
}
template OrderLeaf_DeductLockedAmt(){
    signal input orderLeaf[LenOfOrderLeaf()];
    signal input enabled;
    signal input amt;
    signal output arr[LenOfOrderLeaf()];
    _ <== Num2Bits(BitsUnsignedAmt())(amt * enabled);
    for(var i = 0; i < LenOfOrderLeaf(); i++){
        if(i == LenOfReq() + 3){
            _ <== Num2Bits(BitsUnsignedAmt())((orderLeaf[i] - amt) * enabled);
            arr[i] <== orderLeaf[i] - amt;
        }
        else
            arr[i] <== orderLeaf[i];
    }
}
template OrderLeaf_UpdateCumFeeAmt(){
    signal input orderLeaf[LenOfOrderLeaf()];
    signal input enabled;
    signal input amt;
    signal output arr[LenOfOrderLeaf()];
    _ <== Num2Bits(BitsUnsignedAmt())(amt * enabled);
    for(var i = 0; i < LenOfOrderLeaf(); i++){
        if(i == LenOfReq() + 4){
            arr[i] <== orderLeaf[i] + amt;
        }
        else
            arr[i] <== orderLeaf[i];
    }
}
template OrderLeaf_UpdateCreditAmt(){
    signal input orderLeaf[LenOfOrderLeaf()];
    signal input enabled;
    signal input amt;
    signal output arr[LenOfOrderLeaf()];
    _ <== Num2Bits(BitsUnsignedAmt())(amt * enabled);
    for(var i = 0; i < LenOfOrderLeaf(); i++){
        if(i == LenOfReq() + 5){
            arr[i] <== amt;
        }
        else
            arr[i] <== orderLeaf[i];
    }
}
template OrderLeaf_IsFull(){
    signal input orderLeaf[LenOfOrderLeaf()];
    signal output {bool} isFull;

    component order = OrderLeaf();
    order.arr <== orderLeaf;
    component req = Req();
    req.arr <== order.req;

    //req.arg[5] is the amount of the target token
    //req.arg[8] is `side` if it is secondary order

    signal isAuction <== Or()(TagIsEqual()([req.opType, OpTypeNumAuctionLend()]), TagIsEqual()([req.opType, OpTypeNumAuctionBorrow()]));
    signal isSecondary <== TagIsEqual()([req.opType, OpTypeNumSecondLimitOrder()]);

    signal isFull0 <== TagIsEqual()([req.amount, order.cumAmt0]);
    signal isFull1 <== TagIsEqual()([req.arg[5], order.cumAmt1]);

    signal isFullAsAuction <== And()(isFull0, isAuction);
    signal isFullIfSecondary <== Bool()(Mux(2)([isFull1, isFull0], req.arg[8]));
    signal isFullAsSecondary <== And()(isFullIfSecondary, isSecondary);
    isFull <== Or()(isFullAsAuction, isFullAsSecondary);
}