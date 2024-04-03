#!/bin/bash

CURRENT_PATH="$(dirname $(readlink -f $0))"
PTAU_PATH="/home/abner_huang/zk-circom/ptau/final_28.ptau"

export NODE_OPTIONS="--max-old-space-size=2853189864"

ORDER_TREE_HEIGHT=24
ACC_TREE_HEIGHT=32
TOKEN_TREE_HEIGHT=16
NULLIFIER_TREE_HEIGHT=24
FEE_TREE_HEIGHT=16
NUM_OF_REQS=$1
if [ $((NUM_OF_REQS * 4 % 32)) -eq 0 ]; then
    NUM_OF_CHUNKS=$(( NUM_OF_REQS * 4 ))
else
    NUM_OF_CHUNKS=$(( (NUM_OF_REQS * 4 / 32 + 1) * 32 ))
fi
DEFAULT_NULLIFIER_ROOT=17442189262588877922573347453104862303711672093150317392397950911190231782258

CIRCUIT_NAME=zkTrueUp-${ORDER_TREE_HEIGHT}-${ACC_TREE_HEIGHT}-${TOKEN_TREE_HEIGHT}-${NULLIFIER_TREE_HEIGHT}-${FEE_TREE_HEIGHT}-${NUM_OF_REQS}-${NUM_OF_CHUNKS}

BUILD_DIR=${CURRENT_PATH}/../build/"$(date +'%Y%m%d_%H%M%S')"_${CIRCUIT_NAME}
LOG_FILE=${BUILD_DIR}/${CIRCUIT_NAME}_log.txt
TRANSCRIPT_FILE=${BUILD_DIR}/${CIRCUIT_NAME}_transcript

if [ ! -f /usr/bin/time ]; then
    echo "/usr/bin/time is not installed. Please install it before running this script."
    echo "You can try using the following command: sudo apt-get install time"
    exit 1
fi

if [ ! -f "$PTAU_PATH" ]; then
    echo "No Phase 1 ptau file found."
    exit 1
fi

mkdir -p "$BUILD_DIR"
touch "$LOG_FILE"
touch "$TRANSCRIPT_FILE"

# ================================

echo "\033[1;35m========================================\n****GENERATING SOURCE FILES****\n----------------------------------------\033[0m" 2>&1 | tee -a ${TRANSCRIPT_FILE}
echo "[INFO][$(date)] GENERATING SOURCE FILES - Start" >> $LOG_FILE

    awk -v oth="$ORDER_TREE_HEIGHT" \
        -v ath="$ACC_TREE_HEIGHT" \
        -v tth="$TOKEN_TREE_HEIGHT" \
        -v nth="$NULLIFIER_TREE_HEIGHT" \
        -v fth="$FEE_TREE_HEIGHT" \
        -v nor="$NUM_OF_REQS" \
        -v noc="$NUM_OF_CHUNKS" \
        -v default_nullifier_root="$DEFAULT_NULLIFIER_ROOT" \
        '
            /OrderTreeHeight/{print; getline; print "    return " oth ";"; next}
            /AccTreeHeight/{print; getline; print "    return " ath ";"; next}
            /TokenTreeHeight/{print; getline; print "    return " tth ";"; next}
            /NullifierTreeHeight/{print; getline; print "    return " nth ";"; next}
            /FeeTreeHeight/{print; getline; print "    return " fth ";"; next}
            /NumOfReqs/{print; getline; print "    return " nor ";"; next}
            /NumOfChunks/{print; getline; print "    return " noc ";"; next}
            /NumOfChunks/{print; getline; print "    return " noc ";"; next}
            /DefaultNullifierRoot/{print; getline; print; getline; print "    return " default_nullifier_root ";"; next}
            {print}
        ' \
        ${CURRENT_PATH}/../circuits/zkTrueUp/spec.circom > ${BUILD_DIR}/${CIRCUIT_NAME}_spec.circom

    # --evacu--
    # awk -v current_path="$CURRENT_PATH" \
    #     -v build_dir="$BUILD_DIR" \
    #     -v circuit_name="$CIRCUIT_NAME" \
    #     '
    #         /include "normal.circom"/{gsub("include \"normal.circom\"", "include \"" current_path "/../circuits/zkTrueUp/evacuation.circom\"")}
    #         /include "spec.circom"/{gsub("include \"spec.circom\"", "include \"" build_dir "/" circuit_name "_spec.circom\"")}
    #         /component main = Normal()/{gsub("Normal", "Evacuation")}
    #         {print}
    #     ' \
    #     ${CURRENT_PATH}/../circuits/zkTrueUp/circuit.circom.example > ${BUILD_DIR}/${CIRCUIT_NAME}.circom

    awk -v current_path="$CURRENT_PATH" \
        -v build_dir="$BUILD_DIR" \
        -v circuit_name="$CIRCUIT_NAME" \
        '
            /include "normal.circom"/{gsub("include \"normal.circom\"", "include \"" current_path "/../circuits/zkTrueUp/normal.circom\"")}
            /include "spec.circom"/{gsub("include \"spec.circom\"", "include \"" build_dir "/" circuit_name "_spec.circom\"")}
            {print}
        ' \
        ${CURRENT_PATH}/../circuits/zkTrueUp/circuit.circom.example > ${BUILD_DIR}/${CIRCUIT_NAME}.circom

echo "[INFO][$(date)] GENERATING SOURCE FILES - Start" >> $LOG_FILE

# ================================

echo "\033[1;35m========================================\n****COMPILING CIRCUIT****\n----------------------------------------\033[0m" 2>&1 | tee -a ${TRANSCRIPT_FILE}
echo "[INFO][$(date)] COMPILING CIRCUIT - Start" >> $LOG_FILE

    /usr/bin/time -v circom ${BUILD_DIR}/${CIRCUIT_NAME}.circom --r1cs --c --output ${BUILD_DIR} 2>&1 | tee -a ${TRANSCRIPT_FILE}

echo "[INFO][$(date)] COMPILING CIRCUIT - End" >> $LOG_FILE

echo "\033[1;35m========================================\n****GENERATING ZKEY****\n----------------------------------------\033[0m" 2>&1 | tee -a ${TRANSCRIPT_FILE}
echo "[INFO][$(date)] GENERATING ZKEY - Start" >> $LOG_FILE

    # NODE_OPTIONS="\
    #     --max-old-space-size=2355200 \
    #     --initial-old-space-size=2355200 \
    #     --no-global-gc-scheduling \
    #     --no-incremental-marking \
    #     --max-semi-space-size=1024 \
    #     --initial-heap-size=2355200"  \
    #     snarkjs groth16 setup ${BUILD_DIR}/${CIRCUIT_NAME}.r1cs ${PTAU_PATH} ${BUILD_DIR}/${CIRCUIT_NAME}.zkey
    /usr/bin/time -v npx snarkjs groth16 setup ${BUILD_DIR}/${CIRCUIT_NAME}.r1cs ${PTAU_PATH} ${BUILD_DIR}/${CIRCUIT_NAME}.zkey 2>&1 | tee -a ${TRANSCRIPT_FILE}

echo "[INFO][$(date)] GENERATING ZKEY - End" >> $LOG_FILE

# ================================

# echo "\033[1;35m========================================\n****VERIFYING ZKEY****\n----------------------------------------\033[0m" 2>&1 | tee -a ${TRANSCRIPT_FILE}
# echo "[INFO][$(date)] VERIFYING ZKEY - Start" >> $LOG_FILE

#     /usr/bin/time -v npx snarkjs zkey verify ${BUILD_DIR}/${CIRCUIT_NAME}.r1cs ${PTAU_PATH} ${BUILD_DIR}/${CIRCUIT_NAME}.zkey 2>&1 | tee -a ${TRANSCRIPT_FILE}

# echo "[INFO][$(date)] VERIFYING ZKEY - End" >> $LOG_FILE

# ================================

echo "\033[1;35m========================================\n****EXPORTING VKEY****\n----------------------------------------\033[0m" 2>&1 | tee -a ${TRANSCRIPT_FILE}
echo "[INFO][$(date)] EXPORTING VKEY - Start" >> $LOG_FILE

    /usr/bin/time -v npx snarkjs zkey export verificationkey ${BUILD_DIR}/${CIRCUIT_NAME}.zkey ${BUILD_DIR}/${CIRCUIT_NAME}_verification_key.json 2>&1 | tee -a ${TRANSCRIPT_FILE}

echo "[INFO][$(date)] EXPORTING VKEY - End" >> $LOG_FILE

# ================================

echo "\033[1;35m========================================\n****EXPORTING SOLIDITY VERIFIER****\n----------------------------------------\033[0m" 2>&1 | tee -a ${TRANSCRIPT_FILE}
echo "[INFO][$(date)] EXPORTING SOLIDITY VERIFIER - Start" >> $LOG_FILE

    /usr/bin/time -v npx snarkjs zkey export solidityverifier ${BUILD_DIR}/${CIRCUIT_NAME}.zkey ${BUILD_DIR}/${CIRCUIT_NAME}_verifier.sol 2>&1 | tee -a ${TRANSCRIPT_FILE}

echo "[INFO][$(date)] EXPORTING SOLIDITY VERIFIER - End" >> $LOG_FILE

# ================================

echo "\033[1;35m========================================\n****COMPILING WTNS CALCULATOR****\n----------------------------------------\033[0m" 2>&1 | tee -a ${TRANSCRIPT_FILE}
echo "[INFO][$(date)] COMPILING WTNS CALCULATOR - Start" >> $LOG_FILE

    /usr/bin/time -v make -C ${BUILD_DIR}/${CIRCUIT_NAME}_cpp 2>&1 | tee -a ${TRANSCRIPT_FILE}
    # mv ${BUILD_DIR}/${CIRCUIT_NAME}_cpp/${CIRCUIT_NAME}.dat ${BUILD_DIR}/${CIRCUIT_NAME}.dat
    # mv ${BUILD_DIR}/${CIRCUIT_NAME}_cpp/${CIRCUIT_NAME} ${BUILD_DIR}/${CIRCUIT_NAME}

echo "[INFO][$(date)] COMPILING WTNS CALCULATOR - End" >> $LOG_FILE