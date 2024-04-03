#!/bin/bash

PHASE1=./ptau/final_28.ptau
BUILD_DIR=./testdata/zkTrueUp-24-32-16-24-16-128-512/zkTrueUp-24-32-16-24-16-128-512
SRC_DIR=./testdata/zkTrueUp-24-32-16-24-16-128-512
CIRCUIT_NAME=zkTrueUp-24-32-16-24-16-128-512
SNARKJS_PATH=./node_modules/snarkjs/build/cli.cjs
export NODE_OPTIONS="--max-old-space-size=2048000"

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

echo "****COMPILING CIRCUIT****"
start=`date +%s`
set -x
circom "$SRC_DIR"/"$CIRCUIT_NAME".circom --O1 --r1cs --c --output "$BUILD_DIR"
{ set +x; } 2>/dev/null
end=`date +%s`
echo "DONE ($((end-start))s)"

echo "****GENERATING ZKEY 0****"
start=`date +%s`
node --trace-gc --trace-gc-ignore-scavenger --max-old-space-size=2048000 --initial-old-space-size=2048000 --no-global-gc-scheduling --no-incremental-marking --max-semi-space-size=1024 --initial-heap-size=2048000 --expose-gc $SNARKJS_PATH zkey new "$BUILD_DIR"/"$CIRCUIT_NAME".r1cs "$PHASE1" "$BUILD_DIR"/"$CIRCUIT_NAME"_0.zkey -v
npx snarkjs groth16 setup "$BUILD_DIR"/"$CIRCUIT_NAME".r1cs "$PHASE1" "$BUILD_DIR"/"$CIRCUIT_NAME"_0.zkey
end=`date +%s`
echo "DONE ($((end-start))s)"

echo "****CONTRIBUTE TO THE PHASE 2 CEREMONY****"
start=`date +%s`
node $SNARKJS_PATH zkey contribute -verbose "$BUILD_DIR"/"$CIRCUIT_NAME"_0.zkey "$BUILD_DIR"/"$CIRCUIT_NAME".zkey -n="First phase2 contribution" -e="some random text for entropy"
end=`date +%s`
echo "DONE ($((end-start))s)"

echo "****VERIFYING FINAL ZKEY****"
start=`date +%s`
node --trace-gc --trace-gc-ignore-scavenger --max-old-space-size=2048000 --initial-old-space-size=2048000 --no-global-gc-scheduling --no-incremental-marking --max-semi-space-size=1024 --initial-heap-size=2048000 --expose-gc $SNARKJS_PATH zkey verify -verbose "$BUILD_DIR"/"$CIRCUIT_NAME".r1cs "$PHASE1" "$BUILD_DIR"/"$CIRCUIT_NAME".zkey
end=`date +%s`
echo "DONE ($((end-start))s)

echo "****EXPORTING VKEY****"
start=`date +%s`
node $SNARKJS_PATH zkey export verificationkey "$BUILD_DIR"/"$CIRCUIT_NAME".zkey "$BUILD_DIR"/"$CIRCUIT_NAME"-vkey.json -v
end=`date +%s`
echo "DONE ($((end-start))s)"

