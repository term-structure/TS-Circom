/* eslint-disable @typescript-eslint/no-var-requires */
import fs from 'fs';
import * as dotenv from 'dotenv';
import path from 'path';
const { spawn: _spawn } = require('child_process');
const cmdLogs: string[] = [];
import util from 'util';
const _exec = util.promisify(require('child_process').exec);
dotenv.config({ path: '.env.local' });
dotenv.config();
const RAPIDSNARK_PATH = process.env.RAPIDSNARK_PATH ? path.resolve(__dirname, process.env.RAPIDSNARK_PATH) : '';
const FORCE_BUILD = !!(process.env.FORCE_BUILD);
const DEBUG = process.env.NODE_ENV !== 'production';
const PTAU_PATH = process.env.PTAU_PATH || '';
const CIRCUIT_BASE = process.env.CIRCUIT_BASE || '';
const WASM = process.env.WASM || false;
const CONCURRENT_PROVE_THREAD = parseInt(process.env.CONCURRENT_PROVE_THREAD || '1') || 1;
console.log({PTAU_PATH, CIRCUIT_BASE});

const snarkjs = require('snarkjs');
const groth16 = snarkjs.groth16;
const BasePath = path.resolve(__dirname, '../');
const PhasePath = path.resolve(__dirname, '../', PTAU_PATH);
const SrcInfo = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../', `${CIRCUIT_BASE}/info.json`), 'utf8'));
const CircomBuildBaseDir = path.resolve(__dirname, '../', CIRCUIT_BASE);
const BatchesDir = path.resolve(__dirname, '../', CIRCUIT_BASE);
const MainCircuitName = SrcInfo.mainCircuitName;

type FileLog = {
  circuitName: string,
  name: string,
  path: string,
}

async function main() {
  console.log({
    RAPIDSNARK_PATH,
    FORCE_BUILD,
    DEBUG,
    PTAU_PATH,
    CIRCUIT_BASE,
    WASM,
    CONCURRENT_PROVE_THREAD,
  });
  recursiveRelativePathToAbsolutePath(SrcInfo);
  console.log({SrcInfo});
  const {
    zkeyPath: zKeyPath,
    vkeyPath: vKeyPath,
  } = await build(MainCircuitName, SrcInfo.circuitMainPath);
  // await genSolidityVerifier(zKeyPath, MainCircuitName);
  
  let pending: Array<Promise<void>> = [];
  for (let index = 0; index < SrcInfo.fileLogs.length; index++) {
    const item = SrcInfo.fileLogs[index] as FileLog;

    const task = doAll(item, vKeyPath);
    pending.push(task);
    if(pending.length === CONCURRENT_PROVE_THREAD) {
      await task;
      pending = [];
    }
  }
  await Promise.all(pending);
  console.log('done');
}

main()
  .then(() => process.exit(0))
  .catch(e => { console.error(e); process.exit(1); });

async function doAll(item: FileLog, vKeyPath: string) {
  console.log(`doAll ${item.name}`);
  try {
    const calldataRawPath = path.resolve(item.path, '..', `${item.name}.calldata-raw.json`);
    if(!FORCE_BUILD && fs.existsSync(calldataRawPath)) {
      console.log(`FORCE_BUILD=${FORCE_BUILD} skip ${item.name}`);
      return;
    }

    const { publicPath, proofPath } = await prove(item.name, item.path, item.circuitName);
    await verify(publicPath, proofPath, vKeyPath, item.circuitName);
    await genSolidityCalldata(item, proofPath, publicPath);
    fs.unlinkSync(publicPath);
    fs.unlinkSync(proofPath);
  } catch (error) {
    const errorPath = path.resolve(item.path, '..', `${item.name}.error.json`);
    fs.writeFileSync(errorPath, JSON.stringify(error, null, 2));
    console.error(error);
    console.warn(`verify ${item.name} failed`);
  }
}

async function genSolidityVerifier(zkeyPath: string, circuitName: string) {
  console.time(`solidityverifier ${zkeyPath}`);
  const verifierPath = path.resolve(BatchesDir, `${circuitName}-verifier.sol`);
  const { stdout, } = await exec(`snarkjs zkey export solidityverifier ${zkeyPath} ${verifierPath}`);
  console.timeEnd(`solidityverifier ${zkeyPath}`);
  return {
    stdout,
    verifierPath,
  };
}

async function verify(publicPath: string, proofPath:string, vkeyPath: string, circuitName: string) {
  console.time(`verify ${proofPath}`);
  const { stdout, } = await exec(`npx --max-old-space-size=1024000 snarkjs groth16 verify ${vkeyPath} ${publicPath} ${proofPath}`);
  console.timeEnd(`verify ${proofPath}`);
  return {
    stdout
  };
}

async function build(circuitName: string, circomSrcPath: string) {
  console.time(`build ${circomSrcPath}`);
  const buildDir = path.resolve(__dirname, `${CircomBuildBaseDir}/${circuitName}`);
  const r1csPath = `${buildDir}/${circuitName}.r1cs`;
  const zkey0Path = `${buildDir}/${circuitName}_0.zkey`;
  const zkey1Path = `${buildDir}/${circuitName}_1.zkey`;
  const zkeyPath = `${buildDir}/${circuitName}.zkey`;
  const vkeyPath = `${buildDir}/${circuitName}-vkey.json`;
  fs.mkdirSync(buildDir, { recursive: true });
  if(!fs.existsSync(r1csPath) || FORCE_BUILD) {
    await exec(`circom ${circomSrcPath} --r1cs ${WASM ? '--wasm' : ''} --c --output ${buildDir}`);
  }
  
  if(!fs.existsSync(zkeyPath) || FORCE_BUILD) {
    await exec(`npx --max-old-space-size=1024000 snarkjs groth16 setup ${r1csPath} ${PhasePath} ${zkey1Path}`);
    // await exec(`echo "test" | npx --max-old-space-size=1024000 snarkjs zkey contribute ${zkey0Path} ${zkey1Path} --name="1st Contributor Name"`);
    await exec(`npx --max-old-space-size=1024000 snarkjs zkey beacon ${zkey1Path} ${zkeyPath} 0102030405060708090a0b0c0d0e0f101112231415161718221a1b1c1d1e1f 10 -n="Final Beacon phase2"`);
    // fs.unlinkSync(zkey0Path);
    fs.unlinkSync(zkey1Path);
  }

  if(!fs.existsSync(vkeyPath) || FORCE_BUILD) {
    await exec(`npx --max-old-space-size=1024000 snarkjs zkey export verificationkey ${zkeyPath} ${vkeyPath}`);
  }
  console.timeEnd(`build ${circomSrcPath}`);
  
  return {
    r1csPath,
    zkeyPath,
    vkeyPath,
  };
}

async function prove(inputName: string, inputPath: string, circuitName: string) {
  console.time(`prove ${inputPath}`);
  const { witnessPath } = await generateWitness(inputName, inputPath, circuitName);
  const {
    proofPath,
    publicPath,
  } = await generateProof(inputName, witnessPath, circuitName);
  fs.unlinkSync(witnessPath);
  console.timeEnd(`prove ${inputPath}`);
  return {
    witnessPath,
    proofPath,
    publicPath,
  };
}

async function generateProof(inputName: string, witnessPath: string, circuitName: string) {
  const baseFolderPath = path.resolve(__dirname, `${CircomBuildBaseDir}/${circuitName}`);

  const proofPath = path.resolve(__dirname, `${BatchesDir}/${inputName}-proof.json`);
  const publicPath = path.resolve(__dirname, `${BatchesDir}/${inputName}-public.json`);
  const proveCmd = RAPIDSNARK_PATH ? `${RAPIDSNARK_PATH}` : 'npx --max-old-space-size=1024000 snarkjs groth16 prove';
  const { stdout, } = await exec(`${proveCmd} ${baseFolderPath}/${circuitName}.zkey ${witnessPath} ${proofPath} ${publicPath}`);

  return {
    stdout,
    proofPath,
    publicPath,
  };
}

async function generateWitness(inputName: string, inputPath: string, circuitName: string) {
  const buildDir = path.resolve(__dirname, `${CircomBuildBaseDir}/${circuitName}`);
  const witnessPath = path.resolve(__dirname, `${BatchesDir}/${inputName}-witness.wtns`);

  const jsGenWitnessPath = path.resolve(__dirname, `${buildDir}/${circuitName}_js/generate_witness.js`);
  const cppGenWitnessPath = path.resolve(__dirname, `${buildDir}/${circuitName}_cpp/${circuitName}`);

  if(!FORCE_BUILD && fs.existsSync(witnessPath)) {
    return {
      stdout: `FORCE_BUILD=${FORCE_BUILD} PASS generateWitness ${witnessPath}`,
      circuitName,
      witnessPath,
    };
  }

  if(fs.existsSync(cppGenWitnessPath)) {
    const { stdout, } = await exec(`${cppGenWitnessPath} ${inputPath} ${witnessPath}`);

    return {
      stdout,
      circuitName,
      witnessPath,
    };
  } else if(fs.existsSync(jsGenWitnessPath)) {
    const { stdout, } = await exec(`node ${jsGenWitnessPath} ${buildDir}/${circuitName}_js/${circuitName}.wasm ${inputPath} ${witnessPath}`);

    return {
      stdout,
      circuitName,
      witnessPath,
    };
  } else {
    throw new Error(`No witness generator found for ${circuitName}`);
  }
  
  
}

async function genSolidityCalldata({ name, circuitName, path: itemPath }: FileLog, proofPath: string, publicPath: string) {
  console.time(`soliditycalldata ${publicPath}`);
  const calldataRawPath = path.resolve(itemPath, '..', `${name}.calldata-raw.json`);
  
  if(!FORCE_BUILD && fs.existsSync(calldataRawPath)) {
    return {
      calldataRawPath,
    };
  }

  // const { stdout, } = await spawn(`snarkjs zkey export soliditycalldata ${publicPath} ${proofPath}`);
  const pub = JSON.parse(fs.readFileSync(publicPath, 'utf8'));
  const proof = JSON.parse(fs.readFileSync(proofPath, 'utf8'));
  const stdout = await groth16.exportSolidityCallData(proof, pub);
  fs.writeFileSync(calldataRawPath, `[${stdout}]`);
  console.timeEnd(`soliditycalldata ${publicPath}`);
  return {
    calldataPath: calldataRawPath
  };
}

function exec(cmd: string): Promise<{id: number, cmd: string, stdout: string}> {
  cmdLogs.push(cmd);
  const id = cmdLogs.length - 1;
  console.log(`exec command(${id}): ${cmd}`);
  return new Promise((resolve, reject) => {
    _exec(cmd).then(({stdout, stderr}: {stdout: string, stderr: string}) => {
      if(stderr) throw new Error(stderr);
      if(DEBUG) console.log(stdout);
      return resolve({id, cmd: cmdLogs[id], stdout});
    }).catch((stderr: any) => {
      if(DEBUG) console.error(stderr);
      return reject(stderr);
    });
  });
}

function spawn(cmd: string): Promise<{id: number, cmd: string, stdout: string}> {
  cmdLogs.push(cmd);
  const id = cmdLogs.length - 1;
  console.log(`exec command(${id}): ${cmd}`);
  const execCmds = cmd.split(' ');
  return new Promise((resolve, reject) => {
    const outBuffer: string[] = [];
    const errBuffer: string[] = [];
    let isError = false;
    const child = _spawn(execCmds[0], execCmds.slice(1));
    child.stdout.setEncoding('utf8');
    child.stderr.setEncoding('utf8');
    child.stdout.on('data', (data: any) => {
      outBuffer.push(data.toString());
    });
    child.stderr.on('data', (data: any) => {
      isError = true;
      errBuffer.push(data.toString());
    });
    child.on('close', (code: any) => {
      if(DEBUG) console.log({outBuffer, errBuffer, code});
      if(isError) {
        reject({errBuffer});
      }
      resolve({
        id,
        cmd: cmdLogs[id],
        stdout: outBuffer.join(''),
      });
    });
  });
}

function recursiveRelativePathToAbsolutePath(info: any) {
  for(const key in info) {
    if(typeof info[key] === 'string') {
      const str: string = info[key];
      if(str.startsWith('./')) {
        info[key] = info[key].replace('./', BasePath + '/');
      }
    } else if(typeof info[key] === 'object') {
      recursiveRelativePathToAbsolutePath(info[key]);
    }
  }
  
}