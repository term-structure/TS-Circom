pragma circom 2.1.5;

include "bits.circom";
include "fmt.circom";
include "op_type.circom";

function ConstFieldBits(){
    return 253;
}
function ConstFieldBitsFull(){
    return ConstFieldBits() + 1;
}
function ConstSecondsPerDay(){
    return 86400;
}
function ConstDaysPerYear(){
    return 365;
}
function ConstIsAdminReq(){ 
    return [
        1,//Noop
        1,//Register
        1,//Deposit
        1,//ForceWithdraw
        0,//Transfer
        0,//Withdraw
        0,//AuctionLend
        0,//AuctionBorrow
        1,//AuctionStart
        1,//AuctionMatch
        1,//AuctionEnd
        0,//SecondLimitOrder
        1,//SecondLimitStart
        1,//SecondLimitExchange
        1,//SecondLimitEnd
        0,//SecondMarketOrder
        1,//SecondMarketExchange
        1,//SecondMarketEnd
        1,//AdminCancel
        0,//UserCancel
        1,//IncreaseEpoch
        1,//CreateTSBTokenToken
        0,//Redeem
        1,//WithdrawFee
        1,//Evacuation
        1,//SetAdminTsAddr
        1,//RollBorrowOrder
        1,//RollOverStart
        1,//RollOverMatch
        1,//RollOverEnd
        0,//UserCancelRollBorrow
        1,//AdminCancelRollBorrow
        1 //ForceCancelRollBorrow
    ];
}
function ConstChunkCount(){
    return [
        0,//Noop
        3,//Register
        2,//Deposit
        2,//ForceWithdraw
        2,//Transfer
        3,//Withdraw
        3,//AuctionLend
        3,//AuctionBorrow
        1,//AuctionStart
        1,//AuctionMatch
        5,//AuctionEnd
        4,//SecondLimitOrder
        1,//SecondLimitStart
        1,//SecondLimitExchange
        1,//SecondLimitEnd
        3,//SecondMarketOrder
        1,//SecondMarketExchange
        1,//SecondMarketEnd
        1,//AdminCancel
        2,//UserCancel
        1,//IncreaseEpoch
        1,//CreateTSBTokenToken
        2,//Redeem
        2,//WithdrawFee
        2,//Evacuation
        1,//SetAdminTsAddr
        6,//RollBorrowOrder
        1,//RollOverStart
        1,//RollOverMatch
        6,//RollOverEnd
        2,//UserCancelRollBorrow
        2,//AdminCancelRollBorrow
        2 //ForceCancelRollBorrow
    ];
}
function ConstIsCriticalReq(){
    return [
        0,//Noop
        1,//Register
        1,//Deposit
        1,//ForceWithdraw
        0,//Transfer
        1,//Withdraw
        0,//AuctionLend
        0,//AuctionBorrow
        0,//AuctionStart
        0,//AuctionMatch
        1,//AuctionEnd
        0,//SecondLimitOrder
        0,//SecondLimitStart
        0,//SecondLimitExchange
        0,//SecondLimitEnd
        0,//SecondMarketOrder
        0,//SecondMarketExchange
        0,//SecondMarketEnd
        0,//AdminCancel
        0,//UserCancel
        0,//IncreaseEpoch
        1,//CreateTSBTokenToken
        0,//Redeem
        1,//WithdrawFee
        1,//Evacuation
        0,//SetAdminTsAddr
        1,//RollBorrowOrder
        0,//RollOverStart
        0,//RollOverMatch
        1,//RollOverEnd
        1,//UserCancelRollBorrow
        1,//AdminCancelRollBorrow
        1 //ForceCancelRollBorrow
    ];
}