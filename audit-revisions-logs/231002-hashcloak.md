# Audit Revisions Log

## TKS-C-1

*   Definition change: Modified to define quotient and remainder as 0 when "`dividend` is >= 2^253 or `divisor` = 0"
*   Added a new signal `mask` to record whether the above condition is met.
*   Incorporated the `mask` check when assigning values to quotient and remainder.

## TKS-C-2

*   Changed the Alloc check for `order_leaf.cumAmt0`, `order_leaf.cumAmt1`, and `order_leaf.lockedAmt` from `BitsAmount()` to `BitsUnsignedAmt()`

## TKS-C-3

*   Inside the template `DoReqPlaceOrder` at AL-5, changed the bit size check from `BitsTime()` to `BitsTime() + 1`.
*   Inside the template `DoReqPlaceOrder` at AB-7, changed the bit size check from `BitsRatio() + BitsTime()` to `BitsRatio() + BitsTime() + 1`.
*   Inside the template `DoReqPlaceOrder` at SL-7, changed the bit size check from `BitsRatio() + BitsTime()` to `BitsUnsignedAmt() + BitsTime() + 1`.
    *   The additional bit length check was not added here.`MQ` and `BQ` are guaranteed by `Req_Alloc` not to exceed `BitsUnsignedAmt()`, and `days` is ensured by `IntDivide()` not to exceed `BitsTime()`. Their multiplication will never exceed `BitsUnsignedAmt() + BitsTime()`.
*   Inside the template `DoReqCreateTSBToken` at point 2, changed the bit size check from `BitsTime()` to `BitsTime() + 1`.
    *   The additional bit length check was not added here.`p_req.matchedTime[0]` is guaranteed by `PreprocessedReq_Alloc` not to overflow. The sum of the two will never exceed `BitsTime() + 1`.

## TKS-C-4

*   Added a bit length constraint for the `remainder` within the template `IntDivide`.

## TKS-C-5

*   Removed the signal `packedAmt1` from the template `DoReqInteract` and the signal `isSecondaryMarket` from the template `DoReqEnd`.