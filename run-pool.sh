#!/bin/bash

source $(dirname "$0")/startup.sh

SERVER_IP=$(from_config ".global.ip")
NODE_PORT=$(from_config ".networks.\"${NETWORK_NAME}\".\"cardano-node\".\"node-port\"")

KES_KEYS=$CARDANO_KEYS_DIR/kes

$CARDANO_BINARIES_DIR/cardano-node run \
--config $CARDANO_CONFIG_DIR/config.json \
--database-path $CARDANO_STORAGE_DIR/blockchain/ \
--socket-path $CARDANO_SOCKET_PATH \
--topology $CARDANO_CONFIG_DIR/topology.json \
--shelley-kes-key $KES_KEYS/kes.skey \
--shelley-vrf-key $KES_KEYS/vrf.skey \
--shelley-operational-certificate $KES_KEYS/node.cert \
--host-addr $SERVER_IP \
--port $NODE_PORT

