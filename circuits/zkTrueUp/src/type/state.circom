pragma circom 2.1.5;

template State_GetDigest(){
    signal input state[LenOfState()];
    signal output stateRoot, tsRoot;
    component state_ = State();
    state_.arr <== state;
    signal nullifierRoot <== PoseidonSpecificLen(4)([state_.nullifierRoot[0], state_.epoch[0], state_.nullifierRoot[1], state_.epoch[1]]);
    tsRoot <== PoseidonSpecificLen(6)([state_.adminTsAddr, state_.tSBTokenRoot, state_.feeRoot, nullifierRoot, state_.orderRoot, state_.txCount]);
    stateRoot <== PoseidonSpecificLen(2)([tsRoot, state_.accRoot]);
}