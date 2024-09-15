#!/bin/bash

source "$(dirname "$0")/scripts/software-tools.sh"

function cli {
    wrap-cli-command unwrapped-cli "$@"
}

function unwrapped-cli {
    if prepare_software "cardano-node" "silent"; then
        local command_output
        command_output=$(CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH \
                         $CARDANO_BINARIES_DIR/cardano-cli "$@" 2>&1)
       
        if echo "$command_output" | grep -q "(--mainnet | --testnet-magic NATURAL)"; then
            CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH \
            $CARDANO_BINARIES_DIR/cardano-cli "$@" "${MAGIC[@]}"
        else
            echo -e "$command_output"
        fi
    fi
}

