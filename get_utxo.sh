#!/bin/bash

source $(dirname "$0")/startup.sh

echo ""
cat $CARDANO_KEYS_DIR/payment/base.addr
echo ""
echo ""
CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH \
$CARDANO_BINARIES_DIR/cardano-cli query utxo \
--address $(cat $CARDANO_KEYS_DIR/payment/base.addr) \
"${MAGIC[@]}"

