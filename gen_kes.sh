#!/bin/bash

source $(dirname "$0")/startup.sh

COLD_KEYS=$CARDANO_KEYS_DIR/cold
KES_KEYS=$CARDANO_KEYS_DIR/kes

KES_DURATION=$(cat $CARDANO_CONFIG_DIR/shelley-genesis.json | jq .slotsPerKESPeriod)

CURRENT_SLOT=$(CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH $CARDANO_BINARIES_DIR/cardano-cli query tip "${MAGIC[@]}" | jq .slot)

CURRENT_KES_PERIOD=$(expr $CURRENT_SLOT / $KES_DURATION)

$CARDANO_BINARIES_DIR/cardano-cli node key-gen-KES \
--verification-key-file $KES_KEYS/kes.vkey \
--signing-key-file $KES_KEYS/kes.skey

$CARDANO_BINARIES_DIR/cardano-cli  node issue-op-cert \
--kes-verification-key-file $KES_KEYS/kes.vkey \
--cold-signing-key-file $COLD_KEYS/cold.skey \
--operational-certificate-issue-counter $COLD_KEYS/cold.counter \
--kes-period $CURRENT_KES_PERIOD \
--out-file $KES_KEYS/node.cert

for FILE in $(find $CARDANO_KEYS_DIR -type f); do   
    chmod 0600 $FILE  
done 
