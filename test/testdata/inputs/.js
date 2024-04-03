const fs = require('fs');

// data sample = {"lastExecutedBlock":{"blockNumber":21,"l1RequestNum":0,"pendingRollupTxHash":"0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470","commitment":"0xdd53431a25191dad9a70ede2a5ca458a354e40e921bdac9b7177ec644085b0ce","stateRoot":"0x23d7641c559b1f96558e6c9fcea8a17394fdf9a1cde5e13dccd672b5c8262452","timestamp":"1691561500"},"newBlock":{"blockNumber":22,"newStateRoot":"16211512757870220812689437710394756866735773393198656077024313210815952331858","newTsRoot":"9310443526250427932862148965221774551981042154871688117866873453121842542859","timestamp":"1692944099","chunkIdDeltas":[0],"publicData":"0x180000000100010000000000000000000000174876e80000"},"proof":{"a":["0x130b45e4cccc2e5e0e092a29f6b4eaec9196a906d9ce0ce0acf763137006cbc0","0x2b1509489315af5b056b892e678ddfe60a5a5df82c81c814122a3ad712670ee1"],"b":[["0x28adbe85813da279d4504fb15a55d2140872e0dc603e4a36fb2fe37b7ac7377c","0x09f7b448a858e925e7e2de2dece03d111fc858973aed5ed7faeadabdbefee5af"],["0x0ff986fc866715cfa04528350aca10ff0d329be279e4feff86f97d22e8e208c1","0x1b46750a089aaeb35bf0beb7583eadfde05567239e53eaf3d805ce42389d8e79"]],"c":["0x2e2867ebf026b75de637bd7db26980c865d492aeaa1e05533632dec774f1280b","0x18e47df9f72b0fdfb2b57476f8f7292dbdb5aaeb5eed8c5c419d924f10138650"],"commitment":["0x10ca7fff83c8a5854d26f06a25ac78bc09164348ff735ebe857a95de61900891"]}}
// convert to hex for new root

for (var i = 0; i < 5; i++) {
    const data = JSON.parse(fs.readFileSync(`00${i}.evacu_calldata.json`, 'utf8'));
    data.newBlock.newStateRoot = '0x' + BigInt(data.newBlock.newStateRoot).toString(16).padStart(64, '0');
    console.log(data.newBlock.newStateRoot);
    data.newBlock.newTsRoot = '0x' + BigInt(data.newBlock.newTsRoot).toString(16).padStart(64, '0');
    console.log(data.newBlock.newTsRoot);
    fs.writeFileSync(`00${i}.evacu_calldata.json`, JSON.stringify(data));
}