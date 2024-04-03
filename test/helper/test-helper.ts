import fs from 'fs';
import { BuildMetadataType, TsRollupConfigType } from './test-type';

export function createMainCircuitNormal(circuitMainPath: string, config: TsRollupConfigType, name: string, metadata: BuildMetadataType) {
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
    `pragma circom 2.1.5;
include "spec.circom";
include "../../circuits/${name}/normal.circom";

component main = Normal();
`);
  return circuitMainPath;
}
export 
function createMainCircuitEvacu(circuitMainPath: string, config: TsRollupConfigType, name: string, metadata: BuildMetadataType) {
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

function createSpecCircuit(specPath: string, config: TsRollupConfigType, metadata: BuildMetadataType) {
  writeFileSync(specPath,
    `pragma circom 2.1.5;
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
  return ${metadata.defaultNulliferRoot};
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

export function writeFileSync(path: string, data: string) {
  if (!fs.existsSync(path)) {
    const pathArr = path.split('/');
    pathArr.pop();
    fs.mkdirSync(pathArr.join('/'), { recursive: true });
  }
  fs.writeFileSync(path, data);
}