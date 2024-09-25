#!/bin/bash

source "$(dirname "$0")/scripts/software-tools.sh"

function cli {
    wrap-cli-command unwrapped-cli "$@"
    echo ""  1>&2
    echo -e "${GREEN}DONE!${NORMAL}" 1>&2
}

function unwrapped-cli {
    if prepare_software "cardano-node" "silent"; then
        local command_output
        command_output=$(CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH \
                         $CARDANO_BINARIES_DIR/cardano-cli "$@" 2>&1)
       
        if echo "$command_output" | grep -- "--testnet-magic" > /dev/null; then
            CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH \
            $CARDANO_BINARIES_DIR/cardano-cli "$@" "${MAGIC[@]}"
        else
            echo -e "$command_output"            
        fi
    fi
}

