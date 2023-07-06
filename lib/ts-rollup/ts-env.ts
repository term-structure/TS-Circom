import * as dotenv from 'dotenv';
dotenv.config({ path: '.env.local' });
dotenv.config();

export const RESERVED_ACCOUNTS = BigInt(String(process.env.RESERVED_ACCOUNTS));
export const NULLIFIER_MAX_LENGTH = Number(String(process.env.NULLIFIER_MAX_LENGTH));
