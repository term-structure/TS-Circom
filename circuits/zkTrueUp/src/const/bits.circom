pragma circom 2.1.5;

function BitsOpType()     { return 8; }
function BitsTokenId()     { return 16; }
function BitsAccId()       { return 32; }
function BitsNonce()       { return 64; }
function BitsAmount()      { return 115; }
function BitsUnsignedAmt() { return BitsAmount() - 1; }
function BitsTime()        { return 32; }
function BitsRatio()       { return 32; }
function BitsChunk()       { return 8 * 12; }
function BitsTsAddr()      { return 8 * 20; }
function BitsEpoch()       { return 128; }
function BitsSide()        { return 1; }