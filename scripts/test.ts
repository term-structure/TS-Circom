
import { asyncPoseidonHash, dpPoseidonHash } from 'term-structure-sdk';
async function main() {
  await asyncPoseidonHash;

  const hash = dpPoseidonHash([
    0n,
    0n,
    3779697971080206738458967431800197829432491601815117194175698812071344553405n,
  ]);

  console.log({
    hash: hash.toString(),
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });