pragma circom 2.1.5;

include "./circom-pairing/bn254/subgroup_check.circom";
include "./circom-pairing/bn254/curve.circom";
include "./circom-pairing/bn254/pairing.circom";
include "./circom-pairing/bn254/bn254_func.circom";
include "./circomlib/poseidon.circom";
include "./circomlib/sha256/sha256.circom";
include "./circomlib/bitify.circom";

template PoseidonArbitraryLen(len){
    signal input inputs[len];
    signal output out;
    signal temp;
    var batch = 16;
    if(len < batch){
        out <== Poseidon(len)(inputs);
    }
    else{
        temp <== Poseidon(batch)([inputs[0], inputs[1], inputs[2], inputs[3], inputs[4], inputs[5], inputs[6], inputs[7], inputs[8], inputs[9], inputs[10], inputs[11], inputs[12], inputs[13], inputs[14], inputs[15]]);
        var t[len - batch + 1];
        t[0] = temp;
        for(var i = batch; i < len; i++) {
            t[i - batch + 1] = inputs[i];
        }
        out <== PoseidonArbitraryLen(len - batch + 1)(t);
    }
}
template PoseidonSpecificLen(len){
    signal input inputs[len];
    signal output out;
    var new_len = len + 1;
    var new_inputs[new_len];
    new_inputs[0] = len;
    for(var i = 1; i < new_len; i++)
        new_inputs[i] = inputs[i - 1];
    out <== PoseidonArbitraryLen(new_len)(new_inputs);
}
function ConstN(){
    return 43;
}
function ConstK(){
    return 6;
}
function ConstB(){
    return 3;
}
template G1_ScalarMul(){
    signal input point[2][ConstK()], scalar;
    signal isInfinity;
    signal output out[2][ConstK()];
    (out, isInfinity) <== EllipticCurveScalarMultiplySignalX(ConstN(), ConstK(), ConstB(), get_bn254_prime(ConstN(), ConstK()))(point, 0, scalar);
    isInfinity === 0;
}
template G1_Add(){
    signal input l[2][ConstK()], r[2][ConstK()];
    signal isInfinity;
    signal output out[2][ConstK()];
    (out, isInfinity) <== EllipticCurveAdd(ConstN(), ConstK(), 0, ConstB(), get_bn254_prime(ConstN(), ConstK()))(l, 0, r, 0);
    isInfinity === 0;
}
template verifyProof() {
    // verification key
    signal input gamma2[2][2][ConstK()], delta2[2][2][ConstK()], IC[2][2][ConstK()];

    // proof
    signal input negA[2][ConstK()], B[2][2][ConstK()], C[2][ConstK()], commitment;

    // check proof consists of valid group elements
    SubgroupCheckG1(ConstN(), ConstK())(negA);
    SubgroupCheckG2(ConstN(), ConstK())(B);
    SubgroupCheckG1(ConstN(), ConstK())(C);

    // Compute s = commitment * IC[1] + IC[0]
    signal s[2][ConstK()] <== G1_Add()(G1_ScalarMul()(IC[1], commitment), IC[0]);

    // exponentiate to get e(-A, B)*e(VK, gamma2)*e(C, delta2)
    var b2[2][50] = get_bn254_b(ConstN(), ConstK());
    var loopBitLength = 65;
    var pseudoBinaryEncoding[loopBitLength] = get_bn254_pseudo_binary_encoding();
    signal negalfa1xbeta2[6][2][ConstK()] <== FinalExponentiate(ConstN(), ConstK(), get_bn254_prime(ConstN(), ConstK()))(
        OptimizedMillerLoopProductFp2(ConstN(), ConstK(), b2[0], b2[1], 3, pseudoBinaryEncoding, loopBitLength, get_bn254_prime(ConstN(), ConstK()))([B, gamma2, delta2], [negA, s, C])
    );

    var in[2 * 2 * ConstK() * 3 + 6 * 2 * ConstK()];
    for(var i = 0; i < 2; i++){
        for(var j = 0; j < 2; j++){
            for(var l = 0; l < ConstK(); l++){
                in[2 * 2 * ConstK() * 0 + i * 2 + j * ConstK() + l] = gamma2[i][j][l];
                in[2 * 2 * ConstK() * 1 + i * 2 + j * ConstK() + l] = delta2[i][j][l];
                in[2 * 2 * ConstK() * 2 + i * 2 + j * ConstK() + l] = IC[i][j][l];
            }
        }
    }
    for(var i = 0; i < 6; i++){
        for(var j = 0; j < 2; j++){
            for(var l = 0; l < ConstK(); l++){
                in[2 * 2 * ConstK() * 3 + i * 2 * ConstK() + j * ConstK() + l] = negalfa1xbeta2[i][j][l];
            }
        }
    }
    signal output vk_digest <== PoseidonSpecificLen(2 * 2 * ConstK() * 3 + 6 * 2 * ConstK())(in);
}

template zkTreeNode(){
    signal input l_gamma2[2][2][ConstK()], l_delta2[2][2][ConstK()], l_IC[2][2][ConstK()];
    signal input l_negA[2][ConstK()], l_B[2][2][ConstK()], l_C[2][ConstK()], l_commitment;
    signal input r_gamma2[2][2][ConstK()], r_delta2[2][2][ConstK()], r_IC[2][2][ConstK()];
    signal input r_negA[2][ConstK()], r_B[2][2][ConstK()], r_C[2][ConstK()], r_commitment;
    signal l_vk_digest <== verifyProof()(l_gamma2, l_delta2, l_IC, l_negA, l_B, l_C, l_commitment);
    signal r_vk_digest <== verifyProof()(r_gamma2, r_delta2, r_IC, r_negA, r_B, r_C, r_commitment);

    signal n2b_l_vk_digest[254]  <== Num2Bits_strict()(l_vk_digest);
    signal n2b_r_vk_digest[254]  <== Num2Bits_strict()(r_vk_digest);
    signal n2b_l_commitment[254] <== Num2Bits_strict()(l_commitment);
    signal n2b_r_commitment[254] <== Num2Bits_strict()(r_commitment);

    log("l_vk_digest", l_vk_digest);
    log("r_vk_digest", r_vk_digest);

    component sha256 = Sha256(256 * 4);
    for(var i = 0; i < 256; i++){
        sha256.in[256 * 0 + (256 - 1 - i)] <== i < 254 ? n2b_l_vk_digest[i]  : 0;
        sha256.in[256 * 1 + (256 - 1 - i)] <== i < 254 ? n2b_r_vk_digest[i]  : 0;
        sha256.in[256 * 2 + (256 - 1 - i)] <== i < 254 ? n2b_l_commitment[i] : 0;
        sha256.in[256 * 3 + (256 - 1 - i)] <== i < 254 ? n2b_r_commitment[i] : 0;
    }

    signal commitment <== Bits2Num(256)(sha256.out);
}