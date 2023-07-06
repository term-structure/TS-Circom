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

    ImplyEq()(enabled, 1, TagLessThan(BitsTime())([currentTime * enabled, req_.arg[2] * enabled]));
}
template Req_DaysFromExpired(){
    signal input req[LenOfReq()], maturityTime;

    component req_ = Req();
    req_.arr <== req;

    signal output days <== DaysFrom()(req_.arg[2]/*expiration time*/, maturityTime);
}