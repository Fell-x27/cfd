#!/bin/bash

function check-sync {
    wrap-cli-command run-check
}

function run-check {
    CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH $CARDANO_BINARIES_DIR/cardano-cli query tip ${MAGIC[@]}
}



