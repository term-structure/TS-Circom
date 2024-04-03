const fs = require('fs');
const buildBn128 = require("ffjavascript").buildBn128;

function convertBigIntsToStrings(obj) {
    if (typeof obj === 'bigint')
        return obj.toString();

    if (Array.isArray(obj))
        return obj.map(item => convertBigIntsToStrings(item));

    let newObj = {};
    for (let key in obj)
        if (obj.hasOwnProperty(key))
            newObj[key] = convertBigIntsToStrings(obj[key]);
    return newObj;
}
function convertStringsToBigInt(obj) {
    if (typeof obj === 'string')
        return BigInt(obj);

    if (Array.isArray(obj))
        return obj.map(item => convertStringsToBigInt(item));

    let newObj = {};
    for (let key in obj)
        if (obj.hasOwnProperty(key))
            newObj[key] = convertStringsToBigInt(obj[key]);
    return newObj;
}
function bigint_to_array(n, k, x) {
    let mod = 1n;
    for (var idx = 0; idx < n; idx++) {
        mod = mod * 2n;
    }

    let ret = [];
    var x_temp = x;
    for (var idx = 0; idx < k; idx++) {
        ret.push(x_temp % mod);
        x_temp = x_temp / mod;
    }
    return ret;
}
function convertBigIntsToBigIntArray(n, k, obj) {
    if (typeof obj === 'bigint')
        return bigint_to_array(n, k, obj);

    if (Array.isArray(obj))
        return obj.map(item => convertBigIntsToBigIntArray(n, k, item));

    let newObj = {};
    for (let key in obj)
        if (obj.hasOwnProperty(key))
            newObj[key] = convertBigIntsToBigIntArray(n, k, obj[key]);
    return newObj;
}
function encodePoint(curve, point) {
    return [
        convertBigIntsToStrings(convertBigIntsToBigIntArray(43, 6, curve.toObject(point)[0])),
        convertBigIntsToStrings(convertBigIntsToBigIntArray(43, 6, curve.toObject(point)[1]))
    ];
}
function encodeVk(vkey, prifix = "") {
    const vk_gamma_2 = curve.G2.fromObject(convertStringsToBigInt(vkey.vk_gamma_2));
    const vk_delta_2 = curve.G2.fromObject(convertStringsToBigInt(vkey.vk_delta_2));
    const vk_IC = [curve.G1.fromObject(convertStringsToBigInt(vkey.IC[0])), curve.G1.fromObject(convertStringsToBigInt(vkey.IC[1]))];

    var newObj = {};
    newObj[prifix + "gamma2"] = encodePoint(curve.G2, vk_gamma_2);
    newObj[prifix + "delta2"] = encodePoint(curve.G2, vk_delta_2);
    newObj[prifix + "vk_IC"] = [encodePoint(curve.G1, vk_IC[0]), encodePoint(curve.G1, vk_IC[1])];
    return newObj;
}
function encodePrf(raw_calldata, prifix = "") {
    const negA = curve.G1.fromObject(convertStringsToBigInt(raw_calldata[0].concat("0x01")));
    const B = curve.G2.fromObject(convertStringsToBigInt(raw_calldata[1].map(e => e.reverse()).concat(["0x01", "0x00"])));
    const C = curve.G1.fromObject(convertStringsToBigInt(raw_calldata[2].concat("0x01")));
    const commitment = convertStringsToBigInt(raw_calldata[3]);
    var newObj = {};
    newObj[prifix + "A"] = encodePoint(curve.G1, curve.G1.neg(negA));
    newObj[prifix + "B"] = encodePoint(curve.G2, B);
    newObj[prifix + "C"] = encodePoint(curve.G1, C);
    newObj[prifix + "commitment"] = convertBigIntsToStrings(commitment);
    return newObj;
}
let curve;
const main = async () => {
    curve = await buildBn128();
    try {
        const vk = encodeVk(JSON.parse(fs.readFileSync(process.argv[2])), "l_");
        const prf = encodePrf(JSON.parse(fs.readFileSync(process.argv[3])), "l_");
        fs.writeFileSync(process.argv[6], JSON.stringify(Object.assign(
            encodeVk(JSON.parse(fs.readFileSync(process.argv[2])), "l_"),
            encodePrf(JSON.parse(fs.readFileSync(process.argv[3])), "l_"),
            encodeVk(JSON.parse(fs.readFileSync(process.argv[4])), "r_"),
            encodePrf(JSON.parse(fs.readFileSync(process.argv[5])), "r_"),
        )));
    }
    catch (e) {
        console.log("sample: node scripts/gen-recursion-inputs.js <vk_l.json> <prf_l.json> <vk_r.json> <prf_r.json> <output.json>");
    }
    curve.terminate();
};

main();
