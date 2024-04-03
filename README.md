# circom-zkTrueUp
This repository contains an implementation of a zk circuit using circom, designed specifically for zkTrueUp.

## Test
Copy `.env.example` to `.env`.
```
cp .env.example .env
```
Execute the following command at the top level to run tests. 
```
npx mocha -r ts-node/register test/*.test.ts -- -f=1
```
Alternatively, you can run tests using the following command:
```
npm run test
```

If you do not need to recompile the circuit, you can run the following command instead:
```
npx mocha -r ts-node/register test/*.test.ts
```