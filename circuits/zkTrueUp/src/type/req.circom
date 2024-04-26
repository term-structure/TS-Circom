pragma circom 2.1.5;

template Req_Digest(){
    signal input req[LenOfReq()];
    signal output digest <== PoseidonSpecificLen(LenOfReq())(req);
}
template Req_CheckExpiration(){
    signal input req[LenOfReq()];
    signal input {bool} enabled;
    signal input currentTime;

    component req_ = Req();
    req_.arr <== req;

    var idx_expiration_time = 2;
    ImplyEq()(enabled, 1, TagLessThan(BitsTime())([currentTime * enabled, req_.arg[idx_expiration_time] * enabled]));
}
template Req_DaysFromExpired(){
    signal input req[LenOfReq()], maturityTime;

    component req_ = Req();
    req_.arr <== req;

    var idx_expiration_time = 2;
    signal output days <== DaysFrom()(req_.arg[idx_expiration_time], maturityTime);
}