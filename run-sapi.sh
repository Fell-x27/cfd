#!/bin/bash

source $(dirname "$0")/startup.sh

SAPI_PORT=$(from_config ".networks.${NETWORK_NAME}.\"cardano-node\".\"submit-api-port\"")

$CARDANO_BINARIES_DIR/cardano-submit-api \
--config $CARDANO_CONFIG_DIR/submit-api-config.json \
--socket-path $CARDANO_SOCKET_PATH \
--port $SAPI_PORT \
"${MAGIC[@]}"

