import { TsRollupConfigType } from '../lib/ts-rollup/ts-rollup';
import path from 'path';
import { before } from 'mocha';

import { CIRCUIT_NAME, isTestCircuitRun, testArgs } from '../test/helper/test-config';
import fs from 'fs';
import { expect } from 'chai';
import { createMainCircuit } from '../test/helper/test-helper';
// eslint-disable-next-line @typescript-eslint/no-var-requires
const info = require('./testdata/info.json');
const circom_tester = require('circom_tester');
const wasm_tester = circom_tester.wasm;
const config: TsRollupConfigType = info.config;
const mainSuffix = `${config.order_tree_height}-${config.account_tree_height}-${config.token_tree_height}-${config.nullifier_tree_height}-${config.fee_tree_height}-${config.numOfReqs}-${config.numOfChunks}`;
const mainCircuitName = `${CIRCUIT_NAME}-normal-${mainSuffix}`;

const outputPath = path.resolve(__dirname, `../build/${mainCircuitName}`).replace(/\\/g, '/');
const circuitMainPath = path.resolve(outputPath, `./${mainCircuitName}.circom`).replace(/\\/g, '/');

describe(`${mainCircuitName} test`, function () {
  this.timeout(1000 * 1000);
  let mainCircuit: any;
  let metadata: any = { defaultNulliferRoot: "18012398889380698404717924600148162801214704165566367634751429990523171457715" };

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

  const first = 1;
  const last = 24;
  for (var batch_id = first; batch_id <= last; batch_id++) {
    const batch_id_ = batch_id;
    it(`test batch ${batch_id_}, ${info.fileLogs[batch_id_ - 1].desc}`, async function () {
      const inputs = JSON.parse(fs.readFileSync(path.resolve(__dirname, `./testdata/local-block-230808/${batch_id_}.inputs.json`), 'utf8'));
      const witness = await mainCircuit.calculateWitness(inputs);
      expect(witness[0]).to.equal(1n);
      // todo: check commitment
    });
  }
});