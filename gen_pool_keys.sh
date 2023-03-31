#!/bin/bash

source $(dirname "$0")/startup.sh

COLD_KEYS=$CARDANO_KEYS_DIR/cold
KES_KEYS=$CARDANO_KEYS_DIR/kes

mkdir -p $COLD_KEYS
mkdir -p $KES_KEYS

$CARDANO_BINARIES_DIR/cardano-cli node key-gen \
--cold-verification-key-file $COLD_KEYS/cold.vkey \
--cold-signing-key-file $COLD_KEYS/cold.skey \
--operational-certificate-issue-counter-file $COLD_KEYS/cold.counter

$CARDANO_BINARIES_DIR/cardano-cli node key-gen-VRF \
--verification-key-file $KES_KEYS/vrf.vkey \
--signing-key-file $KES_KEYS/vrf.skey

source $(dirname "$0")/gen_kes.sh

for FILE in $(find $CARDANO_KEYS_DIR -type f); do   
    chmod 0600 $FILE  
done    
