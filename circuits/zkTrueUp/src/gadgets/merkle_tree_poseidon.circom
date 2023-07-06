pragma circom 2.0.0;

include "../../../../node_modules/circomlib/circuits/poseidon.circom";
include "../../../../node_modules/circomlib/circuits/bitify.circom";

template VerifyExists(proof_length){
    signal input idx;
    signal input leaf_node;
    signal input merkle_proof[proof_length];
    signal input merkle_root;

    component n2B = Num2Bits(proof_length);
    n2B.in <== idx;

    component hash[proof_length];
    for(var i=0; i<proof_length; i++)
        hash[i] = Poseidon(2);

    hash[0].inputs[0] <== Mux(2)([leaf_node, merkle_proof[0]], n2B.out[0]);
    hash[0].inputs[1] <== Mux(2)([merkle_proof[0], leaf_node], n2B.out[0]);

    for(var i=1; i<proof_length; i++){
        hash[i].inputs[0] <== Mux(2)([hash[i - 1].out, merkle_proof[i]], n2B.out[i]);
        hash[i].inputs[1] <== Mux(2)([merkle_proof[i], hash[i - 1].out], n2B.out[i]);
    }

    merkle_root === hash[proof_length - 1].out;
}