# Overall introduction

This repository contains an implementation of zkTrue-up built with [circom](https://docs.circom.io/).

# Circuit Design Overview

The primary circuit, [`Normal()`](./circuits/zkTrueUp/normal.circom) enforces the following five types of constraints:
1. [Parameter Allocation](#parameter-allocation)
2. [Request Execution](#request-execution)
3. [Chunk Packing](#chunk-packing)
4. [Request & Chunk Handling](#request--chunk-handling)
5. [Commitment Calculation](#commitment-calculation)

Each of these are shown below in more detail.

## Parameter Allocation

Before any operations or comparisons are executed, all signals must first be _allocated_. This is done by verifying that they are each represented by a predefined number of bits.

## Request Execution

A unique set of constraints applies to each type of request, which are enforced in this section. A batch of requests (or one block from the Layer 2) is always processed in a sequence: we use a channel to transmit data from one request to the next. For the first and last request we insert default values into the channel, as they lack a preceding or subsequent request, respectively.

Request data is segmented into chunks, each 12 bytes in size. This is sent to the smart contract as _calldata_, which can be used to simulate the operations performed by the Operator for the Layer 2. This simulation is crucial for users aiming to reconstruct the transaction history in evacuation mode. 

## Chunk Packing

An L2 block contains multiple requests. We segment these requests into a byte array, which then serves as the _calldata_ for that block.

## Request & Chunk Handling

 The quantity of requests and the length of the chunkified requests in _calldata_ for each block are predefined and consistent. However, not all slots get used for every block. All of the unused request slots will be populated with `noop` requests, and any unused _calldata_ slots in the block will be filled with `noop` data as well.

 Within each L2 block, the `noop` requests must always follow the requests containing transaction data, and cannot be inserted among these requests. If there is any `noop` request data in the middle of an L2 block, all subsequent requests must also be `noop`. This ensures that the state root has a unique true value. Without this mechanism, the value of the rebuilt state root could have multiple potential values, leading to issues in evacuation mode. Likewise, `noop` data in the chunkified requests also needs to follow any other filled data. All data following a `noop` must also be `noop`. This guarantees the accuracy of the commitments sent to the zkTrue-up smart contract.

## Commitment Calculation

To enhance the efficiency of the verification process by reducing the number of public inputs, we generate the SHA256 hash of the _calldata_ values in each block as the `commitment` (the only public input for the circuit). The smart contract verifies the consistency between the input `commitment` provided by the Operator and the `commitment` value generated onchain. We rely on the collision resistance of SHA256 to ensure that a legitimate `commitment` cannot be generated with counterfeit values.

# Mechanism

The file [`mechanism.circom`](./circuits/zkTrueUp/src/mechanism.circom) includes the mechanisms based on the business logic of the Primary Markets and the Secondary Markets.

For more details, please refer to the documents below: 

 * [Auction Mechanism for Primary Markets](https://docs.termstructure.com/protocol-spec./primary-markets/auction-mechanism)
 * [Orderbook Mechanism for Secondary Markets](https://docs.termstructure.com/protocol-spec./secondary-markets/order-book-mechanism)

# State Tree

The transaction states made within Term Structure are stored within the State Tree, which is composed of the Account Tree and the TS Tree. The State Tree is crucial in the evacuation mode.

<a href="https://drive.google.com/uc?export=view&id=19N4A9i1rIF3EYBgjriQ_Y20KZIiu2PKh"><img src="https://drive.google.com/uc?export=view&id=19N4A9i1rIF3EYBgjriQ_Y20KZIiu2PKh" style="width: 650px; max-width: 100%; height: auto" title="State Tree" /></a>

The details of State Tree can be found at [zkTrue-up State Tree](https://www.figma.com/file/ih2v8O2DqFEwWtLk1FbXEX/zkTrue-up-State-Tree?node-id=0-1&t=ykBR39lo9WhQhmP1-0). 

## Account Tree

The Account Tree records the complete state of each account in the system. The Account Tree cannot be retrieved directly from the contract. Instead, it can be rebuilt with the TS Root and that State Root, both of which are stored on the _calldata_. With the Account Tree rebuilt, users can withdraw their asssets in evacuation mode.

## Token Tree

Each account in the Account Tree has their own Token Tree associated with it, which records the `avl_amt` and `locked_amt` for each token ID. The `locked_amt` allows users to withdraw locked funds once the evacuation mode is activated.

<a href="https://drive.google.com/uc?export=view&id=1XIboBxRwoG5mBMAIv_p6nypHnpwbytwJ"><img src="https://drive.google.com/uc?export=view&id=1XIboBxRwoG5mBMAIv_p6nypHnpwbytwJ" style="width: 650px; max-width: 100%; height: auto" title="Account Tree" /></a>

## TS Root

TS root, the abbreviation for Term Structure root, is the hash value of all of its sub-tree roots. This includes the Order Tree, tsbToken Tree, Fee Tree, and Nullifier Tree. 

<a href="https://drive.google.com/uc?export=view&id=1hvJFnh5MbIu0b9dH5U3DfYu7im8MuUB7"><img src="https://drive.google.com/uc?export=view&id=1hvJFnh5MbIu0b9dH5U3DfYu7im8MuUB7" style="width: 650px; max-width: 100%; height: auto" title="TS Tree" /></a>

## Order Tree

The Order Tree records all partially-filled orders. Each order contains two different payment directions. The designation ending with '0' indicates the amount that a user is expected to pay or already paid, while that ending with '1' signifies the amount the user is expected to receive or already received.

For instance:

 * amount0 is the amount a user is set to pay.
 * amount1 is the amount a user is set to receive.
 * cumAmt0 is the cumulative amount the user has already paid (for instance, the collateral a borrower has already placed in an order).
 * cumAmt1 is the cumulative amount the user has already received (for instance, the loan amount a borrower has received from an order).

<a href="https://drive.google.com/uc?export=view&id=1JGgyeyR-pVJziKYm79E-pBAAw-2oWujI"><img src="https://drive.google.com/uc?export=view&id=1JGgyeyR-pVJziKYm79E-pBAAw-2oWujI" style="width: 650px; max-width: 100%; height: auto" title="Order Tree" /></a>

## tsbToken Tree

The tsbToken Tree records the base token ID and maturity time for each TSB token. The base token IDs occupy the first 100 slots of the tsbToken Tree, while the subsequent slots are populated by TSB tokens with varying base tokens and maturity times.

<a href="https://drive.google.com/uc?export=view&id=1UqDP74ZTkuCMMxq8GhcLdBl2mMlwYIZI"><img src="https://drive.google.com/uc?export=view&id=1UqDP74ZTkuCMMxq8GhcLdBl2mMlwYIZI" style="width: 650px; max-width: 100%; height: auto" title="tsbToken Tree" /></a>

## Fee Tree

The Fee Tree records the amount of fees charged for each base token, in a similar structure to the token tree. Fees are charged when orders get matched.

<a href="https://drive.google.com/uc?export=view&id=1ckZ-fQYpxU9m_UQoLcCKZJO3oSFrO55i"><img src="https://drive.google.com/uc?export=view&id=1ckZ-fQYpxU9m_UQoLcCKZJO3oSFrO55i" style="width: 650px; max-width: 100%; height: auto" title="Fee Tree" /></a>

## Nullifier Tree

When a user places an order, the system generates a deterministic random number `orderNonce`, rather than an incremental `nonce`. If different orders possess the same transaction data and identical `orderNonce`, their hash values will also be the same. The system will reject these repeated orders, effectively preventing replay attacks.

<a href="https://drive.google.com/uc?export=view&id=1E7qUv6OlSe1coKTPbCLwwJs4GgVkYELz"><img src="https://drive.google.com/uc?export=view&id=1E7qUv6OlSe1coKTPbCLwwJs4GgVkYELz" style="width: 650px; max-width: 100%; height: auto" title="Fee Tree" /></a>

# Module details

The circuit is composed of three primary modules: [`const`](./circuits/zkTrueUp/src/const/), [`gadgets`](./circuits/zkTrueUp/src/gadgets/), and [`type`](./circuits/zkTrueUp/src/type/). Each of these modules can be imported from its `_mod.circom` file.

## `consts`

This module defines all the constant parameters used in the circuit. These include the enumerated request types, parameters for _calldata_ formatting, the size of basic types, and parameters for the request execution units.

## `gadgets`

The gadgets module includes several critical gadgets employed in the circuit. These are:

 * Float: This gadget transforms a fixed-point number into a floating-point number. The floating-point number comprises a mantissa and an exponent. The mantissa holds the significant figures of the floating-point number, while the exponent represents the power of the radix (in our case, 10). These two components are combined using the following formula:

 ```
 fix := mantissa * (10 ^ exponent)
 ```

 * Indexer: This gadget specifies an ordered set of signals, an index number, and an expected value, and checks if this value is contained in the set with the correct order.
 * MerkleTree: This gadget takes in a Merkle root, Merkle proof, leaf digest, and leaf ID to prove that the leaf exists in the specified Merkle tree.
 * tag_comparators: This gadget appends a tag for the comparator that is implemented in circomlib.
 * PoseidonArbitraryLen: Since the length of inputs for Poseidon cannot exceed 16, we define PoseidonArbitraryLen as follows:
 ```
 func PoseidonArbitraryLen(inputs){
    let res = inputs[0];
    for(var i = 1; i <inputs.len, i +=15)
        res = poseidon([res].join(inputs[i: min(inputs.len, i + 15)]));
    return res;
 }
 ```
 * PoseidonSpecificLen: Since `PoseidonArbitraryLen()` is not collision resistant for different `len`, we define PoseidonSpecificLen as follows:
 ```
 func PoseidonSpecificLen(inputs){
    return res = poseidon([inputs.len].join(inputs));
 }
 ```
 * TsPubKey2TsAddr: This gadget computes the TsAddr from the TsPubkey via the following formula:
 ```
 TsAddr := Poseidon([TsPubkey.x, TsPubkey.y]) % (1 << 160);
 ```
 * ImplyEq: This gadget specifies two values and a switch signal called `enabled`, and enforces that if `enabled` is true, then these two values must be equal.
 * others: This module implements some basic math operators.

## `type`

The `type` module in the `_mod.circom` file defines all of the types that are used throughout the circuit, while the other files under the type folder implement methods for each of these types.

Circom help us to deduce trivial non-linear constraints, which enables us to express a type using a template. For example, we can define the TokenLeaf type as follows:
```
function LenOfTokenLeaf() {
    return 2;
}

template TokenLeaf() {
    signal input arr[LenOfTokenLeaf()];
    signal output (avl_amt, locked_amt) <== (arr[0], arr[1]);
}
```
We can then decode the signal arr `tokenLeaf[..]` as follows:
```
component token = TokenLeaf();
token.arr <== tokenLeaf;
```
Finally, we can set constraints for token.avl_amt and token.locked_amt.

When designing these methods, we draw on concepts from functional programming. The immutable feature is similar to the witness structure for zk proof. The method is designed as follows:
```
template TokenLeaf_Incoming(){
    signal input tokenLeaf[LenOfTokenLeaf()];
    signal input enabled;
    signal input amount;
    _ <== Num2Bits(BitsUnsignedAmt())(amount * enabled);
    signal output arr[LenOfTokenLeaf()] <== TokenLeaf_Alloc()([(tokenLeaf[0] + amount) * enabled, tokenLeaf[1] * enabled]);
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
|Amount| 115 | signed |
|UnsignedAmt| BitsAmount - 1 | unsigned |
|Time| 64 | unsigned |
|Ratio| 32 | unsigned |
|Chunk| 8 * 12 | unsigned |
|TsAddr| 8 * 20 | unsigned |
|Epoch| 128 | unsigned |
|Side| 1 | unsigned |

### Req

Type for req. It is detailed in the [following section](#requests).

### Sig

Type for signature.

 * Field: tsPubKeyX, tsPubKeyY, RX, RY, S;

### State

Type for State.

 * Field: feeRoot, tsbTokenRoot, orderRoot, accRoot, nullifierRoot[2], adminTsAddr, txCount;
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
 * UnsignedAmt: cumAmt0, cumAmt1, lockedAmt, creditAmt, cumFeeAmt;

### OrderUnit

 * Unit<OrderLeaf, OrderTreeHeight>

### FeeLeaf

 * UnsignedAmt; fee;

### FeeUnit

 * Unit<FeeLeaf, FeeTreeHeight>

### tsbTokenLeaf

 * TokenId: baseTokenId;
 * Time: maturity;

### tsbTokenUnit

 * Unit<tsbTokenLeaf, tsbTokenTreeHeight>

### NullifierUnit

 * Unit<Field[8], NullifierTreeHeight>

### UnitSet

 * TokenUnits[]
 * AccUnits[]
 * OrderUnits[]
 * FeeUnits[]
 * tsbTokenUnits[]
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

# Requests

The detailed constraints specified in the circuit are listed in [Requests Handling and Verification](#requests-handling-and-verification);

The data type of requests be defined as follows:

|Request <br> Symbol <br> DataType|reqData[0] <br> reqType <br> uint8|reqData[1] <br> accountId <br> uint32|reqData[2] <br> tokenId <br> uint16|reqData[3] <br> amount <br> uint114|reqData[4] <br> nonce <br> uint64|reqData[5] <br> fee0 <br> uint32|reqData[6] <br> fee1 <br> uint32|reqData[7] <br> txFeeTokenId <br> uint16|reqData[8] <br> txFeeAmt <br> uint114|reqData[9] <br> arg0 <br> uint32|reqData[10] <br> arg1 <br> uint32|reqData[11] <br> arg2 <br> uint32|reqData[12] <br> arg3 <br> uint32|reqData[13] <br> arg4 <br> uint16|reqData[14] <br> arg5 <br> uint114|reqData[15] <br> arg6 <br> bytes20|reqData[16] <br> arg7 <br> uint128|reqData[17] <br> arg8 <br> bool|reqData[18] <br> arg9 <br> uint32|reqData[19] <br> arg10 <br> field|reqData[20] <br> arg11 <br> uint114|reqData[21] <br> arg12 <br> uint114|
|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|
|noop|0||||||||||||||||||||||
|register|1|||||||||receiverId||||||tsAddr|||||||
|deposit|2||tokenId|amount||||||receiverId|||||||||||||
|forceWithdraw|3||tokenId|||||||receiverId|||||||||||||
|transfer|4|senderId|tokenId|amount|nonce|||||receiverId|||||||||||||
|withdraw|5|senderId|tokenId|amount|nonce|||txFeeTokenId|txFeeAmt||||||||||||||
|auctionLend|6|senderId|lendTokenId|lendAmt|orderNonce|auctionLendFeeRate|||||maturityTime|expiredTime|PIR(principal and interest rate)||||epoch||defaultMatchedInterestRate|||primaryLendMinFeeAmt|
|auctionBorrow|7|senderId|collateralTokenId|collateralAmt|orderNonce|auctionBorrowFeeRate|||||maturityTime|expiredTime|PIR|borrowTokenId|borrowAmt||epoch||||primaryBorrowMinFeeAmt||
|auctionStart|8||||omNonce||||||||matchedPIR||||||||||
|auctionMatch|9||||omNonce||||||||||||||||||
|auctionEnd|10||||omNonce||||||||||||||||||
|secondLimitOrder|11|senderId|sellTokenId|sellAmt|orderNonce|secondaryTakerFeeRate|secondaryMakerFeeRate|||||expiredTime||buyTokenId|buyAmt||epoch|side (buy=0, sell=1)|||secondaryTakerMinFeeAmt|secondaryMakerMinFeeAmt|
|secondLimitStart|12||||omNonce||||||||||||||||||
|secondLimitExchange|13||||omNonce||||||||||||||||||
|secondLimitEnd|14||||omNonce||||||||||||||||||
|secondMarketOrder|15|senderId|sellTokenId|sellAmt|orderNonce|secondaryTakerFeeRate||||||expiredTime||buyTokenId|buyAmt||epoch|side|||secondaryTakerMinFeeAmt||
|secondMarketExchange|16||||omNonce||||||||||||||||||
|secondMarketEnd|17||||omNonce||||||||||||||||||
|adminCancelOrder|18||||omNonce||||||||||||||||||
|userCancelOrder|19|senderId||||||txFeeTokenId|txFeeAmt||orderTxId|orderNum||||||||orderHash|||
|increaseEpoch|20||||omNonce||||||||||||||||||
|createTsbToken|21||bondTokenId||||||||maturityTime|||baseTokenId|||||||||
|redeem|22|senderId|bondTokenId|amount|nonce||||||||||||||||||
|withdrawFee|23||tokenId||opNonce||||||||||||||||||
|evacuation|24||tokenId|||||||senderId|||||||||||||
|setAdminTsAddr|25||||opNonce|||||||||||tsAddr|||||||
|rollBorrowOrder|26||collateralTokenId|collateralAmt||primaryBorrowFeeRate||||senderId|maturityTime|expiredTime|PIR|oriTsbTokenId|borrowAmt||epoch||||
|rollOverStart|27||||omNonce||||||||matchedPIR||||||||
|rollOverMatch|28||||omNonce||||||||||||||||
|rollOverEnd|29||||omNonce||||||||||||||||
|userCancelRollBorrow|30|senderId|||||||||||​|​|​||​|||orderHash|
|adminCancelRollBorrow|31||||omNonce||||||||||||||||
|forceCancelRollBorrow|32||||omNonce||||||||||||||||

## General Constraints for All Requests

### Signature

There are three kinds of requests: L1-request, L2-admin-request, and L2-user-request.

 * L1-request is emitted by the contract.
 * L2-admin-request is sent by the admin.
 * L2-user-request is sent by the user.
 
An L2-user-request requires verification of the user's signature. Both L1-request and L2-admin-request (also known as admin-request) need to verify the admin's signature if the `adminTsAddr` is not the default value.

### Unit Set

All units in the UnitSet will be enforced, but only a subset of them will be considered with the main state flow.

### Minimum Fee Mechanism

When a user signs an order, they consent to the `minFee` amount specified as the minimum fee. Initially, upon the first match of an order, we charge an amount equivalent to the signed `minFee` as an initial credit before proceeding with the matching process.

As the order continues to match repeatedly, the transaction fee required from the user will gradually increase. However, any additional fees are only charged once the accumulated fees exceed the initial credit amount.

If the fees for an order are derived from `matchedAmt` and the `matchedAmt` for a match is insufficient to cover the credit amount, the remaining credit will be carried over and charged in subsequent matches.

A unique feature of our mechanism is that an order can assume different roles in various matches. For example, a secondary limit order might act as a taker in its first match and as a maker in later ones. In such scenarios, different `minFee` rates may apply based on the order's role. Therefore, we include an additional rule: if the signed `minFee` differs from the initial credit amount and `minFee` is greater, we will charge the difference between the signed minFee and the original credit, updating the credit amount as needed.   

The following outlines the specific operational flow for implementing the `minFee` mechanism:

-   Calc `minFee` as the maximum of the following:
    -   `oriCreditAmt`
    -   `signedMinFee`
-   Calc `newCreditAmt` 
    -   For the buy order and lend order:
        -   `newCreditAmt := minFee`
    -   For the sell order and borrower order:
        -   `newCreditAmt := Min(minFee, Max(oriCreditAmt, oriCumFeeAmt) + matchedAmt)` 
-   Calc `chargedCreditAmt` as the minimum of the following:
    -   `newCreditAmt` - `oriCreditAmt` 
    -   `newCreditAmt` > `oriCumFeeAmt ? newCreditAmt - oriCumFeeAmt : 0` 
-   Update the accumulated fee amount: `newCumFeeAmt = oriCumFeeAmt + matchedFeeAmt` 
-   Calc chargedFeeAmt as the minimum of the following:
    -   `newCumFeeAmt > newCreditAmt ? newCumFeeAmt - newCreditAmt : 0` 
    -   `matchedFeeAmt` 
-   And the `totalChargedAmt` will be `chargedCreditAmt + chargedFeeAmt` .
    -   If it's a borrow order or a sell order, circuit will reject when `totalChargedAmt > matchedAmt` 

## Specific Constraints for Each Requests

The constraints for each kind of request can be further categorized into three main categories:

 * Legitimacy: which checks if the request is valid based on various criteria, such as whether the balance is sufficient or not.
 * Correctness: which checks if the new state is correct, which is the signal assigned from parameters.
 * Chunkify: which encodes the _calldata_ that will interact with the contract.

For details, please refer to [zkTrue-up Data Format](https://docs.google.com/spreadsheets/d/1rIm7ZiCstLlWJNHMuF6tJgLEmgwcz0LCJJl7c_LCKS0/edit#gid=0). 

### Noop

The `Noop` request should not alter the state.

Legitimacy: none.

Correctness: The original state is equal to the new state.

### Register

Registers a new account into the specified account leaf.

Legitimacy: `oriAccLeaf` is the default value.

Correctness: 

 * `oriAccLeaf.nonce` is equal to `newAccLeaf.nonce`
 * `newAccLeaf.addr` is equal to the address in the request

### Deposit

Specifies a despoit amount to an account.

Legitimacy: none.

Correctness:

 * (`oriAccLeaf.nonce`, `oriAccLeaf.addr`) equals (`newAccLeaf.none`, `newAccLeaf.addr`).
 * Token leaf 
 * Amount to receive

### Force Withdraw

This is a L1 request emitted from the contract. The system must process the request within a specified period after receiving this request.

Legitimacy: none.

Correctness: withdraw all of the available amount.

### Transfer

Transfers a specified amount of tokens from a sender account to a receiver account.

Legitimacy:

 * Sender 
    * Nonce check
    * Check if the account has sufficient balance to send the amount

Correctness:

 * Sender
    * Nonce increase
    * Debit amount to send
 * Receiver
    * Credit amount to receive

### Withdraw

Withdraws a specified amount of tokens from a specified account. Note that these can be either base tokens (like USDC, USDT, ...) or any issued tsbToken.

Legitimacy:

 * Nonce check
 * Check if the account has sufficient balance to withdraw the amount

Correctness:

 * Nonce increase
 * Debit amount to withdraw

### Place Order:

When a user places an order, they sign an `orderNonce` instead of a `nonce`. See [Nullifier Tree](#nullifier-tree). 

The order will be added into the Order Tree and is treated as a partial order.

1. Lend orders, borrow orders in the Primary Markets; and limit orders in the Secondary Markets
    * Upon submitting these request, the indicated amount will be locked:
       * Lend order: `lockAmt := lendAmt + lendAmt * feeRate * daysFromMatchedTime / 365`
       * Borrow order: `lockAmt := collateralAmt`
       * Limit order in the Secondary Markets:
          * Buy: `lockAmt := 365 * MQ * BQ / (daysFromExpiredTime * MQ + (365 - daysFromExpiredTime * BQ))`
          * Sell: `lockAmt := MQ`
    * Upon submitting these request, it will be taken as a partial order first.
    * Legitimacy:
       * Check if the account has sufficient balance to lock the amount of tokens
       * Check expiration
       * Check if the epoch equals the epoch of the specified nullifier tree
       * Check nullifier collision
       * Check if the expected nullifier slot has the default value
       * Check if `currentTime - matchedTime < 86400`
    * Correctness:
       * Check locked amount
       * Check if the digest is being placed into the nullifier leaf correctly
       * Check if the order is being placed into the order leaf correctly
2. Market orders in the Secondary Markets
    * Legitimacy:
       * Check expiration
    * Correctness: none.
    * This request is regarded as the `Start Request` for the following requests, as is explained below.

### Match

Depending on the nature of the order, different verifications steps are carried out:

- Non-market orders (lend orders, borrow orders, limit orders) are inserted into the Order Tree, and the Start Request, Interact Request and End Request get verified in sequence.
- Market orders do not have a Start Request, as orders are not inserted into the Order Tree, and only the Interact Request and End Request get verified in sequence.

These steps are further covered below:

 * Start Request: only applicable to non-market orders.
    * Legitimacy:
       * Check an order's request type
       * Check an order's expiration time
    * Correctness:
       * Default value in order leaf
 * Interact Request: this request match an order with the other orders in the channel. Once the match conditions are met, the matched order in the Order Tree, the associated sender's account, and the orders in the channel will be updated accordingly. Only other Interact Request and End Request can follow an Interact Request.
    * Legitimacy:
       * Check the request type of the specified order and the other orders in the channel.
       * Check if the order pair can be matched or not.
       * Check if `currentTime - matchedTime < 86400`.
       * Check if the fee needs to be deducted from target amount, and check if the account has a sufficient token balance.
       * Auction: (for lend orders)
          * Check if the interest rate is less than the matched interest rate.
          * Check if the interest rate is greater than or equal to the interest rate in the previous lend order.
    * Correctness:
       * Update the order leaf. If the order is completely filled, the locked funds for this order will be returned and the order leaf will be reset.
       * Update a sender's account accordingly.
       * For details, please refer to the mechanism documentation: 
          * [Auction Mechanism](https://docs.termstructure.com/protocol-spec./primary-markets/auction-mechanism)
          * [Orderbook Mechanism](https://docs.termstructure.com/protocol-spec./secondary-markets/order-book-mechanism)
 * End Request: When an order is sent to End Request, it will be returned to the Order Tree for potential matching with other orders in the next round. After the End Request is executed, the channel must be reset. However, this process does not apply to market orders, as partially-filled orders are not required to re-enter the Order Tree.
    * Legitimacy:
       * Check specified order leaf slot is reset to the initial value.
       * Check the request type of the order in the channel.
       * Check if `currentTime - matchedTime < 86400`.
       * If the fee needs to be deducted from target amount, check if the account has sufficient amount of tokens.
       * Auction: check if the matched interest rate is equal to the interest rate of the last lend order.
    * Correctness:
       * Update the order leaf. If the order is completely fulfilled, the locked fund for this order will be returned and the order leaf will be reset.
       * Update the sender's account accordingly.

### Cancel

Removes a specified order from the Order Tree and refund the locked amount to the account.

There are two types of cancel requests: admin cancel and user cancel.

Legitimacy:
 * If it is a user cancel, check if the sender of the cancel order is the sender of the request order.

Correctness:
 * If it is a user cancel, check if the txId (transaction ID) of the specified order is correct.
 * Initialize the order leaf and return the remaining locked amount of tokens to the sender of the order.

### IncreaseEpoch

Increases the smaller epoch value in the pair by 2, then resets the corresponding nullifier tree. For example, if the initial epoch is (1,2), the IncreaseEpoch operation adjusts it to (3,2), as 2 is added to the smaller value 1. 

Legitimacy: none.

Correctness:

 * Add 2 to the smaller epoch
 * Initialize the nullifier tree accordingly

### CreateTsbToken

Add a new tsbToken that records the maturity and the base token ID to the tsbToken tree.

Legitimacy: none.

Correctness:
 * Update the token leaf, associating the tsbTokenId with the data of baseTokenId and maturity.

### Redeem

Redeems the TSB tokens and get back the corresponding base tokens.

Legitimacy:
 * Check nonce
 * Check if an account has sufficient balance of TSB tokens
 * Check if `currentTime > maturityTime`

Correctness:
 * Check the TSB tokens to pay.
 * Check the base tokens to receive.

### WithdrawFee

Withdraw the fee with a specified token ID from the Fee Tree to the L1 admin account.

Legitimacy: none.

Correctness:
 * Reset the fee leaf.

### Evacuation

Once evacuation mode is activated, the State Root must be frozen. This allows multiple users to simultaneously rebuild the State Tree in order to withdraw their assets. If the State Root continues to update during the evacuation mode period, it could be inconvenient for users to withdraw assets.

We also only permit users to withdraw the total amount of `avl_amt` and `locked_amt` at once; partial withdrawals are not allowed. This simplifies the on-chain records, and the scenario of partial withdrawal during evacuation mode is not expected to occur.

Legitimacy: none.

Correctness:

 * For the total amount of `avl_amt + locked_amt` to be withdrawn, `avl_amt` could become negative. For instance, let's consider Alice's USDT L2 token leaf is set to: (avl_amt = 100, locked_amt = 50). After performing a USDT evacuation, the amounts would adjust to (avl_amt = -50, locked_amt = 50).

# Requests Handling and Verification

This section provides a detailed explanation of how the Backend processes the various types of requests, alongside a checklist of items that the circuit needs to verify.

Requests are divided into three main types:
 -  L1 requests
 -  L2 admin requests
 -  L2 user requests

If the Admin Ts Addr is not set to the initial value "0", the Admin signature must be included in the payload when sending the L1 and L2 admin requests for circuit verification.

After handling all the items described below, the Backend will pack all the requests it has **constructed** or **received**, along with their execution results, and _roll them up_ to the contract by generating a zk proof. The Circuit then verifies whether the contents of the package comply with our **FP format**.

### FP format
$$number_{FP} = mantissa * (10 ^ {exponent})$$
$$mantissa \in \mathbb{N}$$
$$exponent \in \mathbb{N}$$
$$(mantissa = 0) \rightarrow (exponent=0)$$

**FP constraints**
$$binaryLength(mantissa)\leq35$$
$$binaryLength(exponent)\leq5$$

The Backend will also generate a series of Merkle Proofs for the updated State Tree, which are then dispatched to the Circuit for validation. This process guarantees that the State Root is updated correctly.

## Register
|No.||Backend|detail|circuit verification|remarks|
|--|--|--|--|--|--|
|0.|**PREPROCESS**|Backend receives data emitted from the contract||N|When data is rolled up to the contract, the contract checks the consistency of the data|
|1.|**EFFECTS**|Backend constructs **L1 request: Register**|[Request Format](#requests)|Y|The circuit analyzes the request with its format|
|2.|**CHECK**|Backend checks that the TS Address is valid||N|Circuit verifies Ts Addr|
|3.|**CHECK**|Backend checks the default valud of the account leaf||Y||
|4.|**EFFECTS**|Backend updates the account leaf|Update account leaf: <br> a. Compute tsAddr with PubKey <br> b. Set nonce to 0 <br> c. Initialize the token tree|Y||

## Deposit
|No.||Backend|detail|circuit verification|remarks|
|--|--|--|--|--|--|
|0.|**PREPROCESS**|Backend receives data emitted from the contract||N|When data is rolled up to the contract, the contract checks the consistency of the data|
|1.|**EFFECTS**|Backend constructs **L1 request: Deposit**|[Request Format](#requests)|Y|The circuit analyzes the request with its format|
|2.|**EFFECTS**|Backend updates the token leaf|Increase available amount|Y||

## Force Withdraw
|No.||Backend|detail|circuit verification|remarks|
|--|--|--|--|--|--|
|0.|**PREPROCESS**|Backend receives data emitted from the contract||N|When data is rolled up to the contract, the contract checks the consistency of the data|
|1.|**EFFECTS**|Backend constructs **L1 request: ForceWithdraw**|[Request Format](#requests)|Y|The circuit analyzes the request with its format|
|2.|**EFFECTS**|Backend updates the token leaf|Decrease available amount|Y||

## Transfer
|No.||Backend|detail|circuit verification|remarks|
|--|--|--|--|--|--|
|0.|**PREPROCESS**|Backend receives a signed **L2 user request: Transfer** from a user|[Request Format](#requests)|Y|Signature is checked|
|1.|**CHECK**|Backend checks if the sender has enough balance||Y||
|2.|**CHECK**|Backend checks if the nonce is correct||Y||
|3.|**EFFECTS**|Backend updates sender's account leaf and token leaves|a. Increase nonce <br> b. Decrease available amount|Y||
|4.|**EFFECTS**|Backend updates receiver's token leaves|Increase available amount|Y||

## Withdraw
|No.||Backend|detail|circuit verification|remarks|
|--|--|--|--|--|--|
|0.|**PREPROCESS**|Backend receives a signed **L2 user request: Withdraw** from a user|[Request Format](#requests)|Y|Signature is checked|
|1.|**CHECK**|Backend checks if the sender has enough balance to withdraw||Y||
|2.|**CHECK**|Backend checks if the sender has enough balance to pay the fee||Y||
|3.|**CHECK**|Backend checks if the nonce is correct||Y||
|4.|**EFFECTS**|Backend updates sender's account leaf and token leaves|a. Increase nonce <br> b. Decrease available amount by withdrawal amount<br> c. Decrease available amount by fee amount|Y||

## Admin Cancel
|No.||Backend|detail|circuit verification|remarks|
|--|--|--|--|--|--|
|0.|**EFFECTS**|Backend deletes a specified order|Reset order leaf|Y||
|1.|**EFFECTS**|Backend constructs **L2 admin request: AdminCancel**|[Request Format](#requests)|Y|The circuit analyzes the request with its format|
|2.|**EFFECTS**|Backend updates the token leaf|Unlock: Deducts the locked amount; Increases available amount|Y||

## User Cancel
|No.||Backend|detail|circuit verification|remarks|
|--|--|--|--|--|--|
|0.|**PREPROCESS**|Backend receives a signed **L2 user request: UserCancel** from a user|[Request Format](#requests)|Y|Signature is checked|
|1.|**EFFECTS**|Search an order matching the order hash in the request||Y||
|2.|**CHECK**|Check if the sender ID in the order matches the sender ID in the request||Y||
|3.|**CHECK**|Backend checks if the sender has enough balance for the fee||Y||
|4.|**EFFECTS**|Backend deletes a specified order|Reset the order leaf|Y||
|5.|**EFFECTS**|Backend updates the token leaf|a. Unlock: Deducts the locked amount; Increases available amount <br> b. Decrease available amount for fee|Y||

## Admin Cancel Roll Borrow Order
|No.||Backend|detail|circuit verification|remarks|
|--|--|--|--|--|--|
|0.|**EFFECTS**|Backend deletes a specified order|Reset order leaf|Y||
|1.|**EFFECTS**|Backend constructs **L2 admin request: AdminCancel**|[Request Format](#requests)|Y|The circuit analyzes the request with its format|

## Force Cancel Roll Borrow Order
|No.||Backend|detail|circuit verification|remarks|
|--|--|--|--|--|--|
|0.|**EFFECTS**|Backend deletes a specified order|Reset order leaf|Y||
|1.|**EFFECTS**|Backend constructs **L2 admin request: AdminCancel**|[Request Format](#requests)|Y|The circuit analyzes the request with its format|

## User Cancel Roll Borrow Order
|No.||Backend|detail|circuit verification|remarks|
|--|--|--|--|--|--|
|0.|**PREPROCESS**|Backend receives a signed **L2 user request: UserCancel** from a user|[Request Format](#requests)|Y|Signature is checked|
|1.|**EFFECTS**|Search an order matching the order hash in the request||Y||
|2.|**CHECK**|Check if the sender ID in the order matches the sender ID in the request||Y||
|3.|**EFFECTS**|Backend deletes a specified order|Reset the order leaf|Y||

## Increase Epoch
|No.||Backend|detail|circuit verification|remarks|
|--|--|--|--|--|--|
|0.|**EFFECTS**|Backend constructs **L2 admin request: IncreaseEpoch**|[Request Format](#requests)|Y|The circuit analyzes the request with its format|
|1.|**EFFECTS**|Backend updates the Nullifier Tree|Initialize older Nullifier Tree, and adds 2 to its epoch|Y||

## Create TSB Token
|No.||Backend|detail|circuit verification|remarks|
|--|--|--|--|--|--|
|0.|**EFFECTS**|Backend constructs **L1 request: CreateTsbToken**|[Request Format](#requests)|Y|The circuit analyzes the request with its format|
|1.|**EFFECTS**|Backend checks if the TSB Token ID is correct|ID should be incremental by 1|N|Contract checks|
|2.|**EFFECTS**|Backend checks if maturity is within 80 * 365 days||Y||
|3.|**EFFECTS**|Backend updates TSB token leaf||Y||

## Redeem
|No.||Backend|detail|circuit verification|remarks|
|--|--|--|--|--|--|
|0.|**PREPROCESS**|Backend receives a signed **L2 user request: Redeem** from a user|[Request Format](#requests)|Y|Signature is checked|
|1.|**CHECK**|Backend checks if the sender has enough balance||Y||
|2.|**CHECK**|Backend checks if the nonce is correct||Y||
|3.|**EFFECTS**|Backend searches maturity time |Search from TSB token leaves|Y||
|4.|**CHECK**|Backend checks if the currentTime exceeds maturityTime||Y||
|5.|**EFFECTS**|Backend updates the sender's account leaf and token leaves|a. Increase nonce <br> b. Reduce TSB token's available amount <br> c. Increase base token's available amount|Y||

## Withdraw Fee
|No.| |Backend|Detail|Circuit Verification|Remarks|
|--|--|--|--|--|--|
|0.|**EFFECTS**|Backend constructs **L2 admin request: WithdrawFee**|[Request Format](#requests)|Y|The circuit analyzes the request with its format|
|1.|**EFFECTS**|Backend updates the fee leaf|Clears the specified deducted fee leaf|Y||

## Evacuation
|No.| |Backend|Detail|Circuit Verification|Remarks|
|--|--|--|--|--|--|
|0.|**PREPROCESS**|Backend receives data emitted from the contract||N|When data is rolled up to the contract, the contract checks the consistency of the data|
|1.|**EFFECTS**|Backend constructs **L1 requests: Evacuation**|[Request Format](#requests)|Y|The circuit analyzes the request with its format|
|2.|**EFFECTS**|Backend updates token leaf|User can evacuate their tokens with available amount plus locked amount. After evacuation, the available amount in the user account will be `-lockedAmt`|Y||

## Set Admin Ts Addr
|No.| |Backend|Detail|Circuit Verification|Remarks|
|--|--|--|--|--|--|
|0.|**EFFECTS**|Backend constructs **L2 admin request: SetAdminTsAddr**|[Request Format](#requests)|Y|The circuit analyzes the request with its format|
|1.|**EFFECTS**|Backend updates Admin TS Addr||Y||

## Auction
Acution has two stages: Order placing stage and matching stage.

### Order Placing Stage

There are two types of orders: Borrow Order and Lend Order

**Here is the execution process of the Borrow Order:**

|No.| |Backend|Detail|Circuit Verification|Remarks|
|--|--|--|--|--|--|
|0.|**PREPROCESS**|Backend receives a signed **L2 user request: AuctionBorrow** from a user|[Request Format](#requests)|Y|Check signature|
|1.|**CHECK**|Check if the market exists|Verify whether the corresponding TSB token has been created.|Y||
|2.|**CHECK**|Check if $borrowAmt$, $feeRate$, $collateralAmt$, $PIR$ can be converted to floating point numbers|[FP format](#fp-format)|Y||
|3.|**CHECK**|Check if duplicated orders exist|Nullifier check|Y||
|4.|**CHECK**|Check if the fee rate meets the system requirements||N|If not, the system ignores this order|
|5.|**CHECK**|Check if $t_e$ is legit|$ \lfloor \frac{t_e}{86400} \rfloor < \lfloor \frac{t_M}{86400} \rfloor - 1 $|Y||
|6.|**CHECK**|Check if the order is expired|$ t_o < t_e $|Y||
|7.|**CHECK**|Check the lower limit of interest rate|$ (interestRate \geq -100\%) \wedge (interestRate \geq \frac{-365}{d_{OTM} - 1}) $|Y||
|8.|**CHECK**|Check the upper limit of interest rate|1. Interest rate must be less than a certain value so that the borrower can pay the fee with the loan. <br> 2. PIR < 4000%|N|Check if the loan is enough to be lent in the matching stage|
|9.|**CHECK**|Check the health factor|$collateralAmt * collateralTokenPrice * rate >= debtAmt * borrowingTokenPrice$, where rate := 0.9 if stable; rate := 0.75 if unstable.|N|Check within the contract|
|10.|**CHECK**|Check if there is enough asset as collateral in the wallet|$collateralAmt \leq availableAmt$|Y||
|11.|**EFFECTS**|Backend updates the sender's token leaf|Lock: decrease available amount; increase locked amount|Y||
|12.|**EFFECTS**|Backend updates nullifier||Y||
|13.|**EFFECTS**|Backend adds this order to the order list||Y||

Locked Amount Formula:

$$lockedAmt = collateralAmt$$

**Here is the execution process of Lend Order:**

|No.| |Backend|Detail|Circuit Verification|Remarks|
|--|--|--|--|--|--|
|0.|**PREPROCESS**|Backend receives a signed **L2 user request: AuctionLend** from a user|[Request Format](#requests)|Y|Check signature|
|1.|**CHECK**|Check if the market exists|Verify whether the corresponding TSB token has been created.|Y||
|2.|**CHECK**|Check if $lendAmt$, $feeRate$, $defaultPIR$, $PIR$ can be converted to floating point numbers|[FP format](#fp-format)|Y||
|3.|**CHECK**|Check if duplicated orders exist|Nullifier check|Y||
|4.|**CHECK**|Check if the fee rate meets the system requirements||N|If not, the system ignores this order|
|5.|**CHECK**|Check if $t_e$ is legal|$ \lfloor \frac{t_e}{86400} \rfloor < \lfloor \frac{t_M}{86400} \rfloor - 1 $|Y||
|6.|**CHECK**|Check if the order is expired|$ t_o < t_e $|Y||
|7.|**CHECK**|Check the lower limit of interest rate|$ (interestRate \geq -100\%) \wedge (interestRate \geq \frac{-365}{d_{OTM} - 1}) $|Y||
|8.|**CHECK**|Check if there is enough asset in the wallet for lending|$lendAmt \leq availableAmt$|Y||
|9.|**EFFECTS**|Backend updates the sender's token leaf|Lock: decrease available amount; increase locked amount|Y||
|10.|**EFFECTS**|Backend updates nullifier||Y||
|11.|**EFFECTS**|Backend adds this order to the order list||Y||

Locked Amount Formula:

$$lockedFeeAmt := \lfloor \frac {lendAmt * defaultMatchedPIR * (d_OTM - 1) * feeRate}{365 * one * one} \rfloor$$
$$lockedAmt = lendAmt + lockedFeeAmt$$

**Here is the execution process of Roll Borrow Order:**

|No.| |Backend|Detail|Circuit Verification|Remarks|
|--|--|--|--|--|--|
|0.|**PREPROCESS**|Backend receives data emitted from the contract||N|When data is rolled up to the contract, the contract checks the consistency of the data|
|1.|**EFFECTS**|Backend constructs **L1 request: RollBorrowOrder**|[Request Format](#requests)|Y|The circuit analyzes the request with its format|
|2.|**EFFECTS**|Backend adds this order to the order list||Y||

### Matching Stage
|No.||Backend|Detail|Circuit Verification|Remarks|
|--|--|--|--|--|--|
|0.|**PREPROCESS**|List orders in a market|A TSB token with specific base token ID and maturity date represents a market|Y|Check if the orders are associated with the same market by examining TSB token ID|
|1.|**PREPROCESS**|Exclude the expired orders||Y|Circuit checks if an order is expired|
|2.|**PREPROCESS**|Prioritize the borrow/lend orders|For lend orders, the lower interest rate gets the higher priority. For borrow orders, the earlier timestamp gets the higher priority.|N||
|3.|**CHECK**|Check if the borrow order with the highest priority matches with the lend order or not. If not, exclude this borrow order and repeat step 2.|The matching conditions are provided below|Y||
|4.|**EFFECTS**|If a new borrow order is processed in a matching round, Backend constructs **L2 admin request: AuctionStart/RollOverStart**|[Request Format](#requests)|Y|The circuit analyzes the request with its format|
|5.|**EFFECTS**|Perform Interact operation on the specified borrow and lend orders|Interact rules are shown below|Y||
|6.|**EFFECTS**|Charge the fee from the lender||Y||
|7.|**EFFECTS**|Deduct the matched lending amount from the previously locked lending amount||Y||
|8.|**EFFECTS**|If the lend order is completed, return the remaining locked amount in the lend order||Y||
|9.|**EFFECTS**|Distribute TSB tokens to the lender||Y||
|10.|**EFFECTS**|Backend constructs **L2 admin request: AuctionMatch/RollOverMatch**|[Request Format](#requests)|Y|The circuit analyzes the request with its format|
|11.|**EFFECTS**|If the borrow order has no more matches in this round, check that matched borrowing amount > fee||Y||
|12.|**EFFECTS**|If the borrow order has no more matches in this round, distribute the matched loan to borrower||Y||
|13.|**EFFECTS**|If the borrow order has no more matches in this round, calculate the fee to charge the borrower||Y||
|14.|**EFFECTS**|If the borrow order has no more matches in this round, deduct the collateral amount in the matched orders from the total locked collateral amount. (For a Roll Borrow Order, deduction will only occur through contract)||Y||
|15.|**EFFECTS**|If the borrow order has no more matches in this round, the Backend constructs **L2 admin request: AuctionEnd/RollOverEnd**|[Request Format](#requests)|Y|The circuit analyzes the request with its format|
|16.|**EFFECTS**|If the borrow order is completed, return the remaining locked amount in the borrow order. (For a Roll Borrow Order, no assets are locked upon placement.)||Y||
|17.|**EFFECTS**|Repeat step 2., until all borrow orders and lend orders are processed||N||

**Matching Conditions**

1. Both orders come from the same market.
$$ t_{M, lendOrder} = t_{M, borrowOrder} $$
$$ lendingTokenID = borrowingTokenID $$

2. The interest rate of the lender's order is less than or equal to the interest rate of the borrower's order.
$$ borrowInterestRate \geq lendInterestRate $$

**Interact rules**:

$$matchedLendAmt := Min(lendAmt - oriCumLendAmt, borrowAmt - oriCumBorrowAmt)$$
$$matchedTsbTokenAmt := \lfloor \frac {matchedLendAmt * (PIR * days + one * (365 - days))}{(365 * one)} \rfloor$$

$$
\begin{cases} 
    newCumLendAmt & := oriCumLendAmt + matchedLendAmt \\
    newCumTsbTokenAmt & := oriCumTsbTokenAmt + matchedTsbTokenAmt \\
    newCumBorrowAmt & := oriCumBorrowAmt + matchedLendAmt \\
    newCumCollateralAmt 
& := \lceil \frac{signedCollateralAmt * newCumBorrowAmt}{signedBorrowAmt} \rceil
\equiv CollateralAmt - \lfloor \frac {signedCollateralAmt * (borrowAmt - newCumBorrowAmt)}{borrowAmt}  \rfloor \\
\end{cases}
$$

**Fee rules**

(Lend order)
$$LendFeeAmt := \lfloor \frac{matchedLendAmt * defaultMatchedInterestRate * feeRate * (days - 1)}{364 * one * one} \rfloor$$

(Borrow order)
$$BorrowFeeAmt := \lfloor \frac{matchedBorrowAmt * |matchedInterestRate| * feeRate * (days - 1)}{364 * one * one} \rfloor$$

## Secondary Markets

There are two types of orders: Limit Order and Market Order.

The derivation of the constraints formulated in circuit is illustrated in [Interaction Rules for Secondary Market in Circuit Derivation](#interaction-rules-for-secondary-market-in-circuit-derivation).

Below is the process of executing a Limit Order:

|No.||Backend|detail|circuit verification|remarks|
|--|--|--|--|--|--|
|0.|**PREPROCESS**|Backend receives a signed **L2 user request: SecondLimitOrder** from a user|[Request Format](#requests)|Y|Check signature|
|1.|**CHECK**|Check if the market exists|Verify if the corresponding TSB token has been created.|Y||
|2.|**CHECK**|Check if $MQ$, $BQ$, $takerFeeRate$, $makerFeeRate$ can be converted to floating point numbers|[FP format](#fp-format)|Y||
|3.|**CHECK**|Check if duplicated orders exist|Nullifier check|Y||
|4.|**CHECK**|Check if the fee rate meets the system requirements||N|If not, the system ignores this order|
|5.|**CHECK**|Check if $t_e$ is valid|$ \lfloor \frac{t_e}{86400} \rfloor < \lfloor \frac{t_M}{86400} \rfloor $|Y||
|6.|**CHECK**|Check if the order is expired|$ t_o < t_e $|Y||
|7.|**CHECK**|Check interest rate lower limit|$ (interestRate > -100\%) \wedge (interestRate \geq \frac{-365}{d_{OTM}}) $|Y||
|8.|**CHECK**|Check interest rate upper limit|1. Interest rate must be less than a certain value so that the borrower can pay the fee with the loan. <br> 2. PIR \leq 4000%|N|During the matching phase check if the user's account has sufficient tokens to pay the fee|
|9.|**CHECK**|If it is a buyer's order, check if there's enough BQ in the wallet||Y||
|10.|**CHECK**|If it is a seller's order, check if there's enough MQ in the wallet||Y||
|11.|**EFFECTS**|If it is a buyer, lock BQ||Y||
|12.|**EFFECTS**|If it is a seller, lock MQ||Y||
|13.|**EFFECTS**|Backend updates nullifier||Y||
|14.|**EFFECTS**|Backend adds this order to the list||Y||
|15.|**EFFECTS**|Backend constructs **L2 admin request: SecondLimitStart**|[Request Format](#requests)|Y|The circuit analyzes the request with its format|
|16.|**EFFECTS**|Include all orders in this market to process||Y|Check if both orders contain the same TSB token|
|17.|**EFFECTS**|Exclude the expired orders||Y|Circuit checks if an order is expired|
|18.|**EFFECTS**|Sort the orders' priority by interest rate||N||
|19.|**CHECK**|Check if a maker with the highest priority matches his/her orders or not|Additional matching condition are shown as below|Y||
|20.|**EFFECTS**|Perform Interaction with the matched buyer's orders and seller's orders|Interaction rules are shown as below|Y||
|21.|**CHECK**|If the maker is the seller, check if matchedBQ is greater than or equal to the maker's fee||Y||
|22.|**EFFECTS**|Execute the transaction result|Transfer the precise amount from the previously locked funds to the counterparty|Y||
|23.|**EFFECTS**|Charge the maker fee|If the order sender is a buyer, deduct the fee from the locked amount; if the order sender is a seller, deduct the fee from matchedBQ|Y||
|24.|**EFFECTS**|If a maker's order has been completed, return the remaining locked amount in the order||Y||
|25.|**EFFECTS**|Backend constructs **L2 admin request: SecondLimitExchange**|[Request Format](#requests)|Y|The circuit analyzes the request with its format|
|26.|**CHECK**|If there is no more maker to match with a taker and if the taker is a seller, check if matchedBQ is greater than or equal to the taker's fees|If not, this match will be rolled back|Y||
|27.|**EFFECTS**|If there is no more maker to match with a taker, charge fee from the taker||Y||
|28.|**EFFECTS**|If there is no more maker to match with a taker, and if the taker's order has been completed, return the remaining locked amount in the order||Y||
|29.|**EFFECTS**|If there is no more maker to match with a taker, the Backend constructs **L2 admin request: SecondLimitEnd**|[Request Format](#requests)|Y|The circuit analyzes the request with its format|
|30.|**EFFECTS**|If there is no more maker to match with a taker, add the taker to the maker list|Add this order into the Order Tree|Y||

**Matching Conditions**

1. Both orders come from the same market.
$$ tsbTokenId_{sellOrder} = tsbTokenId_{buyOrder} $$

2. The interest rate of the buyer's order is less than or equal to the interest rate of the seller's order.
$$ buyerMQ * sellerBQ \leq sellerMQ * buyerBQ $$

**Interest Rate Definition**:

$$interestRate := \frac{MQ}{BQ} - 100\%$$

**Locked Amount Formula**:

(buy side)
$$ days := 
\begin{cases}
    d_{ETM}&, interestRate < 0 \\
    d_{OTM}&, otherwise
\end{cases} $$

$$lockedAmt := \lfloor \frac{365 * MQ * BQ}{d_{ETM} * (MQ - BQ) + 365 * BQ} \rfloor + \lfloor \frac{MQ * Max(takerFeeRate, makerFeeRate) * days}{365 * one} \rfloor$$

(sell side)
$$lockedAmt := MQ$$

**Interact Rules**:

$$ matchedMQ := Min(remainingTakerMQ, remainingMakerMQ)$$
$$ matchedBQ := \lfloor \frac{matchedMQ * makerSignedBQ * 365}{d_{OTM} * (makerSignedMQ - makerSignedBQ) + 365 * makerSignedBQ} \rfloor$$

**Fee Rules**

$$FeeAmt := \lfloor \frac{matchedMQ * feeRate * days}{365 * one} \rfloor$$

Below is the process of executing a Market Order:

|No.|Action|Backend|detail|circuit verification|remarks|
|--|--|--|--|--|--|
|0.|**PREPROCESS**|Backend receives a signed **L2 user request: SecondMarketOrder** from a user|[Request Format](#requests)|Y|Check signature|
|1.|**CHECK**|Check if the market exists|Verify if the corresponding TSB token has been created.|Y||
|2.|**CHECK**|Check if $MQ$, $BQ$, $makerFeeRate$, $takerFeeRate$ can be converted to floating point numbers|[FP format](#fp-format)|Y||
|3.|**CHECK**|Check if duplicated orders exist|nullifier check|Y||
|4.|**CHECK**|Check if the fee rate meets the system requirements||N|If not, the system ignores this order|
|5.|**CHECK**|Check if $t_e$ is legal|$ \lfloor \frac{t_e}{86400} \rfloor < \lfloor \frac{t_M}{86400} \rfloor $|Y||
|6.|**CHECK**|Check if the order is expired|$ t_o < t_e $|Y||
|7.|**CHECK**|If it's a buy order, check if there is enough BQ in the wallet|There is a field in the order that is the maximum BQ that can be spent|Y||
|8.|**EFFECTS**|Include all orders in this market to process||Y|Check that both orders contain the same TSB token|
|9.|**EFFECTS**|Exclude the expired orders||Y|Circuit checks expiration|
|10.|**EFFECTS**|Sort priority by interest rate||N||
|11.|**CHECK**|Check if the maker with the highest priority matches with this order or not|Additional matching Condition are shown as below|Y||
|12.|**EFFECTS**|Perform Interaction on the specified buy order and sell order|Interaction rules are shown below|Y||
|13.|**CHECK**|If the maker is the seller, check if matchedBQ is greater than or equal to the maker's fee||Y||
|14.|**EFFECTS**|Execute the trading result|Charge takers from their available amount and makers from their locked amount. Transfer the exact amount from one party to the counter party|Y||
|15.|**EFFECTS**|Charge the maker fee|If it is a buy order, deduct the fee from the locked amount; if it is a sell order, deduct the fee from the matchedBQ|Y||
|16.|**EFFECTS**|If the maker order is completed, return the remaining locked amount in the maker order||Y||
|17.|**EFFECTS**|Backend constructs **L2 admin request: SecondMarketExchange**|[Request Format](#requests)|Y|The circuit analyzes the request with its format|
|18.|**CHECK**|If there is no maker matched with the taker, and if the taker is a seller, check if matchedBQ is greater than or equal to the taker's fee|If not, this pairing will be rolled back|Y||
|19.|**EFFECTS**|If there is no maker matched with the taker, charge the taker fee||Y||
|20.|**EFFECTS**|If there is no maker matched with the taker, and if the taker order is completed, return the remaining locked amount in the taker order||Y||
|21.|**EFFECTS**|If there is no maker matched with the taker, the Backend constructs **L2 admin request: SecondMarketEnd**|[Request Format](#requests)|Y|The circuit analyzes the request with its format|
|22.|**EFFECTS**|Backend updates nullifier||Y||

**Matching Conditions**

1. Both orders come from the same market.
$$ tsbTokenId_{sellOrder} = tsbTokenId_{buyOrder} $$

**Interact Rules**:

(market sell order)
$$matchedMQ := Min(remainTakerMQ, remainMakerMQ)$$
$$matchedBQ := \lfloor \frac{matchedMQ * makerSignedBQ * 365}{d_{MTM} * (makerSignedMQ - makerSignedBQ) + 365 * makerSignedBQ} \rfloor$$

(market buy order)
$$expectedMatchedMQ := Min(remainTakerMQ, remainMakerMQ)$$
$$expectedMatchedBQ := \lfloor \frac{matchedMQ * makerSignedBQ * 365}{d_{MTM} * (makerSignedMQ - makerSignedBQ) + 365 * makerSignedBQ} \rfloor$$
$$supMQ := \frac{remainTakerAvlBQ * d_{MTM} * makerSignedMQ + (365 - d_{MTM}) * makerSignedBQ * remainTakerAvlBQ}{365 * makerSignedBQ}$$
$$matchedBQ := Min(expectedMatchedBQ, remainTakerAvlBQ)$$
$$matchedMQ := 
\begin{cases}
    expectedMatchedMQ &, matchedBQ = expectedMatchedBQ \\
    supMQ &, otherwise
\end{cases}
$$

**Fee Rules**

$$Fee := \lfloor \frac{matchedMQ * feeRate * days}{365 * one} \rfloor$$

# Interaction Rules for the Secondary Markets in Circuit Derivation

Five versions of equivalent interaction rules are shown below. The first version is the most intuitive, while the last version represents the actual checking method in the circuit.

## Interaction Rules - 1

**(taker is limit sell order)**
$$matchedMQ := Min(remainTakerMQ, remainMakerMQ)$$
$$matchedBQ := \lfloor \frac{matchedMQ * makerSignedBQ * 365}{d_{MTM} * (makerSignedMQ - makerSignedBQ) + 365 * makerSignedBQ} \rfloor$$

**(taker is limit buy order)**
$$matchedMQ := Min(remainTakerMQ, remainMakerMQ)$$
$$matchedBQ := \lfloor \frac{matchedMQ * makerSignedBQ * 365}{d_{MTM} * (makerSignedMQ - makerSignedBQ) + 365 * makerSignedBQ} \rfloor$$

**(taker is market sell order)**
$$matchedMQ := Min(remainTakerMQ, remainMakerMQ)$$
$$matchedBQ := \lfloor \frac{matchedMQ * makerSignedBQ * 365}{d_{MTM} * (makerSignedMQ - makerSignedBQ) + 365 * makerSignedBQ} \rfloor$$

**(taker is market buy order)**
$$expectedMatchedMQ := Min(remainTakerMQ, remainMakerMQ)$$
$$expectedMatchedBQ := \lfloor \frac{matchedMQ * makerSignedBQ * 365}{d_{MTM} * (makerSignedMQ - makerSignedBQ) + 365 * makerSignedBQ} \rfloor$$
$$supMQ := \frac{remainTakerAvlBQ * d_{MTM} * makerSignedMQ + (365 - d_{MTM}) * makerSignedBQ * remainTakerAvlBQ}{365 * makerSignedBQ}$$
$$matchedBQ := Min(expectedMatchedBQ, remainTakerAvlBQ)$$
$$matchedMQ := 
\begin{cases}
    expectedMatchedMQ &, matchedBQ = expectedMatchedBQ \\
    supMQ &, otherwise
\end{cases}
$$

## Interaction Rules - 2

Convert (MQ, BQ) to (sellAmt, buyAmt) and (buyAmt, sellAmt) according to the side of order.
$$(sellAmt, buyAmt) := 
\begin{cases}
    (BQ, MQ) &, side = 0 (buyer) \\
    (MQ, BQ) &, otherwise
\end{cases}
$$

**(taker is limit sell order)**
$$matchedMakerBuyAmt := Min(remainTakerSellAmt, remainMakerBuyAmt)$$
$$matchedMakerSellAmt := \lfloor \frac{matchedMakerBuyAmt * makerSignedSellAmt * 365}{d_{MTM} * (makerSignedBuyAmt - makerSignedSellAmt) + 365 * makerSignedSellAmt} \rfloor$$

**(taker is limit buy order)**
$$matchedMakerSellAmt := Min(remainTakerBuyAmt, remainMakerSellAmt)$$
$$matchedMakerBuyAmt := \lfloor \frac{matchedMakerSellAmt * makerSignedBuyAmt * 365}{d_{MTM} * (makerSignedSellAmt - makerSignedBuyAmt) + 365 * makerSignedBuyAmt} \rfloor$$

**(taker is market sell order)**
$$matchedMakerBuyAmt := Min(remainTakerSellAmt, remainMakerBuyAmt)$$
$$matchedMakerSellAmt := \lfloor \frac{matchedMakerBuyAmt * makerSignedSellAmt * 365}{d_{MTM} * (makerSignedBuyAmt - makerSignedSellAmt) + 365 * makerSignedSellAmt} \rfloor$$

**(taker is market buy order)**
$$expectedMatchedMakerSellAmt := Min(remainTakerBuyAmt, remainMakerSellAmt)$$
$$expectedMatchedMakerBuyAmt := \lfloor \frac{matchedMakerSellAmt * makerSignedBuyAmt * 365}{d_{MTM} * (makerSignedSellAmt - makerSignedBuyAmt) + 365 * makerSignedBuyAmt} \rfloor$$
$$supMQ := \frac{remainTakerAvlBQ * d_{MTM} * makerSignedSellAmt + (365 - d_{MTM}) * makerSignedBuyAmt * remainTakerAvlBQ}{365 * makerSignedBuyAmt}$$
$$matchedMakerBuyAmt := Min(expectedMatchedMakerBuyAmt, remainTakerAvlBQ)$$
$$matchedMakerSellAmt := 
\begin{cases}
    expectedMatchedMakerSellAmt &, matchedMakerBuyAmt = expectedMatchedMakerBuyAmt \\
    supMQ &, otherwise
\end{cases}
$$

## Interaction Rules - 3

Combine the identical parts across different cases in interaction rules - 2.

**(taker is limit sell order / taker is market sell order)**
$$matchedMakerBuyAmtExpected := Min(remainTakerSellAmt, remainMakerBuyAmt)$$
$$matchedMakerSellAmtExpected := \lfloor \frac{matchedMakerBuyAmtExpected * makerSignedSellAmt * 365}{d_{MTM} * (makerSignedBuyAmt - makerSignedSellAmt) + 365 * makerSignedSellAmt} \rfloor$$
$$(matchedMakerBuyAmt, matchedMakerSellAmt) := (matchedMakerBuyAmtExpected, matchedMakerSellAmtExpected)$$

**(taker is limit buy order / taker is market buy order)**
$$matchedMakerSellAmtExpected := Min(remainTakerBuyAmt, remainMakerSellAmt)$$
$$matchedMakerBuyAmtExpected := \lfloor \frac{matchedMakerSellAmt * makerSignedBuyAmt * 365}{d_{MTM} * (makerSignedSellAmt - makerSignedBuyAmt) + 365 * makerSignedBuyAmt} \rfloor$$
$$supMQ := \frac{remainTakerAvlBQ * d_{MTM} * makerSignedSellAmt + (365 - d_{MTM}) * makerSignedBuyAmt * remainTakerAvlBQ}{365 * makerSignedBuyAmt}$$
$$(matchedMakerSellAmt, matchedMakerBuyAmt) := 
\begin{cases}
    (supMQ, remainTakerAvlBQ) &, (takerIsMarketBuyOrder) \wedge (remainTakerAvlBQ < matchedMakerSellAmtExpected) \\
    (matchedMakerSellAmtExpected, matchedMakerBuyAmtExpected) &, otherwise
\end{cases}
$$

## Interaction Rules - 4

Combine all the cases together.

$$matchedMakerSellAmtIfMQ := Min(remainTakerBuyAmt, remainMakerSellAmt)$$
$$matchedMakerBuyAmtIfMQ := Min(remainTakerSellAmt, remainMakerBuyAmt)$$
$$matchedMakerSellAmtExpected :=
\begin{cases}
    \lfloor \frac{matchedMakerBuyAmtIfMQ * makerSignedSellAmt * 365}{d_{MTM} * (makerSignedBuyAmt - makerSignedSellAmt) + 365 * makerSignedSellAmt} \rfloor &, (isTakerSellOrder) \\
    matchedMakerSellAmtIfMQ &, otherwise
\end{cases}
$$
$$matchedMakerBuyAmtExpected :=
\begin{cases}
    \lfloor \frac{matchedMakerSellAmt * makerSignedBuyAmt * 365}{d_{MTM} * (makerSignedSellAmt - makerSignedBuyAmt) + 365 * makerSignedBuyAmt} \rfloor &, (isTakerBuyOrder) \\
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

## Interaction Rules - 5

To be consistent with the circuit, matchedMakerSellAmtIfBQ and matchedMakerBuyAmtIfBQ are separated.

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
