#!/bin/bash

source $(dirname "$0")/startup.sh

SERVER_IP=$(from_config ".global.ip")
NODE_PORT=$(from_config ".networks.\"${NETWORK_NAME}\".\"cardano-node\".\"node-port\"")


$CARDANO_BINARIES_DIR/cardano-node run \
--config $CARDANO_CONFIG_DIR/config.json \
--database-path $CARDANO_STORAGE_DIR/blockchain/ \
--socket-path $CARDANO_SOCKET_PATH \
--topology $CARDANO_CONFIG_DIR/topology.json \
$([[ $# -gt 0 && "$2" == "--noip" || "$SERVER_IP" == "127.0.0.1" || "$SERVER_IP" == "localhost" ]] && echo "" || echo "--host-addr $SERVER_IP --port $NODE_PORT")




