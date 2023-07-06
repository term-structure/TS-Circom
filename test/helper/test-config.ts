import fs from 'fs';
import * as dotenv from 'dotenv';
import { parse } from 'ts-command-line-args';
import { hexToUint8Array } from 'term-structure-sdk';
import { HDNode } from 'ethers/lib/utils';
import { Wallet } from 'ethers';

interface TestConfigType {
  circuitRecompile: boolean;
}
export const testArgs = parse<TestConfigType>({
  circuitRecompile: {
    type: Boolean, defaultValue: false, description: 'recompile circuit', alias: 'f',
  }
}, {
  partial: true
});
dotenv.config({path: '.env.local'});
dotenv.config();

export const CIRCUIT_NAME = process.env.CIRCUIT_NAME as string;
export const isTestCircuitRun = Boolean(parseInt(process.env.TEST_IS_CIRCUIT_RUN || '0'));
export const IS_EXPORT_CIRCUIT_INPUTS = Boolean(parseInt(process.env.TEST_IS_EXPORT_CIRCUIT_INPUTS || '0'));
export const acc1Priv = hexToBuffer('0x0cef2e17df41494b8d56b57d4b3908833560e584329c5a0f223ffb36cee07f38');
export const acc2Priv = hexToBuffer('0x057b409b15ef93aea2387c8bbb4ab500625743510e5aa16d9ad57f8258fb5613');
export const MNEMONIC = process.env.MNEMONIC || 'test test test test test test test test test test test junk';
export const CHAIN_ID = Number(process.env.CHAIN_ID || 1);
export const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS || '0x00000000000000000000000000000';

export function getTestAccounts(num: number) {
  const hdnode = HDNode.fromMnemonic(MNEMONIC);
  const accounts = [];
  for(let i = 0; i < num; i++) {
    const node = hdnode.derivePath(`m/44'/60'/0'/0/${i}`);
    accounts.push(new Wallet(node));
  }
  return accounts;
}

export function exportInputFile(circuitInputJsonPath: string, data: any, namespace = '') {
  const path = namespace ? circuitInputJsonPath.replace('.json', `_${namespace}.json`) : circuitInputJsonPath;
  fs.writeFileSync(path, JSON.stringify(data, null, 2));
  console.log(`output input file: ${path}`);
}
// console.log(JSON.stringify(new Array(250).fill(0).map((_,idx) => '0x'+uint8ArrayToHexString(ethers.utils.randomBytes(32)))));

function hexToBuffer(L2MintAccountPriv: string): Buffer {
  L2MintAccountPriv = L2MintAccountPriv.replace('0x', '');
  if (L2MintAccountPriv.length % 2) {
    L2MintAccountPriv = '0' + L2MintAccountPriv;
  }
  return Buffer.from(L2MintAccountPriv, 'hex');
}