# Overall introduction
This repository contains an implementation of a zk circuit using circom, designed specifically for zkTrueUp.
# Circuit Design Overview
There is a primary template named `Normal()`, which enforces the following five main sets of constraints:
## Parameter Allocation
Only signals that have been allocated can be correctly placed into the comparator. In the context of this circuit, allocation refers to the restriction of a specific signal to a predetermined number of bits. We allocate some signals and assign parameters to them.
## Request Execution
For each different request, a set of specific constraints is enforced. These constraints will be detailed in the following section. Due to the interaction between some adjacent requests in the circuit system, a series of channels have been implemented between all adjacent Request Execution uints to help this interaction. To ensure that each adjacent request is placed in the same batch, we enforce that the channel data being input to the first Request Execution uint and output from the last Request Execution uint will both be default. After executing each request, we obtain the chunkified calldata to represent each request. The chunk size is defined as 12 bytes. The calldata can be used to emulate state changes that are processed by the operator.
## Packed Chunks
Due to the different chunk counts for each type of request, the chunks are encoded and packed into batch calldata.
## Handling Remaining Requests and Chunks
The slot count for requests and batch calldata is fixed, but it is allowed to use only a portion of them. The remaining requests are referred to as `unknown`, and the remaining transactions in the batch calldata are referred to as `noop`. 
 * We enforce that the requests following `unknown` must also be `unknown`, ensuring that each batch calldata can represent a unique set of requests. 
 * We enforce that the transactions following `noop` must also be `noop`. This allows the calldata used to interact with the contract to contain only the non-trivial part, and ensures that the contract can recover commitment correctly.
## Calculation of Commitment
To decrease the public input count and improve the efficiency of the zero-knowledge proof verification process, we calculate the sha256 hash of the batch calldata and set it as the only public input. This value is referred to as the `commitment`. The contract will recalculate the `commitment` from the batch calldata. We trust that using fake calldata to generate the same `commitment` is sufficiently difficult, ensuring that the calldata calculated in the circuit as private information must be the same as the calldata used to call the contract.
# Mechanism
The file `mechanism.circom` implement the mechanism for auction market, secondary market.

For details, please refer to the mechanism document. 
 * [Auction Mechanism](https://docs.termstructure.com/protocol-spec./primary-markets/auction-mechanism)
 * [Orderbook Mechanism](https://docs.termstructure.com/protocol-spec./secondary-markets/order-book-mechanism)
# State Tree
The state of the system is represented by a State Tree, the details of which can be found at [ZkTrueUp State Tree](https://www.figma.com/file/ih2v8O2DqFEwWtLk1FbXEX/ZkTrueUp-State-Tree?node-id=0-1&t=ykBR39lo9WhQhmP1-0). The State Tree consists of several sub-trees, including an Account Tree, a Token Tree, an Order Tree, a Bond Tree, a Fee Tree, and a Nullifier Tree.

## Account Tree
The Account Tree records the complete state of each account in the system.

## Token Tree
The Token Tree, which is a sub-tree of the Account Tree, records the `avl_amt` and `locked_amt` for each token ID. The `locked_amt` allows users to withdraw locked funds when the evacuation mode is active.

## Ts Root
Users only need to recover their account tree during the evacuation mode. For each batch, we provide a ts root to verify that the user's recovered account tree matches the state root on the chain.

## Order Tree
The Order Tree records all partial orders, with the cumAmt0 field tracking the amount that has been deducted from the corresponding account's locked amount, and the cumAmt1 field tracking the amount that has been sent into the account.

## Bond Tree
The Bond Tree records the maturity and the base token ID for each bond token. If a bond leaf represents a base token, it need to be the default. 

## Fee Tree
The Fee Tree records the fee, only for base tokens.

## Nullifier Tree
When a user intends to place an order, they sign an `orderNonce` instead of a `nonce`. The orderNonce differs from the nonce in that the former is not restricted to being an incrementing value. Consequently, we have implemented a nullifier tree to prevent replay attacks and allow for the reordering of orders.

# Module details
The circuit consists of three primary modules, namely `const`, `gadgets`, and `type`. These modules can be conveniently imported from the file named `_mod.circom`.
## consts
This module defines all the constant parameters that are used in the circuit. These parameters include the enum request type, parameters to format the calldata, the size of basic types, and parameters for the request execution units.
## gadgets
The gadgets module implements several important gadgets that are used in the circuit. These include:
 * Float: This gadget converts a fixed-point number into a floating-point number, which consists of a mantissa and an exponent. The mantissa holds the significant digits of the floating-point number, while the exponent indicates the power of the radix (in our case, 10). The two parts are combined using the following formula:
 ```
 fix := poinmantissa * (10 ^ exponent)
 ```
 * Indexer: This gadget specifies an ordered set of signals, an index number, and an expected value, and checks if this value is contained in the set with the correct order.
 * MerkleTree: This gadget takes in a merkle root, merkle proof, leaf digest, and leaf ID to prove that the leaf exists in the specified merkle tree.
 * tag_comparators: This gadget appends a tag for the comparator that is implemented in circomlib.
 * PoseidonV2: Since the length of inputs for Poseidon cannot exceed 16, we define PoseidonV2 as follows:
 ```
 func PoseidonV2(inputs){
    let res = inputs[0];
    for(var i = 1; i <inputs.len, i +=15)
        res = poseidon([res].join(inputs[i: min(inputs.len, i + 15)]));
    return res;
 }
 ```
 * TsPubKey2TsAddr: This gadget computes the TsAddr from the TsPubkey using the PoseidonV2 function and the following is the formula:
 ```
 TsAddr := PoseidonV2([TsPubkey.x, TsPubkey.y]) % (1 << 160);
 ```
 * ImplyEq: This gadget specifies two values and a switch signal called `enabled`, and enforces that if `enabled` is true, then these two values must be the same.
 * others: This module also implements some basic math operators.
 ## type
 The type module in the `_mod.circom` file defines all of the types that are used throughout the circuit, while the other files under the type folder implement methods for each type.
 Circom help us to deduce trivial non-linear constraints, which enables us to express a type using a template. For example, we can define the TokenLeaf type as follows:
 ```
 function LenOfTokenLeaf(){
     return 2;
 }
 template TokenLeaf(){
     signal input arr[LenOfTokenLeaf()];
     signal output (avl_amt, locked_amt) <== (arr[0], arr[1]);
 }
 ```
 We can then decord the signal arr `tokenLeaf[..]` as follows:
 ```
 component token = TokenLeaf();
 token.arr <== tokenLeaf;
 ```
 Finally, we can set constraints for token.avl_amt and token.locked_amt.

When designing the methods, we draw on concepts from functional programming. The immutable feature is similar to the witness structure for zk proof. The method is designed as follows:
```
template TokenLeaf_Incoming(){
    signal input tokenLeaf[LenOfTokenLeaf()], amount;
    signal output arr[LenOfTokenLeaf()] <== TokenLeaf_Alloc()([tokenLeaf[0] + amount, tokenLeaf[1]]);/
}
```
The output of the method is the newly allocated token leaf.

The following are the types that are used in this circuit:
### Basic Data Types

<!-- prettier-ignore -->
|Type|Bit len|--|
|--|--|--|
|ReqType| 8 | unsigned |
|TokenId| 16 | unsigned |
|AccId| 32 | unsigned |
|Nonce| 64 | unsigned |
|Amount| 121 | signed |
|UnsignedAmt| BitsAmount - 1 | unsigned |
|Time| 64 | unsigned |
|Ratio| 64 | unsigned |
|Chunk| 8 * 12 | unsigned |
|TsAddr| 8 * 20 | unsigned |
|Epoch| 128 | unsigned |
|Side| 1 | unsigned |
### Req
type for req. It's will be detailed in the following section.
### Sig
type for signature.
 * Field: tsPubKeyX, tsPubKeyY, RX, RY, S;
### State
type for State.
 * Field: feeRoot, bondRoot, orderRoot, accRoot, nullifierRoot[2], adminTsAddr, txCount;
 * Epoch: epoch[2];
### Unit<Leaf, TreeHeight>
 * unit<TreeHeight>: LeafId;
 * Leaf: oriLeaf, newLeaf;
 * Field: oriRoot, newRoot;
 * Field[]: merkle proof;
### TokenLeaf
 * Amount: avlAmt
 * UnsignedAmt: lockedAmt;
### TokenUnit
 * Unit<TokenLeaf, TokenTreeHeight>
### AccLeaf
 * TsAddr: txAddr;
 * Nonce: nonce;
 * field: tokens; represent token tree root;
### AccUnit
 * Unit<AccLeaf, AccTreeHeight>
### OrderLeaf
 * Req: req;
 * Field: txId;
 * UnsignedAmt; cumAmt0, cumAmt1, lockedAmt;
### OrderUnit
 * Unit<OrderLeaf, OrderTreeHeight>
### FeeLeaf
 * UnsignedAmt; fee;
### FeeUnit
 * Unit<FeeLeaf, FeeTreeHeight>
### BondLeaf
 * TokenId: baseTokenId;
 * Time: maturity;
### BondUnit
 * Unit<BondLeaf, BondTreeHeight>
### NullifierUnit
 * Unit<Field[8], NullifierTreeHeight>
### UnitSet
 * TokenUnits[]
 * AccUnits[]
 * OrderUnits[]
 * FeeUnits[]
 * BondUnits[]
 * NullifierUnits[]
### PreprocessedReq
 * Req;
 * Sig;
 * UnitSet;
 * Chunk[]: chunks;
 * bool: nullifierTreeId
 * uint3: nullifierElemId
 * Time: matchedTime
### Channel
 * OrderLeaf;
 * field[]: args;
# request details
The data type of requests be defined as follows:
|Request|reqData[0]|reqData[1]|reqData[2]|reqData[3]|reqData[4]|reqData[5]|reqData[6]|reqData[7]|reqData[8]|reqData[9]|reqData[10]|reqData[11]|reqData[12]|reqData[13]|reqData[14]|reqData[15]|reqData[16]|
|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|
|Symbol|reqType|accountId|tokenId|amount|nonce|fee0|fee1|arg0|arg1|arg2|arg3|arg4|arg5|arg6|arg7|arg8|arg9|
|DataType|ReqType|AccId|TokenId|UnsignedAmt|Nonce|Ratio|Ratio|AccId|Time|Time|Ratio|TokenId|UnsignedAmt|TsAddr|Epoch|Side|--|
|noop|0|||||||||||||||||
|register|1|||||||receiverId||||||tsAddr||||
|deposit|2||tokenId|amount||||receiverId||||||||||
|forcedWithdraw|3||tokenId|||||receiverId||||||||||
|transfer|4|senderId|tokenId|amount|nonce|||receiverId||||||||||
|withdraw|5|senderId|tokenId|amount|nonce|||||||||||||
|auctionLend|6|senderId|lendTokenId|lendAmt|orderNonce|auctionLendFeeRate|||maturityTime|expiredTime|interest (decimals = 6)||||epoch|||
|auctionBorrow|7|senderId|collateralTokenId||orderNonce|auctionBorrowFeeRate|||maturityTime|expiredTime|interest|borrowTokenId|borrowAmt||epoch|||
|auctionStart|8||||||||||matchedInterest|||||||
|auctionMatch|9|||||||||||||||||
|auctionEnd|10|||||||||||||||||
|secondLimitOrder|11|senderId|sellTokenId|sellAmt|orderNonce|secondaryTakerFeeRate|secondaryMakerFeeRate|||expiredTime||buyTokenId|buyAmt||epoch|side (buy=0, sell=1)||
|secondLimitStart|12|||||||||||||||||
|secondLimitExchange|13|||||||||||||||||
|secondLimitEnd|14|||||||||||||||||
|secondMarketOrder|15|senderId|sellTokenId|sellAmt|orderNonce|secondaryTakerFeeRate||||expiredTime||buyTokenId|buyAmt||epoch|side||
|secondMarketExchange|16|||||||||||||||||
|secondMarketEnd|17|||||||||||||||||
|adminCancelOrder|18|||||||||||||||||
|userCancelOrder|19|senderId|||||||orderTxId|orderNum||||||||
|increaseEpoch|20|||||||||||||||||
|createBondToken|21||bondTokenId||||||maturityTime|||baseTokenId||||||
|redeem|22|senderId|bondTokenId|amount|nonce|||||||||||||
|withdrawFee|23||tokenId|||||||||||||||
|evacuation|24||tokenId|||||senderId||||||||||
|setAdminTsAddr|25|||||||||||||tsAddr||||

## common
### signature
There are three types of requests: L1-request, L2-admin-request, and L2-user-request.
 * L1-request is emitted by the contract.
 * L2-admin-request is sent from the admin.
 * L2-user-request is sent from the user.
 
L2-user-request requires verification of the user's signature. If the adminTsAddr in the state is not default, L1-request and L2-admin-request, also commonly known as admin-request, need to verify the admin's signature. Ortherwise, the signature verifier will be ignored.
### unit set
All units in the unit set will be enforced, but only a subset of them will be considered with the main state flow.
## Additional Request Details
The constraints for each type of request can be further categorized into three main parts:
 * Legality: This part checks if the request is legal based on various criteria, such as whether the balance is sufficient or not.
 * Correctness: check the new state is correct, which is the signal assigned from parameter.
 * Chunkify: This part encodes the calldata that will interact with the contract.
    * For details, please refer to [ZkTrueUp Spec](https://docs.google.com/spreadsheets/d/1NL2Y0Gz_Xczo1ZUPZoifMk3-zTM84bQt7BtaZiZSUFU/edit#gid=2074446946). 

### Unknown
The `Unknown` request should not alter the state.

legality: none.

correctness: 
 * the original state is equeal to the new state.

### Register
Register new account into the specified account leaf.

legality: 
 * oriAccLeaf is default.

correctness: 
 * oriAccLeaf.nonce is equal to newAccLeaf.nonce
 * newAccLeaf.addr is same to info from req.

### Deposit
Making a deposit of a specified amount into a specified account.

legality: none.

correctness:
 * (oriAccLeaf.nonce, oriAccLeaf.addr) is equal to (newAccLeaf.none, newAccLeaf.addr).
 * token leaf 
    * incoming

### Forced Withdraw
This is a L1-request that was emitted from a contract, and it requires us to batch it within a specified time.

legality: none.

correctness:
 * outgoing all of available amount.

### Transfer
Transfer specified amount from specified sender account to specified receiver account.

legality:
 * sender 
    * nonce check
    * is sufficient or not

correctness:
 * sender
    * nonce increase
    * outgoing
 * receiver
    * incoming

### Withdraw
Withdraw specified amount from specified account.

legality:
 * nonce check
 * is sufficient or not

correctness:
 * nonce increase
 * outgoing

### Place Order:
When a user intends to place an order, they sign an `orderNonce` instead of a `nonce`. The orderNonce differs from the nonce in that the former is not restricted to being an incrementing value. Consequently, we have implemented a nullifier tree to prevent replay attacks and allow for the reordering of orders.

When an order is placed, it will be inserted into an order tree, which will be considered a partial order.

1. lend order, borrow order, secondary limit order
    * Upon submitting these request, the indicated amount will be locked:
       * Lend order: `lockAmt := lendingAmt + lendingAmt * feeRate * daysFromMatchedTime / 365`
       * borrow order: `lockAmt := collateralAmt`
       * secondary limit order:
          * buy: `lockAmt := 365 * MQ * BQ / (daysFromExpiredTime * MQ + (365 - daysFromExpiredTime * BQ))`
          * sell: `lockAmt := MQ`
    * Upon submitting these request, it will be consider as partial order first.
    * legality:
       * is sufficient to lock or not
       * check expiration
       * check epoch is equal to the epoch of the specified nullifier tree
       * check nullifier collision
       * check the expected nullifier slot is default
       * check `currentTime - matchedTime < 86400`
    * correctness
       * lock amt
       * place digest into nullifier leaf correctly
       * place order into order leaf correctly
2. secondary market order
    * legality:
       * check expiration
    * correctness: none.
    * This request will be regarded as the `Start Request` for further request, which will be explained below.

### Match
We employ a series of requests to express a match between two orders as follows:
 * Start Request: This request removes the order from order tree and places it in the channel. In the case of a market order, it will place itself in the channel. After this request, either an interactive request or request termination is allowed.
    * legality:
       * check the req type of specified order
       * check expiration of specified order
    * correctness:
       * default order leaf
 * Interact Request: This request identifies an order in the order tree and matches it with the order from the channel. The matched order in the order tree will be updated with the result of the match, and the sender's account associated with the order will be updated accordingly. The order from the channel will also be updated accordingly. After this request, either an interactive request or request termination is allowed.
    * legality:
       * check the req type for both the specified order and the order from channel.
       * check the order pair can be matched or not.
       * check `currentTime - matchedTime < 86400`.
       * If fee need be deducted from target amout, check it's sufficient or not.
       * Auction: (specified order is lend order)
          * check interest is less than matched interest.
          * check interest is greater than or equal to interest of previous lend order.
    * correctness:
       * update order leaf. If it's full, default it and refund remaining locked amount.
       * update sender's account accordingly.
       * For details, please refer to the mechanism document. 
          * [Auction Mechanism](https://docs.termstructure.com/protocol-spec./primary-markets/auction-mechanism)
          * [Orderbook Mechanism](https://docs.termstructure.com/protocol-spec./secondary-markets/order-book-mechanism)
 * End Request: This request places the order from the channel back into the order tree, and updates the sender's account to reflect the changes. After this request, the channel need to be default. In the case of a market order, it should not be place back into the order tree.
    * legality:
       * check specified order leaf slot is default.
       * check the req type of the order from channel.
       * check `currentTime - matchedTime < 86400`.
       * If fee need be deducted from target amout, check it's sufficient or not.
       * Auction: check matched interest is equal to interest of last lend order.
    * correctness:
       * update order leaf. If it's full, default it and refund remaining locked amount.
       * update sender's account accordingly.

### Cancel
Remove a specified order from the order tree and initiate a refund of the remaining locked amount.

There are two type of cancel request: admin cancel, user cancel.

 * legaltiy:
    * If it is a user cancel, check the sender of order is equal to the sender of request.

 * correctness:
    * If it is a user cancel, check txId of specified order is correct.
    * default the order, and refund remaining locked amount.

### increaseEpoch
Add 2 to the epoch value that is smaller, and set the corresponding nullifier tree to its default value.

 * legality: none.

 * correctness:
    * Add 2 to the smaller epoch
    * Default the nullifier tree accordingly

### createBondToken
Add a new bond to the bond tree that record the maturity and the base token ID.

 * legality: none.

 * correctness:
    * place a bond info into bond tree basing on the request.

### redeem
Convert the bond token into its corresponding base token.

 * legality:
    * nonce check
    * sufficient check
    * check `currentTime > maturityTime`
 * correctness:
    * outgoing bond token
    * incoming base token

### withdrawFee
Withdraw the fee of specified token id from fee tree to the L1 admin balance.

 * legality: none.

 * correctness:
    * default fee leaf.

### evacuation
When the evacuation mode is activated, we prevent excessive changes to the state root by requesting the user to withdraw all of their "avl_amt" and "locked_amt" at once. Consequently, we must employ this request to update the state tree upon concluding the evacuation mode.

 * legality: none.

 * correctness:
    * outgoing `avl_amt + locked_amt`. `avl_amt` would be negative.