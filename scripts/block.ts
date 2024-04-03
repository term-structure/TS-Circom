
import Papa from 'papaparse';
import { resolve } from 'path';
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'fs';
import { CIRCUIT_NAME } from '../test/helper/test-config';

const infoPath = resolve(__dirname, `../testdata/${CIRCUIT_NAME}/info.json`);
const blockCsvPath = resolve(__dirname, '../', process.env.REAL_BLOCK_CSV_PATH as string);
const outputPath = resolve(__dirname, '../', process.env.REAL_BLOCK_OUTPUT_PATH as string);
async function main() {
  rmSync(outputPath, { recursive: true, force: true });
  mkdirSync(outputPath);
  
  const infoRaw = readFileSync(infoPath, 'utf8');
  const info = JSON.parse(infoRaw);
  console.log({
    info
  });
  info.outputPath = outputPath;


  const csvString = readFileSync(blockCsvPath,'utf8');
  const {data, errors} = Papa.parse(csvString, {
    header: true,
    delimiter: '\t',
    quoteChar: '\'',
    escapeChar: '"'
  });
  
  const fileLogs: any[] = [];
  for (let index = 1; index <= data.length; index++) {
    const {
      circuitInputV1,
      blockNumber,
      circuitInputV2,
      circuitInputV2Raw,
      lastCommittedBlock,
      commitBlock,
      currentTime,
    } = data[index-1] as any;

    if(!circuitInputV2) {
      console.warn(`circuitInputV2 is empty at blockNumber ${blockNumber}`);
      continue;
    }
    const c = JSON.parse(commitBlock);
    c['timestamp'] = currentTime;
    writeFileSync(resolve(outputPath, `${blockNumber}.inputs.json`), circuitInputV2);
    writeFileSync(resolve(outputPath, `${blockNumber}.inputs-key.json`), JSON.stringify(JSON.parse(circuitInputV2Raw), null, 2));
    // writeFileSync(resolve(outputPath, `${blockNumber}.input-old.json`), circuitInputV1);
    writeFileSync(resolve(outputPath, `${blockNumber}.lastCommittedBlock.json`), JSON.stringify(JSON.parse(lastCommittedBlock), null, 2));
    writeFileSync(resolve(outputPath, `${blockNumber}.commitBlock.json`), JSON.stringify(c, null, 2));
    fileLogs.push({
      'circuitName': CIRCUIT_NAME,
      'name': `${blockNumber}`,
      'path': resolve(outputPath, `${blockNumber}.inputs.json`),
    });
  }
  info.fileLogs = fileLogs.sort((a, b) => Number(a.name) - Number(b.name));
  writeFileSync(infoPath, JSON.stringify(info, null, 2));

}

main()
  .then(() => {
    process.exit(0);
  })
  .catch(e => {
    console.error(e);
    process.exit(1);
  });