pragma circom 2.1.2;

include "./const/_mod.circom";
include "./gadgets/_mod.circom";
include "../../../node_modules/circomlib/circuits/comparators.circom";

template AuctionCalcDebtAmt(){
    signal input interest;
    signal input principal;
    signal input days;

    signal output debtAmt;
    // debtAmt := principal * (interest * (days - 1) + one * (365 - (days - 1))) / (365 * one) 
    var one = 10 ** 8;
    signal temp <== interest * (days - 1) + one * (365 - (days - 1));
    (debtAmt, _) <== IntDivide(BitsAmount())(principal * temp, one * 365); 
}
template AuctionCalcFee(){
    signal input feeRate;
    signal input matchedBorrowingAmt;
    signal input matchedInterest;
    signal input days;

    signal output fee;
    // fee := matchedBorrowingAmt * matchedInterest * feeRate * (days - 1) / (365 * (10 ** 8) * (10 ** 8))
    var one = 10 ** 8;
    signal slt <== TagLessThan(BitsRatio())([matchedInterest, one]);
    signal absInterest <== (2 * slt - 1)* (one - matchedInterest);
    signal temp <== feeRate * (days - 1);
    signal temp2 <== absInterest * temp;
    (fee, _) <== IntDivide(BitsAmount())(matchedBorrowingAmt * temp2, one * one * 365);
}
template AuctionMechanism(){
    // interest := the max lender interest matched to the same borrower
    // newCumCollateralAmt := CollateralAmt * newCumBorrowingAmt / BorrowingAmt;
    signal input enabled;
    signal input interest;
    signal input LendingAmt, BorrowingAmt, CollateralAmt;
    
    signal input oriCumLendingAmt, oriCumTslAmt, oriCumBorrowingAmt, oriCumCollateralAmt;

    signal input days;

    signal output newCumLendingAmt, newCumTslAmt, newCumBorrowingAmt, newCumCollateralAmt;

    signal matchedAmt <== Min(BitsAmount())([LendingAmt - oriCumLendingAmt, BorrowingAmt - oriCumBorrowingAmt]);
    signal matchedTslAmt <== AuctionCalcDebtAmt()(interest * enabled, matchedAmt * enabled, days * enabled);
    signal remainingCollateralAmt;
    
    newCumLendingAmt <== oriCumLendingAmt + matchedAmt;
    newCumTslAmt <== oriCumTslAmt + matchedTslAmt;
    newCumBorrowingAmt <== oriCumBorrowingAmt + matchedAmt;
    (remainingCollateralAmt, _) <== IntDivide(BitsAmount())(CollateralAmt * (BorrowingAmt - newCumBorrowingAmt), (BorrowingAmt - 1) * enabled + 1);
    newCumCollateralAmt <== CollateralAmt - remainingCollateralAmt;
}
template CalcNewBQ(){
    signal input enabled;
    signal input MQ, BQ, priceMQ, priceBQ, days;
    signal output newBQ;
    signal temp <== (days * (priceMQ - priceBQ) + 365 * priceBQ);
    (newBQ, _) <== IntDivide(BitsAmount())((365 * MQ * priceBQ), (temp - 1) * enabled + 1);
}
template CalcSupMQ(){
    signal input enabled;
    signal input avl_BQ, priceMQ, priceBQ, days;
    signal output supMQ;
    signal temp0 <== avl_BQ * days;
    signal temp1 <== temp0 * priceMQ;
    signal temp2 <== 365 * priceBQ;
    signal temp3 <== (365 - days) * priceBQ;
    signal temp4 <== temp3 * avl_BQ;
    (supMQ, _) <== IntDivide(BitsAmount())(temp1 + temp4, (temp2 - 1) * enabled + 1);
}
template SecondCalcFee(){
    signal input MQ, feeRate, days;
    signal temp <== MQ * feeRate;
    signal output out;
    (out, _) <== IntDivide(BitsAmount())(temp * days, 365 * (10 ** 8));
}
template SecondMechanism(){
    signal input enabled;
    signal input takerOpType;
    signal input takerBuyAmt, takerSellAmt, makerBuyAmt, makerSellAmt;
    signal input makerSide;
    signal input oriCumTakerBuyAmt, oriCumTakerSellAmt, oriCumMakerBuyAmt, oriCumMakerSellAmt;
    signal input days;
    signal output newCumTakerBuyAmt, newCumTakerSellAmt, newCumMakerBuyAmt, newCumMakerSellAmt;

    signal is_market_order <== IsEqual()([takerOpType, OpTypeNumSecondMarketOrder()]);

    signal remainTakerSellAmt <== takerSellAmt - oriCumTakerSellAmt;
    signal remainMakerSellAmt <== makerSellAmt - oriCumMakerSellAmt;
    signal temp7 <== (1 - (is_market_order * (1 - makerSide)));
    signal remainTakerBuyAmt <== (takerBuyAmt - oriCumTakerBuyAmt) * temp7;
    signal remainMakerBuyAmt <== makerBuyAmt - oriCumMakerBuyAmt;
    
    signal temp0, temp1, temp2, temp3;
    (temp0, _) <== IntDivide(BitsAmount())(remainTakerSellAmt * makerSellAmt, (makerBuyAmt - 1) * enabled + 1);
    (temp1, _) <== IntDivide(BitsAmount())(remainTakerBuyAmt * makerBuyAmt, (makerSellAmt - 1) * enabled + 1);
    (temp2, _) <== IntDivide(BitsAmount())(remainMakerSellAmt * makerBuyAmt, (makerSellAmt - 1) * enabled + 1);
    (temp3, _) <== IntDivide(BitsAmount())(remainMakerBuyAmt * makerSellAmt, (makerBuyAmt - 1) * enabled + 1);
    signal supTakerBuyAmt  <== Mux(2)([temp0, remainTakerBuyAmt], makerSide);
    signal infTakerSellAmt <== Mux(2)([remainTakerSellAmt, temp1], makerSide);
    signal supMakerBuyAmt  <== Mux(2)([remainMakerBuyAmt, temp2], makerSide);
    signal infMakerSellAmt <== Mux(2)([temp3, remainMakerSellAmt], makerSide);
    
    signal matchedMakerSellAmtFirstDay <== Min(BitsAmount())([supTakerBuyAmt, infMakerSellAmt]);
    signal matchedMakerBuyAmtFirstDay  <== Min(BitsAmount())([supMakerBuyAmt, infTakerSellAmt]);

    // calc new BQ for maker and taker //!! side == 0 -> sell amt be BQ
    signal matchedMakerSellAmtIfBQ <== CalcNewBQ()(enabled, matchedMakerBuyAmtFirstDay, matchedMakerSellAmtFirstDay, makerBuyAmt, makerSellAmt, days);
    signal matchedMakerBuyAmtIfBQ  <== CalcNewBQ()(enabled, matchedMakerSellAmtFirstDay, matchedMakerBuyAmtFirstDay, makerSellAmt, makerBuyAmt, days);

    signal matchedMakerSellAmtExpected <== Mux(2)([matchedMakerSellAmtIfBQ, matchedMakerSellAmtFirstDay], makerSide);
    signal matchedMakerBuyAmtExpected <== Mux(2)([matchedMakerBuyAmtIfBQ, matchedMakerBuyAmtFirstDay], 1 - makerSide);

    signal supMQ <== CalcSupMQ()(enabled, remainTakerSellAmt, makerSellAmt, makerBuyAmt, days);
    signal slt <== TagLessThan(BitsAmount())([remainTakerSellAmt, matchedMakerBuyAmtExpected]);
    signal is_sufficent <== slt * makerSide;

    signal matchedMakerSellAmt <== Mux(2)([matchedMakerSellAmtExpected, supMQ               ], is_market_order * is_sufficent);
    signal matchedMakerBuyAmt  <== Mux(2)([matchedMakerBuyAmtExpected , remainTakerSellAmt  ], is_market_order * is_sufficent);

    newCumTakerBuyAmt  <== oriCumTakerBuyAmt  + matchedMakerSellAmt;
    newCumMakerBuyAmt  <== oriCumMakerBuyAmt  + matchedMakerBuyAmt ;
    newCumTakerSellAmt <== oriCumTakerSellAmt + matchedMakerBuyAmt ;
    newCumMakerSellAmt <== oriCumMakerSellAmt + matchedMakerSellAmt;
}
template AuctionInteract(){
    signal input oriLend[LenOfOrderLeaf()], oriBorrow[LenOfOrderLeaf()], matchedInterest, days;
    signal output newLend[LenOfOrderLeaf()], newBorrow[LenOfOrderLeaf()];
    signal output {bool} isMatched;
    component lend = OrderLeaf();
    lend.arr <== oriLend;
    component lend_req = Req();
    lend_req.arr <== lend.req;
    component borrow = OrderLeaf();
    borrow.arr <== oriBorrow;
    component borrow_req = Req();
    borrow_req.arr <== borrow.req;
    signal enabled <== And()(TagIsEqual()([lend_req.opType, OpTypeNumAuctionLend()]), TagIsEqual()([borrow_req.opType, OpTypeNumAuctionBorrow()]));
    isMatched <== And()(TagIsEqual()([lend_req.arg[1], borrow_req.arg[1]]), And()(TagIsEqual()([lend_req.tokenId, borrow_req.arg[4]]), TagGreaterEqThan(BitsRatio())([borrow_req.arg[3], lend_req.arg[3]])));
    
    signal newCumLendingAmt, newCumTslAmt, newCumBorrowingAmt, newCumCollateralAmt;
    (newCumLendingAmt, newCumTslAmt, newCumBorrowingAmt, newCumCollateralAmt) <== AuctionMechanism()(enabled, matchedInterest, lend_req.amount, borrow_req.arg[5], borrow_req.amount, lend.cumAmt0, lend.cumAmt1, borrow.cumAmt1, borrow.cumAmt0, days);
    
    newLend <== OrderLeaf_Place()(lend.req, newCumLendingAmt * enabled, newCumTslAmt * enabled, lend.txId * enabled, lend.lockedAmt * enabled);
    newBorrow <== OrderLeaf_Place()(borrow.req, newCumCollateralAmt * enabled, newCumBorrowingAmt * enabled, borrow.txId * enabled, borrow.lockedAmt * enabled);
}
template SecondaryInteract(){
    signal input oriTaker[LenOfOrderLeaf()], oriMaker[LenOfOrderLeaf()], days;
    signal output newTaker[LenOfOrderLeaf()], newMaker[LenOfOrderLeaf()];
    signal output {bool} isMatched;
    component maker = OrderLeaf();
    maker.arr <== oriMaker;
    component maker_req = Req();
    maker_req.arr <== maker.req;
    component taker = OrderLeaf();
    taker.arr <== oriTaker;
    component taker_req = Req();
    taker_req.arr <== taker.req;
    signal enabled0 <== And()(TagIsEqual()([maker_req.opType, OpTypeNumSecondLimitOrder()]), TagIsEqual()([taker_req.opType, OpTypeNumSecondLimitOrder()]));
    signal enabled1 <== And()(TagIsEqual()([maker_req.opType, OpTypeNumSecondLimitOrder()]), TagIsEqual()([taker_req.opType, OpTypeNumSecondMarketOrder()]));
    signal enabled <== Or()(enabled0, enabled1);
    isMatched <== Or()(TagIsEqual()([taker_req.opType, OpTypeNumSecondMarketOrder()]),And()(TagLessEqThan(BitsAmount() * 2)([maker_req.arg[5] * taker_req.arg[5], maker_req.amount * taker_req.amount]), And()(TagIsEqual()([maker_req.tokenId, taker_req.arg[4]]), TagIsEqual()([maker_req.arg[4], taker_req.tokenId]))));
    
    signal newCumTakerBuyAmt, newCumTakerSellAmt, newCumMakerBuyAmt, newCumMakerSellAmt;
    (newCumTakerBuyAmt, newCumTakerSellAmt, newCumMakerBuyAmt, newCumMakerSellAmt) <== SecondMechanism()(enabled, taker_req.opType, taker_req.arg[5], taker_req.amount, maker_req.arg[5], maker_req.amount, maker_req.arg[8], taker.cumAmt1, taker.cumAmt0, maker.cumAmt1, maker.cumAmt0, days);
    
    newTaker <== OrderLeaf_Place()(taker.req, newCumTakerSellAmt * enabled, newCumTakerBuyAmt * enabled, taker.txId * enabled, taker.lockedAmt * enabled);
    newMaker <== OrderLeaf_Place()(maker.req, newCumMakerSellAmt * enabled, newCumMakerBuyAmt * enabled, maker.txId * enabled, maker.lockedAmt * enabled);
}
template CalcFee(){
    signal input newOrderLeaf[LenOfOrderLeaf()], enabled, oriCumAmt0, oriCumAmt1, matchedTime, maturityTime, arg;

    component new_order = OrderLeaf();
    new_order.arr <== newOrderLeaf;
    component req = Req();
    req.arr <== new_order.req;

    signal isLend <== TagIsEqual()([req.opType, OpTypeNumAuctionLend()]);
    signal isBorrow <== TagIsEqual()([req.opType, OpTypeNumAuctionBorrow()]);
    signal isAuction <== Or()(isLend, isBorrow);
    signal isSecondary <== Or()(TagIsEqual()([req.opType, OpTypeNumSecondLimitOrder()]), TagIsEqual()([req.opType, OpTypeNumSecondMarketOrder()]));

    var matched_amt0 = new_order.cumAmt0 - oriCumAmt0;
    var matched_amt1 = new_order.cumAmt1 - oriCumAmt1;

    signal feeIfLend <== AuctionCalcFee()(req.fee0, matched_amt0, arg, DaysFrom()(matchedTime, req.arg[1]));
    signal feeAsLend <== feeIfLend * isLend;
    signal feeIfBorrow <== AuctionCalcFee()(req.fee0, matched_amt1, arg, DaysFrom()(matchedTime, req.arg[1]));
    signal feeAsBorrow <== feeIfBorrow * isBorrow;

    signal feeRateIf2nd <== (req.fee1 - req.fee0) * arg + req.fee0;
    signal feeIfBuy  <== SecondCalcFee()(matched_amt1, feeRateIf2nd * isSecondary, DaysFrom()(matchedTime, maturityTime));
    signal feeIfSell <== SecondCalcFee()(matched_amt0, feeRateIf2nd * isSecondary, DaysFrom()(matchedTime, maturityTime));
    signal feeAsBuy  <== feeIfBuy * (1 - req.arg[8]);
    signal feeAsSell <== feeIfSell * req.arg[8];
    signal feeIfSecondary <== feeAsBuy + feeAsSell;

    signal output feeFromLocked <== Mux(2)([feeAsBuy, feeAsLend], isAuction);
    signal output feeFromTarget <== Mux(2)([feeAsSell, feeAsBorrow], isAuction);
    signal output fee <== feeFromTarget + feeFromLocked;
}