#!/bin/bash

source $(dirname "$0")/startup.sh

PGPASSFILE=$CARDANO_CONFIG_DIR/pgpass  \
$CARDANO_BINARIES_DIR/cardano-db-sync \
--config $CARDANO_CONFIG_DIR/db-sync-config.json \
--socket-path $CARDANO_SOCKET_PATH \
--state-dir $CARDANO_STORAGE_DIR/db_sync/ \
--schema-dir $CARDANO_CONFIG_DIR/schema/
