import { TsRollupConfigType } from '../lib/ts-rollup/ts-rollup';
import path from 'path';
import { after, before } from 'mocha';

import { CIRCUIT_NAME, isTestCircuitRun, testArgs } from './helper/test-config';
import fs, { writeFileSync } from 'fs';
import { expect } from 'chai';
import { CircuitInputsExporter, StateType } from './helper/test-helper';
import { stateToCommitment } from './helper/commitment.helper';
// eslint-disable-next-line @typescript-eslint/no-var-requires
const circom_tester = require('circom_tester');
const wasm_tester = circom_tester.wasm;
const config: TsRollupConfigType = {
  order_tree_height: 8,
  account_tree_height: 10,
  token_tree_height: 8,
  nullifier_tree_height: 6,
  fee_tree_height: 3,
  bond_tree_height: 8,
  numOfReqs: 3,
  numOfChunks: 31,
};
const mainSuffix = `${config.order_tree_height}-${config.account_tree_height}-${config.token_tree_height}-${config.nullifier_tree_height}-${config.fee_tree_height}-${config.numOfReqs}-${config.numOfChunks}`;
const mainCircuitName = `${CIRCUIT_NAME}-evacuation-${mainSuffix}`;

const outputPath = path.resolve(__dirname, `../build/${mainCircuitName}`).replace(/\\/g, '/');
const circuitsSrcPath = path.resolve(__dirname, '../testdata', mainCircuitName).replace(/\\/g, '/');
const circuitMainPath = path.resolve(outputPath, `./${mainCircuitName}.circom`).replace(/\\/g, '/');
if (!fs.existsSync(circuitsSrcPath)) {
  fs.mkdirSync(circuitsSrcPath);
}

describe.skip(`${mainCircuitName} test, waiting for backend testing`, function () {
  this.timeout(1000 * 1000);
  let mainCircuit: any;
  const metadata: any = {};
  const exporter = new CircuitInputsExporter(
    mainCircuitName,
    config, mainSuffix, circuitsSrcPath, circuitMainPath
  );
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

  it('test evacuation', async function () {
    const inputs = {
      stateRoot: '14573921404931235927542089570903662094261824002392021320441560125117255185327',
      tsRoot: '11361214865536279141587699204621774598445294930750258204980779645594848879224',
      accRoot: '5115630466616808616829882227156116301907672587160571359009681823502306471734',
      accId: 1,
      nonce: '6',
      tsAddr: '993897585093631141645065567988378268956570510229',
      tokenRoot: '3930954191114726730368280803960332558468090274905745100111721393827443700096',
      tokenId: 3,
      avlAmt: '399699999313',
      lockedAmt: '0',
      accMkPrf: [
        '3584191393189863604461539395236108500631327252395928118527951520743968860062',
        '9579550963742995413691126915847977424434267303615892715517058442630231621418',
        '15917211436574108972183061960147999946861076911081234949868679263773382513663',
        '18724611985044876234544486048157852730743105679520780147695467090502316495360',
        '21789201403568908218655282546157646678919734927413441147004044281815300925014',
        '10367346053857556976133910291833588143775121241344360514732376069318518764665',
        '16650408070729038345587941823378370973940983752101296481275512079017207846122',
        '7560602014127157644730305462935094829156774684838037250646245627436788579663',
        '19692293070719703768830990038161741938232733577761336066757969277836239911031',
        '12417551859798582779249876201830590622188550612064986569316322856128565846353'
      ],
      tokenMkPrf: [
        '14744269619966411208579211824598458697587494354926760081771325075741142829156',
        '7423237065226347324353380772367382631490014989348495481811164164159255474657',
        '11286972368698509976183087595462810875513684078608517520839298933882497716792',
        '2704439908452755671146992592373747128408378893952151312000277957093914620988',
        '19712377064642672829441595136074946683621277828620209496774504837737984048981',
        '20775607673010627194014556968476266066927294572720319469184847051418138353016',
        '3396914609616007258851405644437304192397291162432396347162513310381425243293',
        '21551820661461729022865262380882070649935529853313286572328683688269863701601'
      ],
      currentTime: 1713071017,
    };
    const state = {
      oriStateRoot: '0x20388c1525e7439645b53c5a7db96a681669ec10082b9f58f442e0bb2c08f3af',
      newStateRoot: '0x20388c1525e7439645b53c5a7db96a681669ec10082b9f58f442e0bb2c08f3af',
      oriTsRoot: '0x191e384095d5422fa027893223858f0e0136768d0e0c389011d1d7284ffa6278',
      newTsRoot: '0x191e384095d5422fa027893223858f0e0136768d0e0c389011d1d7284ffa6278',
      pubdata: '0x01001800000001000300000000000000000000005d0ff9fa5100',
      newBlockTimestamp: 1713071017,
      newAccountRoot: '0x0b4f581fea086020c8ebe40732aaffde397609944153e13e4e8a4050d6616f36',
      isCriticalChunk: '0x0100',
      o_chunk: '0x1800000001000300000000000000000000005d0ff9fa5100'
    };
    await exporter.exportOthers('inputs', inputs);
    await exporter.exportOthers('commitment', state);
    await expectCircuitPass(inputs, state);
  });
  async function expectCircuitPass(newInputs: any, state: StateType, force = false) {
    if (isTestCircuitRun || force) {
      const witness = await mainCircuit.calculateWitness(newInputs);
      expect(witness[0]).to.equal(1n);
      const { commitment } = stateToCommitment(state);
      expect(BigInt(commitment)).to.equal(witness[1]);
    }
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
  
  function BondTreeHeight(){
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
  function MaxBondUnitsPerReq(){
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
    return NumOfReqs() * MaxBondUnitsPerReq();
  }
  function NumOfOuts(){
    return (NumOfChunks() + 5) \\ 6;
  }
    `);
}