import { BuildMetadataType, TsRollupConfigType } from './helper/test-type';
import path from 'path';
import { before } from 'mocha';

import { CIRCUIT_NAME, isTestCircuitRun, testArgs } from '../test/helper/test-config';
import fs from 'fs';
import { expect } from 'chai';
import { createMainCircuitNormal } from '../test/helper/test-helper';
// eslint-disable-next-line @typescript-eslint/no-var-requires
const info = require('./testdata/info.json');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const circom_tester = require('circom_tester');
const wasm_tester = circom_tester.wasm;
const config: TsRollupConfigType = info.config;
const mainSuffix = `${config.order_tree_height}-${config.account_tree_height}-${config.token_tree_height}-${config.nullifier_tree_height}-${config.fee_tree_height}-${config.numOfReqs}-${config.numOfChunks}`;
const mainCircuitName = `${CIRCUIT_NAME}-normal-${mainSuffix}`;

const outputPath = path.resolve(__dirname, `../build/${mainCircuitName}`).replace(/\\/g, '/');
const circuitMainPath = path.resolve(outputPath, `./${mainCircuitName}.circom`).replace(/\\/g, '/');

describe(`${mainCircuitName} test`, function () {
  this.timeout(1000 * 1000);

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  let mainCircuit: any;

  const metadata: BuildMetadataType = { defaultNulliferRoot: '18012398889380698404717924600148162801214704165566367634751429990523171457715' };
  before(async function () {
    const mainPath = createMainCircuitNormal(circuitMainPath, config, CIRCUIT_NAME, metadata);
    if (isTestCircuitRun) {
      mainCircuit = await wasm_tester(mainPath, {
        recompile: testArgs.circuitRecompile,
        output: path.resolve(__dirname, `../build/${mainCircuitName}`)
      });
    } else {
      console.warn('Skip circuit test');
    }
  });

  const first = 0;
  const last = 23;
  for (let batch_id = first; batch_id <= last; batch_id++) {
    const batch_id_ = batch_id;
    it(`test batch ${batch_id_}`, async function () {
      const inputs = JSON.parse(fs.readFileSync(path.resolve(__dirname, `./testdata/inputs/${batch_id_.toString().padStart(3, '0')}.circuit_input.json`), 'utf8'));
      const witness = await mainCircuit.calculateWitness(inputs);
      expect(witness[0]).to.equal(1n);
      // todo: check commitment
    });
  }
});