pragma circom 2.1.5;

template Arr_Zero(n){
    signal output out[n];
    for(var i = 0; i < n; i++)
        out[i] <== 0;
}
template Arr_Reverse(n){
    signal input in[n];
    signal output out[n];
    for(var i = 0; i < n; i++)
        out[i] <== in[n - 1 - i];
}
template Arr_CopyRange(target_len, start, source_len){
    signal input target_in[target_len], source[source_len];
    signal output target_out[target_len];
    assert(start + source_len <= target_len);
    for(var i = 0; i < target_len; i++){
        if(i < start || i >= start + source_len)
            target_out[i] <== target_in[i];
        else
            target_out[i] <== source[i - start];
    }
}