#!/bin/bash

source $(dirname "$0")/startup.sh

CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH \
$CARDANO_BINARIES_DIR/cardano-cli query protocol-parameters "${MAGIC[@]}" --out-file $CARDANO_CONFIG_DIR/protocol.json
