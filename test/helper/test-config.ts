import * as dotenv from 'dotenv';
import { parse } from 'ts-command-line-args';

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
dotenv.config({ path: '.env.local' });
dotenv.config();

export const CIRCUIT_NAME = process.env.CIRCUIT_NAME as string;
export const isTestCircuitRun = Boolean(parseInt(process.env.TEST_IS_CIRCUIT_RUN || '0'));