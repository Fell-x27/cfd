
declare -A RUNNERS

RUNNERS["node-relay"]="run_cardano_node|cardano-node"
RUNNERS["node-relay-local"]="run_cardano_node --noip|cardano-node"
RUNNERS["node-block-producer"]="run_cardano_pool|cardano-node"
RUNNERS["db-sync"]="run_cardano_db_sync|cardano-db-sync"
RUNNERS["submit-api"]="run_cardano_sapi|cardano-node"
RUNNERS["wallet"]="run_cardano_wallet|cardano-wallet"

function run_cardano_node {
    if prepare_software "cardano-node"; then
        SERVER_IP=$(from-config ".global.ip")
        NODE_PORT=$(from-config ".networks.\"${NETWORK_NAME}\".software.\"cardano-node\".\"node-port\"")

        $CARDANO_BINARIES_DIR/cardano-node run \
            --config $CARDANO_CONFIG_DIR/config.json \
            --database-path $CARDANO_STORAGE_DIR/blockchain/ \
            --socket-path $CARDANO_SOCKET_PATH \
            --topology $CARDANO_CONFIG_DIR/topology.json \
            $([[ $# -gt 0 && "$1" == "--noip" || "$SERVER_IP" == "127.0.0.1" || "$SERVER_IP" == "localhost" ]] && echo "" || echo "--host-addr $SERVER_IP --port $NODE_PORT")
    fi
}


function run_cardano_pool {
    local KES_KEYS=$CARDANO_KEYS_DIR/kes
    local ERRMSG="${BOLD}${WHITE_ON_RED} ERROR: ${NORMAL} the pool is not configured properly."

    for KEY in node.cert kes.skey vrf.skey
    do
        if [ ! -e "$KES_KEYS/$KEY" ]; then
            echo -e $ERRMSG
            echo "$KES_KEYS/$KEY is missed!"
            exit 1
        fi
    done



    if prepare_software "cardano-node"; then
        SERVER_IP=$(from-config ".global.ip")
        NODE_PORT=$(from-config ".networks.\"${NETWORK_NAME}\".software.\"cardano-node\".\"node-port\"")

        

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
    fi
}

function run_cardano_db_sync {
    if prepare_software "cardano-db-sync"; then
        output=$("$(dirname "$0")/cardano.sh" $NETWORK_NAME database-manager check)                
        
       
        if echo "$output" | grep -q "All good!"; then
            PGPASSFILE=$CARDANO_CONFIG_DIR/pgpass  \
            $CARDANO_BINARIES_DIR/cardano-db-sync \
                --config $CARDANO_CONFIG_DIR/db-sync-config.json \
                --socket-path $CARDANO_SOCKET_PATH \
                --state-dir $CARDANO_STORAGE_DIR/db_sync/ \
                --schema-dir $CARDANO_CONFIG_DIR/schema/
        elif 
            echo "$output" | grep -qE "Error : User '.*' can't access postgres"; then
            echo ""    
            echo -e "\033[43m\033[30mWARNING: There is no '$USERNAME' user in postgres.\033[0m Let's fix it!"
            echo ""
            echo "First step:"
            echo "     sudo su - postgres"
            echo "  or, if there is no sudo, become root and use:"
            echo "     su - postgres"
            echo ""
            echo "Second step:"
            echo "     createuser --createdb --superuser $USERNAME"
            echo ""
            echo "Third step:"
            echo "     exit"
            echo ""
        elif echo "$output" | grep -qE "Error : No '.*' database"; then
            echo "The database does not exist, trying to fix..."
            output=$("$(dirname "$0")/cardano.sh" preprod database-manager createdb 2>/dev/null)
            if echo "$output" | grep -q "All good!"; then            
                echo "Ok, looks good, let's start it again!"                
                run_cardano_db_sync
            fi
        else
            echo "$output"
        fi
fi

}


function run_cardano_sapi {
    if prepare_software "cardano-node"; then
        SAPI_PORT=$(from-config ".networks.${NETWORK_NAME}.software.\"cardano-node\".\"submit-api-port\"")

        $CARDANO_BINARIES_DIR/cardano-submit-api \
        --config $CARDANO_CONFIG_DIR/submit-api-config.json \
        --socket-path $CARDANO_SOCKET_PATH \
        --port $SAPI_PORT \
        "${MAGIC[@]}"
    fi
}

function run_cardano_wallet {
    if prepare_software "cardano-wallet"; then
        SERVER_IP=$(from-config ".global.ip")
        CARDANO_WALLET_PORT=$(from-config ".networks.\"${NETWORK_NAME}\".software.\"cardano-wallet\".\"cardano-wallet-port\"")
        WALLETS_STORAGE=$CARDANO_STORAGE_DIR/wallets/
        mkdir -p $WALLETS_STORAGE

        $CARDANO_BINARIES_DIR/cardano-wallet serve \
        --listen-address 127.0.0.1 \
        --port $CARDANO_WALLET_PORT \
        --node-socket $CARDANO_SOCKET_PATH \
        --database $WALLETS_STORAGE \
        --sync-tolerance 300s \
        --log-level info \
        --$(if [ "$NETWORK_TYPE" == "mainnet" ]; then echo "mainnet"; else echo "testnet $CARDANO_CONFIG_DIR/byron-genesis.json"; fi)
    fi
}

