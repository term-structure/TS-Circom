/*
    In general, to guarantee that the circuit can be compiled successfully without the underflow/overflow issues,
    we need to make sure that the following conditions are satisfied:
        1.  All the input signals for the components that are activated while processing are legal (not underflow nor overflow).
        2.  All the intermediate calculation results are legal (not underflow nor overflow).
        3.  The final output value derived from the legal input signals with the pre-defined calculation is legal (not underflow nor overflow).

    In our case,
        1.  We will do the input signal check in `UnitSet_Enforce()` in `normal.circom` to help us ensure that inputs are legal before passing them to the component, making it easier to guarantee their validity.
        2.  Our mechanism and pre-defined calculation formula will guarantee that even the intermediate calculation results are illegal, the final output value will also be legal.
        3.  The final output values are legal according to 2.

    For example,
    Consider the following formula: $$debtAmt := principal * (PIR * (days - 1) + one * (365 - (days - 1))) / (365 * one)$$

    In this formula, if days is 367 and PIR(principal and interest) is 90%, 
    the term one * (365 - (days - 1)) may underflow. 
    
    However, the term principal * (PIR * (days - 1) + one * (365 - (days - 1))) will not underflow.

    Given our mechanism, we checked the lower limit of the PIR when `PlaceOrder`, 
    As a result, we have determined that the $principal * (PIR * (days - 1) + one * (365 - (days - 1)))$ must be greater than 0.

    Next, we need to address the division operation, IntDivide(), to ensure both the divisor and dividend are valid. 
    To prevent overflow beyond 2^253 in the template used in this file, we make certain assumptions. 

    These assumptions are relevant for other parts of the circuit that use these templates, 
    and they only need to be satisfied when the results are utilized, ensuring correctness.

    Most of the time, we satisfy this condition by performing the input signal check in UnitSet_Enforce() in normal.circom.
    
    For example, in the formula: $$debtAmt := principal * (PIR * (days - 1) + one * (365 - (days - 1))) / (365 * one)$$
    We need to assume the following:
        1.  `PIR` is within `BitsRatio()` bits.
        2.  `principal` is within `BitsAmount()` bits.
        3.  `days` is within 15 bits.

    By doing this, we only need to assert: (BitsRatio() + BitsAmount() + BitsDays()) <= ConstFieldBits() to guarantee that the results will not overflow.

    In conclusion, we simply need to pay attention to the "IntDivide()" calculation and ensure that both the divisor and dividend are valid to guarantee legal outputs from it.

*/
pragma circom 2.1.2;

include "./const/_mod.circom";
include "./gadgets/_mod.circom";
include "../../../node_modules/circomlib/circuits/comparators.circom";


function BitsDays(){
    // check that `Create bond tokens` can only be issued within 365 * 80 days.
    return 15;
}

/*
    This template assumes that the input signal has been checked to meet the following:
    1. `PIR` is within `BitsRatio()` bits.
    2. `principal` is within `BitsAmount()` bits.
    3. `days` is within 15 bits.
    
    $$debtAmt := principal * (PIR * (days - 1) + one * (365 - (days - 1))) / (365 * one)$$

*/
template AuctionCalcDebtAmt(){
    signal input PIR;
    signal input principal;
    signal input days;
    signal output debtAmt;
    var one = 10 ** 8;

    // Because the 'AuctionLend', 'AuctionBorrow' includes a check for the 'interest lower limit', `numeratorOfScaledPIR` cannot possibly underflow.
    signal numeratorOfScaledPIR <== PIR * (days - 1) + one * (365 - (days - 1));

    // Overflow check
    assert((BitsRatio() + BitsAmount() + BitsDays()) <= ConstFieldBits());
    // Underflow check
    //      the `numeratorOfScaledPIR` cannot possibly underflow 
    //      => `principal * numeratorOfScaledPIR` cannot possibly underflow.
    (debtAmt, _) <== IntDivide(BitsAmount())(principal * numeratorOfScaledPIR, one * 365); 
}

/*
    This template assumes that the input signal has been checked to meet the following:
    1. `feeRate` is within `BitsRatio()` bits.
    2. `matchedBorrowingAmt` is within `BitsAmount()` bits.
    3. `matchedPIR` is within `BitsRatio()` bits.
    4. `days` is within 15 bits.
    
    $$fee := matchedBorrowingAmt * |interest| * feeRate * (days - 1) / (365 * one * one)$$

*/
template AuctionCalcFee(){
    signal input feeRate;
    signal input matchedBorrowingAmt;
    signal input matchedPIR;
    signal input days;
    signal output fee;
    var one = 10 ** 8;

    signal slt <== TagLessThan(BitsRatio())([matchedPIR, one]);
    signal absInterestRate <== (2 * slt - 1)* (one - matchedPIR);

    // Because the 'AuctionLend', 'AuctionBorrow' includes a check for the "days > 1", `numeratorOfScaledFeeRate` cannot possibly underflow.
    signal numeratorOfScaledFeeRate <== feeRate * (days - 1);
    signal absInterestRate_numeratorOfScaledFeeRate_Product <== absInterestRate * numeratorOfScaledFeeRate;

    // Overflow check
    assert((BitsAmount() + BitsRatio() + BitsRatio() + BitsDays()) <= ConstFieldBits());
    // Underflow check: obviously
    (fee, _) <== IntDivide(BitsAmount())(matchedBorrowingAmt * absInterestRate_numeratorOfScaledFeeRate_Product, one * one * 365);
}

/*
    PIR := the max lender PIR matched to the same borrower
    
    This template assumes that the input signal has been checked to meet the following:
    1. `PIR` is within `BitsRatio()` bits.
    2. `days` is within 15 bits.
    3. `xxxxAmt` is within `BitsAmount()` bits.

    $$ matchedLendingAmt := Min(LendingAmt - oriCumLendingAmt, BorrowingAmt) $$
    $$ matchedTSBTokenAmt := \lfloor \frac {matchedBorrowAmt * (PIR * days + one * (365 - days))}{(365 * one)} \rfloor $$
    
    $$ newCumLendingAmt := oriCumLendingAmt + matchedLendingAmt $$
    $$ newCumTSBTokenAmt := oriCumTSBTokenAmt + matchedTSBTokenAmt $$
    $$ newCumBorrowingAmt := oriCumBorrowingAmt + matchedLendingAmt $$
    $$ newCumCollateralAmt := CollateralAmt - \lfloor \frac {SignedCollateralAmt * (BorrowingAmt - newCumBorrowingAmt)}{BorrowingAmt}  \rfloor $$

    We can ensure, by the definition of the mechanism itself:
    1.  `oriCumLendingAmt` <= `newCumLendingAmt` <= `LendingAmt`
    2.  `oriCumTSBTokenAmt` <= `newCumTSBTokenAmt`
    3.  `oriCumBorrowingAmt` <= `newCumBorrowingAmt` <= `BorrowingAmt`
    4.  `oriCumCollateralAmt` <= `newCumCollateralAmt` <= `CollateralAmt`
*/
template AuctionMechanism(){
    signal input enabled;
    signal input PIR;
    signal input LendingAmt, BorrowingAmt, CollateralAmt;
    
    signal input oriCumLendingAmt, oriCumTSBTokenAmt, oriCumBorrowingAmt, oriCumCollateralAmt;

    signal input days;

    signal output newCumLendingAmt, newCumTSBTokenAmt, newCumBorrowingAmt, newCumCollateralAmt;

    signal remainingCollateralAmt;
    
    // $$ matchedLendingAmt := Min(LendingAmt - oriCumLendingAmt, BorrowingAmt) $$
    signal matchedAmt <== Min(BitsAmount())([LendingAmt - oriCumLendingAmt, BorrowingAmt - oriCumBorrowingAmt]);
    // $$ matchedTSBTokenAmt := \lfloor \frac {matchedBorrowAmt * (PIR * days + one * (365 - days))}{(365 * one)} \rfloor $$
    signal matchedTSBTokenAmt <== AuctionCalcDebtAmt()(PIR * enabled, matchedAmt * enabled, days * enabled);

    // $$ newCumLendingAmt := oriCumLendingAmt + matchedLendingAmt $$
    newCumLendingAmt <== oriCumLendingAmt + matchedAmt;
    // $$ newCumTSBTokenAmt := oriCumTSBTokenAmt + matchedTSBTokenAmt $$
    newCumTSBTokenAmt <== oriCumTSBTokenAmt + matchedTSBTokenAmt;
    // $$ newCumBorrowingAmt := oriCumBorrowingAmt + matchedLendingAmt $$
    newCumBorrowingAmt <== oriCumBorrowingAmt + matchedAmt;
    // $$ newCumCollateralAmt := CollateralAmt - \lfloor \frac {SignedCollateralAmt * (BorrowingAmt - newCumBorrowingAmt)}{BorrowingAmt}  \rfloor $$
    
    // Overflow check
    assert((BitsAmount() + 1) <= ConstFieldBits());
    assert((BitsAmount() + BitsAmount()) <= ConstFieldBits());
    // Underflow check
    //    by the definition of the mechanism itself, BorrowingAmt > newCumBorrowingAmt
    (remainingCollateralAmt, _) <== IntDivide(BitsAmount())(CollateralAmt * (BorrowingAmt - newCumBorrowingAmt), BorrowingAmt * enabled);
    newCumCollateralAmt <== CollateralAmt - remainingCollateralAmt;
}

/*
    This template assumes that the input signal has been checked to meet the following:
    1. `MQ` is within `BitsAmount()` bits.
    2. `priceMQ` is within `BitsAmount()` bits.
    3. `priceBQ` is within `BitsAmount()` bits.
    4. `days` is within 15 bits.

    $$newBQ := 365 * MQ * priceBQ / (days * (priceMQ - priceBQ) + 365 * priceBQ)$$

*/
template CalcNewBQ(){
    signal input enabled;
    signal input MQ, priceMQ, priceBQ, days;
    signal output newBQ;

    // Because the 'SecondLimitOrder' includes a check for the 'interest lower limit', `denominator` cannot possibly underflow.
    signal denominator <== (days * (priceMQ - priceBQ) + 365 * priceBQ);

    // Overflow check
    //      ceil(log_2(365)) = 9
    assert((9 + BitsAmount() + BitsAmount()) <= ConstFieldBits()); 
    assert((BitsDays() + BitsAmount()) <= ConstFieldBits());
    assert((9 + BitsAmount()) <= ConstFieldBits());
    // Underflow check:
    //      the `denominator` cannot possibly underflow
    (newBQ, _) <== IntDivide(BitsAmount())((365 * MQ * priceBQ), denominator * enabled);
}

/*
    This template assumes that the input signal has been checked to meet the following:
    1. `avlBQ` is within `BitsAmount()` bits.
    2. `priceMQ` is within `BitsAmount()` bits.
    3. `priceBQ` is within `BitsAmount()` bits.
    4. `days` is within 15 bits.

    $$supMQ := ((avlBQ * days * priceMQ) + ((365 - days) * priceBQ * avlBQ)) / (365 * priceBQ)$$
    
*/
template CalcSupMQ(){
    signal input enabled;
    signal input avlBQ, priceMQ, priceBQ, days;
    signal output supMQ;
    
    // Because the 'SecondLimitOrder' includes a check for the 'interest lower limit', `remainDays_priceBQ_avlBQ_Product` cannot possibly underflow.
    signal avlBQ_days_Product <== avlBQ * days;
    signal avlBQ_days_priceMQ_Product <== avlBQ_days_Product * priceMQ;
    signal remainDays_priceBQ_Product <== (365 - days) * priceBQ;
    signal remainDays_priceBQ_avlBQ_Product <== remainDays_priceBQ_Product * avlBQ;

    // Overflow check
    //      ceil(log_2(365)) = 9
    assert((BitsAmount() + BitsDays() + BitsAmount()) <= ConstFieldBits());
    assert((9 + BitsAmount()) <= ConstFieldBits());
    // Underflow check:
    //      the `remainDays_priceBQ_avlBQ_Product` cannot possibly underflow
    //      => `avlBQ_days_priceMQ_Product + remainDays_priceBQ_avlBQ_Product` cannot possibly underflow
    (supMQ, _) <== IntDivide(BitsAmount())(avlBQ_days_priceMQ_Product + remainDays_priceBQ_avlBQ_Product, (365 * priceBQ) * enabled);
}

/*
    This template assumes that the input signal has been checked to meet the following:
    1. `MQ` is within `BitsAmount()` bits.
    2. `feeRate` is within `BitsRatio()` bits.
    3. `days` is within 15 bits.

    $$fee := MQ * feeRate * days / (365 * one)$$

*/
template SecondCalcFee(){
    signal input MQ, feeRate, days;
    signal output fee;

    signal MQ_feeRate_Product <== MQ * feeRate;

    // Overflow check
    assert((BitsAmount() + BitsRatio() + BitsDays()) <= ConstFieldBits());
    // Underflow check: obviously
    (fee, _) <== IntDivide(BitsAmount())(MQ_feeRate_Product * days, 365 * (10 ** 8));
}

/*
    If the taker is a market buy order, takerSellAmt := takerAvlBQ.

    $$matchedMakerSellAmtIfMQ := Min(remainTakerBuyAmt, remainMakerSellAmt)$$
    $$matchedMakerBuyAmtIfMQ := Min(remainTakerSellAmt, remainMakerBuyAmt)$$
    $$matchedMakerSellAmtIfBQ := \lfloor \frac{matchedMakerBuyAmtIfMQ * makerSignedSellAmt * 365}{d_{MTM} * (makerSignedBuyAmt - makerSignedSellAmt) + 365 * makerSignedSellAmt} \rfloor$$
    $$matchedMakerBuyAmtIfBQ := \lfloor \frac{matchedMakerSellAmtIfMQ * makerSignedBuyAmt * 365}{d_{MTM} * (makerSignedSellAmt - makerSignedBuyAmt) + 365 * makerSignedBuyAmt} \rfloor$$
    $$matchedMakerSellAmtExpected :=
    \begin{cases}
        matchedMakerSellAmtIfBQ &, (isTakerSellOrder) \\
        matchedMakerSellAmtIfMQ &, otherwise
    \end{cases}
    $$
    $$matchedMakerBuyAmtExpected :=
    \begin{cases}
        matchedMakerBuyAmtIfBQ &, (isTakerBuyOrder) \\
        matchedMakerBuyAmtIfMQ &, otherwise
    \end{cases}
    $$
    $$supMQ := \frac{remainTakerAvlBQ * d_{MTM} * makerSignedSellAmt + (365 - d_{MTM}) * makerSignedBuyAmt * remainTakerAvlBQ}{365 * makerSignedBuyAmt}$$
    $$(matchedMakerSellAmt, matchedMakerBuyAmt) := 
    \begin{cases}
        (supMQ, remainTakerAvlBQ) &, (isTakerMarketBuyOrder) \wedge (remainTakerAvlBQ < matchedMakerSellAmtExpected) \\
        (matchedMakerSellAmtExpected, matchedMakerBuyAmtExpected) &, otherwise
    \end{cases}
    $$

    We can ensure, by the definition of the mechanism itself:
    1.  `oriCumTakerBuyAmt` <= `newCumTakerBuyAmt` <= `takerBuyAmt`
    2.  `oriCumTakerSellAmt` <= `newCumTakerSellAmt`( <= `takerSellAmt`, if taker is not a market sell order)
    3.  `oriCumMakerBuyAmt` <= `newCumMakerBuyAmt` <= `makerBuyAmt`
    4.  `oriCumMakerSellAmt` <= `newCumMakerSellAmt` <= `makerSellAmt`
*/
template SecondMechanism(){
    signal input enabled;
    signal input takerOpType;
    signal input takerBuyAmt, takerSellAmt, makerBuyAmt, makerSellAmt;
    signal input makerSide;
    signal input oriCumTakerBuyAmt, oriCumTakerSellAmt, oriCumMakerBuyAmt, oriCumMakerSellAmt;
    signal input days;
    signal output newCumTakerBuyAmt, newCumTakerSellAmt, newCumMakerBuyAmt, newCumMakerSellAmt;

    signal isMarketOrder <== IsEqual()([takerOpType, OpTypeNumSecondMarketOrder()]);

    // If the taker is a market buy order, remainTakerBuyAmt will be meaningless, so it is masked as 0.
    signal isMarketBuyOrder <== (1 - (isMarketOrder * (1 - makerSide)));

    signal remainTakerSellAmt <== takerSellAmt - oriCumTakerSellAmt;
    signal remainMakerSellAmt <== makerSellAmt - oriCumMakerSellAmt;
    signal remainTakerBuyAmt <== (takerBuyAmt - oriCumTakerBuyAmt) * isMarketBuyOrder;
    signal remainMakerBuyAmt <== makerBuyAmt - oriCumMakerBuyAmt;
    
    // $$matchedMakerSellAmtIfMQ := Min(remainTakerBuyAmt, remainMakerSellAmt)$$
    signal matchedMakerSellAmtIfMQ <== Min(BitsAmount())([remainTakerBuyAmt, remainMakerSellAmt]);
    // $$matchedMakerBuyAmtIfMQ := Min(remainTakerSellAmt, remainMakerBuyAmt)$$
    signal matchedMakerBuyAmtIfMQ  <== Min(BitsAmount())([remainTakerSellAmt, remainMakerBuyAmt]);

    // $$matchedMakerSellAmtIfBQ := \lfloor \frac{matchedMakerBuyAmtIfMQ * makerSignedSellAmt * 365}{d_{MTM} * (makerSignedBuyAmt - makerSignedSellAmt) + 365 * makerSignedSellAmt} \rfloor$$
    signal matchedMakerSellAmtIfBQ <== CalcNewBQ()(enabled, matchedMakerBuyAmtIfMQ, makerBuyAmt, makerSellAmt, days);
    // $$matchedMakerBuyAmtIfBQ := \lfloor \frac{matchedMakerSellAmtIfMQ * makerSignedBuyAmt * 365}{d_{MTM} * (makerSignedSellAmt - makerSignedBuyAmt) + 365 * makerSignedBuyAmt} \rfloor$$
    signal matchedMakerBuyAmtIfBQ  <== CalcNewBQ()(enabled, matchedMakerSellAmtIfMQ, makerSellAmt, makerBuyAmt, days);

    // $$matchedMakerSellAmtExpected :=
    // \begin{cases}
    //     matchedMakerSellAmtIfBQ &, (isTakerSellOrder) \\
    //     matchedMakerSellAmtIfMQ &, otherwise
    // \end{cases}
    // $$
    signal matchedMakerSellAmtExpected <== Mux(2)([matchedMakerSellAmtIfBQ, matchedMakerSellAmtIfMQ], makerSide);
    // $$matchedMakerBuyAmtExpected :=
    // \begin{cases}
    //     matchedMakerBuyAmtIfBQ &, (isTakerBuyOrder) \\
    //     matchedMakerBuyAmtIfMQ &, otherwise
    // \end{cases}
    // $$
    signal matchedMakerBuyAmtExpected <== Mux(2)([matchedMakerBuyAmtIfBQ, matchedMakerBuyAmtIfMQ], 1 - makerSide);

    // $$supMQ := \frac{remainTakerAvlBQ * d_{MTM} * makerSignedSellAmt + (365 - d_{MTM}) * makerSignedBuyAmt * remainTakerAvlBQ}{365 * makerSignedBuyAmt}$$
    signal supMQ <== CalcSupMQ()(enabled, remainTakerSellAmt, makerSellAmt, makerBuyAmt, days);

    // $$(matchedMakerSellAmt, matchedMakerBuyAmt) := 
    // \begin{cases}
    //     (supMQ, remainTakerAvlBQ) &, (isTakerMarketBuyOrder) \wedge (remainTakerSellAmt < matchedMakerBuyAmtExpected) \\
    //     (matchedMakerSellAmtExpected, matchedMakerBuyAmtExpected) &, otherwise
    // \end{cases}
    // $$
    // If the taker is a market buy order, takerSellAmt := takerAvlBQ.
    signal slt <== TagLessThan(BitsAmount())([remainTakerSellAmt, matchedMakerBuyAmtExpected]);
    signal isSufficent <== slt * makerSide;
    signal matchedMakerSellAmt <== Mux(2)([matchedMakerSellAmtExpected, supMQ               ], isMarketOrder * isSufficent);
    signal matchedMakerBuyAmt  <== Mux(2)([matchedMakerBuyAmtExpected , remainTakerSellAmt  ], isMarketOrder * isSufficent);

    newCumTakerBuyAmt  <== oriCumTakerBuyAmt  + matchedMakerSellAmt;
    newCumMakerBuyAmt  <== oriCumMakerBuyAmt  + matchedMakerBuyAmt ;
    newCumTakerSellAmt <== oriCumTakerSellAmt + matchedMakerBuyAmt ;
    newCumMakerSellAmt <== oriCumMakerSellAmt + matchedMakerSellAmt;
}

/*
    fee rules:
    1. lend order
        $$Fee := \lfloor \frac{matchedLendingAmt * defaultPIR * feeRate * (days - 1)}{364 * one * one} \rfloor$$
    2. borrow order
        $$Fee := \lfloor \frac{matchedBorrowingAmt * matchedPIR * feeRate * (days - 1)}{364 * one * one} \rfloor$$
    3. secondary order
        $$Fee := \lfloor \frac{matchedMQ * feeRate * days}{364 * one} \rfloor$$

*/
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

    // $$Fee := \lfloor \frac{matchedLendingAmt * defaultPIR * feeRate * (days - 1)}{364 * one * one} \rfloor$$
    signal feeIfLend <== AuctionCalcFee()(req.fee0, matched_amt0, arg, DaysFrom()(matchedTime, req.arg[1]));
    signal feeAsLend <== feeIfLend * isLend;
    
    // $$Fee := \lfloor \frac{matchedBorrowingAmt * matchedPIR * feeRate * (days - 1)}{364 * one * one} \rfloor$$
    signal feeIfBorrow <== AuctionCalcFee()(req.fee0, matched_amt1, arg, DaysFrom()(matchedTime, req.arg[1]));
    signal feeAsBorrow <== feeIfBorrow * isBorrow;

    // $$Fee := \lfloor \frac{matchedMQ * feeRate * days}{364 * one} \rfloor$$
    // fee will be collected uniformly based on base token, taking into account the different scenarios of each side.
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

template AuctionInteract(){
    signal input oriLend[LenOfOrderLeaf()], oriBorrow[LenOfOrderLeaf()], matchedPIR, days;
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
    
    // Matching condition:
    // 1. lend_req.arg[1] == borrow_req.arg[1] (maturity time)
    // 2. lend_req.tokenId == borrow_req.arg[4] (lending token id)
    // 3. lend_req.arg[3] >= borrow_req.arg[3] (PIR)
    isMatched <== And()(TagIsEqual()([lend_req.arg[1]/* maturity time */, borrow_req.arg[1]/* maturity time */]), And()(TagIsEqual()([lend_req.tokenId, borrow_req.arg[4]/* borrowing token id */]), TagGreaterEqThan(BitsRatio())([borrow_req.arg[3]/* PIR */, lend_req.arg[3]/* PIR */])));
    
    // exec auction mechanism
    signal newCumLendingAmt, newCumTSBTokenAmt, newCumBorrowingAmt, newCumCollateralAmt;
    (newCumLendingAmt, newCumTSBTokenAmt, newCumBorrowingAmt, newCumCollateralAmt) <== AuctionMechanism()(enabled, matchedPIR, lend_req.amount, borrow_req.arg[5], borrow_req.amount, lend.cumAmt0, lend.cumAmt1, borrow.cumAmt1, borrow.cumAmt0, days);
    
    // output the execution result
    newLend <== OrderLeaf_Place()(lend.req, newCumLendingAmt * enabled, newCumTSBTokenAmt * enabled, lend.txId * enabled, lend.lockedAmt * enabled, lend.cumFeeAmt * enabled, lend.creditAmt * enabled);
    newBorrow <== OrderLeaf_Place()(borrow.req, newCumCollateralAmt * enabled, newCumBorrowingAmt * enabled, borrow.txId * enabled, borrow.lockedAmt * enabled, borrow.cumFeeAmt * enabled, borrow.creditAmt * enabled);
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

    // Matching condition:
    // 1. takerMqTokenId == makerMqTokenId
    // 2. if taker is not market order, makerBuyAmt * takerBuyAmt <= makerSellAmt * takerSellAmt

    signal takerMqTokenId <== Mux(2)([taker_req.arg[4]/* buyTokenId */, taker_req.tokenId], taker_req.arg[8]/* side */);
    signal makerMqTokenId <== Mux(2)([maker_req.arg[4]/* buyTokenId */, maker_req.tokenId], maker_req.arg[8]/* side */);
    isMatched <== And()(
        TagIsEqual()([takerMqTokenId, makerMqTokenId]),
        Or()(
            TagIsEqual()([taker_req.opType, OpTypeNumSecondMarketOrder()]),
            TagLessEqThan(BitsAmount() * 2)([maker_req.arg[5]/* makerBuyAmt */ * taker_req.arg[5] /* takerBuyAmt */, maker_req.amount /* makerSellAmt */ * taker_req.amount /* takerSellAmt */])
        )
    );
    
    // exec secondary mechanism
    signal newCumTakerBuyAmt, newCumTakerSellAmt, newCumMakerBuyAmt, newCumMakerSellAmt;
    (newCumTakerBuyAmt, newCumTakerSellAmt, newCumMakerBuyAmt, newCumMakerSellAmt) <== SecondMechanism()(enabled, taker_req.opType, taker_req.arg[5], taker_req.amount, maker_req.arg[5], maker_req.amount, maker_req.arg[8], taker.cumAmt1, taker.cumAmt0, maker.cumAmt1, maker.cumAmt0, days);
    
    // output the execution result
    newTaker <== OrderLeaf_Place()(taker.req, newCumTakerSellAmt * enabled, newCumTakerBuyAmt * enabled, taker.txId * enabled, taker.lockedAmt * enabled, taker.cumFeeAmt * enabled, taker.creditAmt * enabled);
    newMaker <== OrderLeaf_Place()(maker.req, newCumMakerSellAmt * enabled, newCumMakerBuyAmt * enabled, maker.txId * enabled, maker.lockedAmt * enabled, maker.cumFeeAmt * enabled, maker.creditAmt * enabled);
}

template RollInteract(){
    signal input oriLend[LenOfOrderLeaf()], oriBorrow[LenOfOrderLeaf()], matchedPIR, days, borrowingTokenId;
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
    signal enabled <== And()(TagIsEqual()([lend_req.opType, OpTypeNumAuctionLend()]), TagIsEqual()([borrow_req.opType, OpTypeNumRollBorrowOrder()]));
    
    // Matching condition:
    // 1. lend_req.arg[1] == borrow_req.arg[1] (maturity time)
    // 2. borrowingTokenId == lend_req.tokenId (lending token id)
    // 3. lend_req.arg[3] >= borrow_req.arg[3] (PIR)
    isMatched <== And()(TagIsEqual()([lend_req.arg[1]/* maturity time */, borrow_req.arg[1]/* maturity time */]), And()(TagIsEqual()([lend_req.tokenId, borrowingTokenId]), TagGreaterEqThan(BitsRatio())([borrow_req.arg[3]/* PIR */, lend_req.arg[3]/* PIR */])));
    
    // exec auction mechanism
    signal newCumLendingAmt, newCumTSBTokenAmt, newCumBorrowingAmt, newCumCollateralAmt;
    (newCumLendingAmt, newCumTSBTokenAmt, newCumBorrowingAmt, newCumCollateralAmt) <== AuctionMechanism()(enabled, matchedPIR, lend_req.amount, borrow_req.arg[5], borrow_req.amount, lend.cumAmt0, lend.cumAmt1, borrow.cumAmt1, borrow.cumAmt0, days);
    
    // output the execution result
    newLend <== OrderLeaf_Place()(lend.req, newCumLendingAmt * enabled, newCumTSBTokenAmt * enabled, lend.txId * enabled, lend.lockedAmt * enabled, lend.cumFeeAmt * enabled, lend.creditAmt * enabled);
    newBorrow <== OrderLeaf_Place()(borrow.req, newCumCollateralAmt * enabled, newCumBorrowingAmt * enabled, borrow.txId * enabled, borrow.lockedAmt * enabled, borrow.cumFeeAmt * enabled, 0);
}