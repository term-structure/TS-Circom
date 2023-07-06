pragma circom 2.1.5;

function FmtOpcode()       { return 1 * 8; }
function FmtAccId()        { return 4 * 8; }
function FmtTokenId()      { return 2 * 8; }
function FmtStateAmount()  { return 16 * 8; }
function FmtHashedPubKey() { return 20 * 8; }
function FmtPacked()       { return 5 * 8; }
function FmtTime()         { return 4 * 8; }
function FmtTxOffset()     { return 4 * 8; }
function FmtTxId()         { return 8 * 8; }