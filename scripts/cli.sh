#!/bin/bash

source "$(dirname "$0")/scripts/software-tools.sh"

function cli {
    local output_buffer
    local error_buffer

    local tmp_error_file
    tmp_error_file=$(mktemp)

    {
        output_buffer=$(wrap-cli-command unwrapped-cli "$@" 2> "$tmp_error_file")
    }

    error_buffer=$(cat "$tmp_error_file")
    rm -f "$tmp_error_file"

    if [[ -n "$error_buffer" ]]; then
        echo "$error_buffer" 1>&2
        echo "" 1>&2
        echo -e "${RED}ERROR!${NORMAL}" 1>&2
    else
        echo "$output_buffer"
        echo "" 1>&2
        echo -e "${GREEN}DONE!${NORMAL}" 1>&2
    fi
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

