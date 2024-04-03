#!/bin/bash

PHASE1=./ptau/final_28.ptau
BUILD_DIR=./build/recursion_groth16
SRC_DIR=./circuits/recursion_groth16
CIRCUIT_NAME=main
SNARKJS_PATH=./node_modules/snarkjs/build/cli.cjs
export NODE_OPTIONS="--max-old-space-size=2762144"

if [ -f "$PHASE1" ]; then
    echo "Found Phase 1 ptau file"
else
    echo "No Phase 1 ptau file found. Exiting..."
    exit 1
fi

if [ ! -d "$BUILD_DIR" ]; then
    echo "No build directory found. Creating build directory..."
    mkdir -p "$BUILD_DIR"
fi

# echo "****COMPILING CIRCUIT****"
# start=`date +%s`
# set -x
# circom "$SRC_DIR"/"$CIRCUIT_NAME".circom --r1cs --c --output "$BUILD_DIR"
# { set +x; } 2>/dev/null
# end=`date +%s`
# echo "DONE ($((end-start))s)"

echo "****GENERATING ZKEY 0****"
start=`date +%s`
node --max-old-space-size=2048000 --initial-old-space-size=2048000 --no-global-gc-scheduling --no-incremental-marking --max-semi-space-size=1024 --initial-heap-size=2048000 $SNARKJS_PATH zkey new "$BUILD_DIR"/"$CIRCUIT_NAME"_c.r1cs "$PHASE1" "$BUILD_DIR"/"$CIRCUIT_NAME"_1.zkey -v
end=`date +%s`
echo "DONE ($((end-start))s)"

# echo "****CONTRIBUTE TO THE PHASE 2 CEREMONY****"
# start=`date +%s`
# echo "test" | npx snarkjs zkey contribute "$BUILD_DIR"/"$CIRCUIT_NAME"_0.zkey "$BUILD_DIR"/"$CIRCUIT_NAME"_1.zkey --name="1st Contributor Name"
# end=`date +%s`
# echo "DONE ($((end-start))s)"

echo "****GENERATING FINAL ZKEY****"
start=`date +%s`
node --max-old-space-size=2048000 --initial-old-space-size=2048000 --no-global-gc-scheduling --no-incremental-marking --max-semi-space-size=1024 --initial-heap-size=2048000 $SNARKJS_PATH zkey beacon "$BUILD_DIR"/"$CIRCUIT_NAME"_1.zkey "$BUILD_DIR"/"$CIRCUIT_NAME".zkey 0102030405060708090a0b0c0d0e0f101112231415161718221a1b1c1d1e1f 10 -n="Final Beacon phase2"
end=`date +%s`
echo "DONE ($((end-start))s)"

echo "** Exporting vkey"
start=`date +%s`
npx snarkjs zkey export verificationkey "$BUILD_DIR"/"$CIRCUIT_NAME".zkey "$BUILD_DIR"/vkey.json
end=`date +%s`
echo "DONE ($((end-start))s)"

