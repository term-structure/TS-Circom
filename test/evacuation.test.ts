import { TsRollupConfigType } from '../lib/ts-rollup/ts-rollup';
import path from 'path';
import { before } from 'mocha';
import { CIRCUIT_NAME, isTestCircuitRun, testArgs } from './helper/test-config';
import fs, { writeFileSync } from 'fs';
import { expect } from 'chai';
// eslint-disable-next-line @typescript-eslint/no-var-requires
const info = require('./testdata/info.json');
const circom_tester = require('circom_tester');
const wasm_tester = circom_tester.wasm;
const config: TsRollupConfigType = info.config;
const mainSuffix = `${config.order_tree_height}-${config.account_tree_height}-${config.token_tree_height}-${config.nullifier_tree_height}-${config.fee_tree_height}-${config.numOfReqs}-${config.numOfChunks}`;
const mainCircuitName = `${CIRCUIT_NAME}-evacuation-${mainSuffix}`;

const outputPath = path.resolve(__dirname, `../build/${mainCircuitName}`).replace(/\\/g, '/');
const circuitMainPath = path.resolve(outputPath, `./${mainCircuitName}.circom`).replace(/\\/g, '/');

describe(`${mainCircuitName} test`, function () {
  this.timeout(1000 * 1000);
  let mainCircuit: any;
  const metadata: any = {};
  before(async function () {
    const mainPath = createMainCircuit(circuitMainPath, config, CIRCUIT_NAME, metadata);
    if (isTestCircuitRun) {
      mainCircuit = await wasm_tester(mainPath, {
        recompile: testArgs.circuitRecompile,
        output: path.resolve(__dirname, `../build/${mainCircuitName}`)
      });
    } else {
      console.warn('Skip circuit test');
    }
  });
  for (var i = 0; i < 4; i++) {
    const idx = i;
    it(`test evacuation ${i}`, async function () {
      const inputs = JSON.parse(fs.readFileSync(path.resolve(__dirname, `./testdata/evacuate/input-${idx}.json`)).toString());
      const witness = await mainCircuit.calculateWitness(inputs);
      expect(witness[0]).to.equal(1n);
    });
  }
});
function createMainCircuit(circuitMainPath: string, config: TsRollupConfigType, name: string, metadata: any) {
  console.log('createMainCircuit', circuitMainPath);

  const pathArr = circuitMainPath.split('/');
  pathArr.pop();
  if (!fs.existsSync(circuitMainPath)) {
    console.log({
      circuitMainPath,
      pathArr
    });
    fs.mkdirSync(pathArr.join('/'), { recursive: true });
  }

  createSpecCircuit(`${pathArr.join('/')}/spec.circom`, config, metadata);
  writeFileSync(circuitMainPath,
    `pragma circom 2.1.2;
  include "spec.circom";
  include "../../circuits/${name}/evacuation.circom";
  
  component main = Evacuation();
  `);
  return circuitMainPath;
}
function createSpecCircuit(specPath: string, config: TsRollupConfigType, metadata: any) {
  writeFileSync(specPath,
    `pragma circom 2.1.2;
  function OrderTreeHeight(){
    return ${config.order_tree_height};
  }
  function AccTreeHeight(){
    return ${config.account_tree_height};
  }
  function TokenTreeHeight(){
    return ${config.token_tree_height};
  }
  function NullifierTreeHeight(){
    return ${config.nullifier_tree_height};
  }
  function FeeTreeHeight(){
    return ${config.fee_tree_height};
  }
  function NumOfReqs(){
    return ${config.numOfReqs};
  }
  function NumOfChunks(){
    return ${config.numOfChunks};
  }
  
  function DefaultNullifierRoot(){
    return 0;
  }
  
  function TSBTokenTreeHeight(){
    return ${config.bond_tree_height};
  }
  
  function MinChunksPerReq(){
    return 5;
  }
  function MaxOrderUnitsPerReq(){
    return 1;
  }
  function MaxAccUnitsPerReq(){
    return 2;
  }
  function MaxTokenUnitsPerReq(){
    return 2;
  }
  function MaxNullifierUnitsPerReq(){
    return 1;
  }
  function MaxFeeUnitsPerReq(){
    return 1;
  }
  function MaxTSBTokenUnitsPerReq(){
    return 1;
  }
  function MaxChunksPerReq(){
    return 9;
  }
  
  function NumOfOrderUnits(){
    return NumOfReqs() * MaxOrderUnitsPerReq();
  }
  function NumOfAccUnits(){
    return NumOfReqs() * MaxAccUnitsPerReq();
  }
  function NumOfTokenUnits(){
    return NumOfReqs() * MaxTokenUnitsPerReq();
  }
  function NumOfFeeUnits(){
    return NumOfReqs() * MaxFeeUnitsPerReq();
  }
  function NumOfBondUnits(){
    return NumOfReqs() * MaxTSBTokenUnitsPerReq();
  }
  function NumOfOuts(){
    return (NumOfChunks() + 5) \\ 6;
  }
    `);
}