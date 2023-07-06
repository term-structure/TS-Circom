pragma circom 2.1.5;

template Sig_Verify(){
    signal input sig[LenOfSig()], enabled, digest;
    signal (tsPubKeyX, tsPubKeyY, RX, RY, S) <== Sig()(sig);
    EdDSAPoseidonVerifier()(enabled, tsPubKeyX, tsPubKeyY, S, RX, RY, digest);
    signal output tsAddr <== TsPubKey2TsAddr()([tsPubKeyX, tsPubKeyY]);
}