#!/bin/bash

function get-pool-state {
    local $POOL_ID=$1
    CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH \
    $CARDANO_BINARIES_DIR/cardano-cli query pool-state \
    "${MAGIC[@]}" \
    --stake-pool-id $POOL_ID
}

function get-stake-key-state {
    local $STAKE_ADDR=$1
    CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH \
        $CARDANO_BINARIES_DIR/cardano-cli query stake-address-info \
        --address $STAKE_ADDR \
        "${MAGIC[@]}"
}

function get-current-slot {
    CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH $CARDANO_BINARIES_DIR/cardano-cli \
     query \
     tip \
     "${MAGIC[@]}" | jq .slot
}


function register-stake-key {
    $CARDANO_BINARIES_DIR/cardano-cli key verification-key \
        --signing-key-file $CARDANO_KEYS_DIR/payment/stake.skey \
        --verification-key-file $CARDANO_KEYS_DIR/payment/stake.vkey
        
    $CARDANO_BINARIES_DIR/cardano-cli key non-extended-key \
        --extended-verification-key-file $CARDANO_KEYS_DIR/payment/stake.vkey \
        --verification-key-file $CARDANO_KEYS_DIR/payment/stake.vkey

    STAKE_ADDR=$($CARDANO_BINARIES_DIR/cardano-cli stake-address build \
        --stake-verification-key-file $CARDANO_KEYS_DIR/payment/stake.vkey \
        "${MAGIC[@]}")

    
    local STAKE_ADDR_STATE=$(wrap-cli-command get-stake-key-state $STAKE_ADDR)

    if [ "$STAKE_ADDR_STATE" == "[]" ]; then
        #NOT REGISTERED
        $CARDANO_BINARIES_DIR/cardano-cli stake-address registration-certificate \
        --stake-verification-key-file $CARDANO_KEYS_DIR/payment/stake.vkey \
        --out-file $CARDANO_KEYS_DIR/payment/stake.cert
        
       
        get-protocol   
 
        build-tx "tx" $(jq -r ".stakeAddressDeposit" $CARDANO_CONFIG_DIR/protocol.json) $CARDANO_KEYS_DIR/payment/stake.cert
        
        sign-tx  "tx" $CARDANO_KEYS_DIR/payment/payment.skey $CARDANO_KEYS_DIR/payment/stake.skey
        
        send-tx  "tx"
        
        rm $CARDANO_KEYS_DIR/payment/stake.cert
    else
        echo "ALREADY REGISTERED"
        if [ $(echo "$STAKE_ADDR_STATE" | jq -r ".[].delegation") == null ]; then
            echo "NOT DELEGATED"
        else
            echo "AND DELEGATED"
        fi
    fi

    rm $CARDANO_KEYS_DIR/payment/stake.vkey
}

function gen-pools-keys {    
    local COLD_KEYS=$CARDANO_KEYS_DIR/cold
    local KES_KEYS=$CARDANO_KEYS_DIR/kes
    

    if rewriting-prompt "$COLD_KEYS/cold.skey" "You are about to irreversibly delete an existing pool keys!"; then
        COLD_KEYS=$CARDANO_KEYS_DIR/cold
        KES_KEYS=$CARDANO_KEYS_DIR/kes

        mkdir -p $COLD_KEYS
        mkdir -p $KES_KEYS

        $CARDANO_BINARIES_DIR/cardano-cli node key-gen \
        --cold-verification-key-file $COLD_KEYS/cold.vkey \
        --cold-signing-key-file $COLD_KEYS/cold.skey \
        --operational-certificate-issue-counter-file $COLD_KEYS/cold.counter

        $CARDANO_BINARIES_DIR/cardano-cli node key-gen-VRF \
        --verification-key-file $KES_KEYS/vrf.vkey \
        --signing-key-file $KES_KEYS/vrf.skey    

        for FILE in $(find $CARDANO_KEYS_DIR -type f); do   
            chmod 0600 $FILE  
        done    
        
        echo ""
        echo "New cold keys are successfully created!"
        echo -e "\e[1;30;47mcold.skey:\e[0m $COLD_KEYS/cold.skey"
        echo -e "\e[1;30;47mcold.vkey:\e[0m $COLD_KEYS/cold.vkey"
        echo -e "\e[1;30;47mvrf.skey:\e[0m $KES_KEYS/vrf.skey"
        echo -e "\e[1;30;47mvrf.vkey:\e[0m $KES_KEYS/vrf.vkey"
        return 0
    else
        return 1
    fi
}

function gen-pool-cert {
    POOL_CONF=$CARDANO_POOL_DIR/settings.json

    get-protocol

    if ! test -f "$POOL_CONF"; then
        echo "{\"PLEDGE\":\"0\", \"OPCOST\":\"$(jq -r ".minPoolCost" $CARDANO_CONFIG_DIR/protocol.json)\", \"MARGIN\":\"0\", \"META_URL\":\"\", \"RELAYS\":\"\"}" > $POOL_CONF
    fi


    DEF_PLEDGE=$(jq -r '.PLEDGE' $POOL_CONF)
    DEF_OPCOST=$(jq -r '.OPCOST' $POOL_CONF)
    DEF_MARGIN=$(jq -r '.MARGIN' $POOL_CONF)
    DEF_META_URL=$(jq -r '.META_URL' $POOL_CONF)
    DEF_RELAYS=$(jq -r '.RELAYS' $POOL_CONF)

    echo "Please set the pool's parameters."
    echo "Leave fields blank to use the default values."
    echo "Your input will be saved as the new default values in the future."
    echo "Enter \"\" (an empty string with quotes) to remove any existing string values."
    echo ""

    read -p "Set pledge(in lovelaces)[$DEF_PLEDGE]:" PLEDGE
    PLEDGE=${PLEDGE:-$DEF_PLEDGE}
    PLEDGE=$(echo "$PLEDGE" | sed 's/"//g')

    read -p "Set operational costs(in lovelaces)[$DEF_OPCOST]:" OPCOST
    OPCOST=${OPCOST:-$DEF_OPCOST}
    OPCOST=$(echo "$OPCOST" | sed 's/"//g')

    read -p "Set margin(0-1)[$DEF_MARGIN]:" MARGIN
    MARGIN=${MARGIN:-$DEF_MARGIN}
    MARGIN=$(echo "$MARGIN" | sed 's/"//g')

    read -p "Set metadata URL(64 symbols)[$DEF_META_URL]:" META_URL
    META_URL=${META_URL:-$DEF_META_URL}
    META_URL=$(echo "$META_URL" | sed 's/"//g')

    if ! [ -z "$META_URL" ]; then     
        URL_STATUS=($(curl -Is $META_URL | head -1))

        if [ ${#META_URL} -le 64 ] && [ ${URL_STATUS[1]} == "200" ]; then
          META_HASH=$($CARDANO_BINARIES_DIR/cardano-cli stake-pool metadata-hash \
              --pool-metadata-file <(curl -s -L -k $META_URL))
          echo "    URL is OK; Calculated hash: $META_HASH"
        else
          META_HASH=""
          echo "URL is not responding; Ignored"
        fi
    fi

    read -p "Set relays separated by spaces(IP:PORT IP:PORT IP:PORT)[$DEF_RELAYS]:" RELAYS
    RELAYS=${RELAYS:-$DEF_RELAYS}
    RELAYS=$(echo "$RELAYS" | sed 's/"//g')


    echo "{\"PLEDGE\":\"$PLEDGE\", \"OPCOST\":\"$OPCOST\", \"MARGIN\":\"$MARGIN\", \"META_URL\":\"$META_URL\", \"RELAYS\":\"$RELAYS\"}" > $POOL_CONF

    echo ""


    COLD_KEYS=$CARDANO_KEYS_DIR/cold
    KES_KEYS=$CARDANO_KEYS_DIR/kes
    PAYMENT_KEYS=$CARDANO_KEYS_DIR/payment


    RELAYS=($RELAYS) 
    RELAYS=( "${RELAYS[@]/#/--pool-relay-ipv4 }" )
    RELAYS=( "${RELAYS[@]/:/ --pool-relay-port }" )

    if ! [ -z "$META_URL" ]; then
        META_URL="--metadata-url $META_URL"
    fi

    if ! [ -z "$META_HASH" ]; then
        META_HASH="--metadata-hash $META_HASH"
    fi


    $CARDANO_BINARIES_DIR/cardano-cli key verification-key \
        --signing-key-file $CARDANO_KEYS_DIR/payment/stake.skey \
        --verification-key-file $CARDANO_KEYS_DIR/payment/stake.vkey
        
    $CARDANO_BINARIES_DIR/cardano-cli key non-extended-key \
        --extended-verification-key-file $CARDANO_KEYS_DIR/payment/stake.vkey \
        --verification-key-file $CARDANO_KEYS_DIR/payment/stake.vkey


    $CARDANO_BINARIES_DIR/cardano-cli stake-pool registration-certificate \
        --cold-verification-key-file $COLD_KEYS/cold.vkey \
        --vrf-verification-key-file $KES_KEYS/vrf.vkey \
        --pool-pledge $PLEDGE \
        --pool-cost $OPCOST \
        --pool-margin $MARGIN \
        --pool-reward-account-verification-key-file $PAYMENT_KEYS/stake.vkey \
        --pool-owner-stake-verification-key-file $PAYMENT_KEYS/stake.vkey \
        "${MAGIC[@]}" \
        ${RELAYS[@]} \
        $META_URL \
        $META_HASH \
        --out-file $CARDANO_POOL_DIR/pool-registration.cert

    echo "Pool's certificate has been saved locally at $CARDANO_POOL_DIR/pool-registration.cert"
    echo "You have to post it on the Cardano blockchain then."
    rm $CARDANO_KEYS_DIR/payment/stake.vkey

}


function reg-pool-cert {
    local COLD_KEYS=$CARDANO_KEYS_DIR/cold
    local KES_KEYS=$CARDANO_KEYS_DIR/kes
    local PAYMENT_KEYS=$CARDANO_KEYS_DIR/payment

    local POOL_ID=$($CARDANO_BINARIES_DIR/cardano-cli stake-pool id \
    --cold-verification-key-file $COLD_KEYS/cold.vkey)

    echo "Checking pool status..."

    local POOL_STATE=$(wrap-cli-command get-pool-state $POOL_ID)
    
    KEY=$(echo "$POOL_STATE" | jq -r 'keys[0]')
    FUTURE_POOL_PARAMS=$(echo "$POOL_STATE" | jq -r ".$KEY.futurePoolParams")
    POOL_PARAMS=$(echo "$POOL_STATE" | jq -r ".$KEY.poolParams")
    POOL_RET=$(echo "$POOL_STATE" | jq -r ".$KEY.retiring")
    
    if [[ "$FUTURE_POOL_PARAMS" != "null" ]] || ( [[ "$POOL_PARAMS" != "null" ]] && [[ "$POOL_RET" == "null" ]] ); then
        echo -n "POOL IS ALREADY REGISTERED..."
        echo "renewing pool cert;"
        build-tx "tx" 0 $CARDANO_POOL_DIR/pool-registration.cert        
    else 
        echo -n "POOL IS NOT REGISTERED..."
        echo "init registration process;"
        $CARDANO_BINARIES_DIR/cardano-cli key verification-key \
            --signing-key-file $CARDANO_KEYS_DIR/payment/stake.skey \
            --verification-key-file $CARDANO_KEYS_DIR/payment/stake.vkey
        
        $CARDANO_BINARIES_DIR/cardano-cli key non-extended-key \
            --extended-verification-key-file $CARDANO_KEYS_DIR/payment/stake.vkey \
            --verification-key-file $CARDANO_KEYS_DIR/payment/stake.vkey
        
        $CARDANO_BINARIES_DIR/cardano-cli stake-address delegation-certificate \
            --stake-verification-key-file $PAYMENT_KEYS/stake.vkey \
            --cold-verification-key-file $COLD_KEYS/cold.vkey \
            --out-file $CARDANO_POOL_DIR/delegation.cert
        
    
        build-tx "tx" $(jq -r ".stakePoolDeposit" $CARDANO_CONFIG_DIR/protocol.json) \
            $CARDANO_POOL_DIR/pool-registration.cert \
            $CARDANO_POOL_DIR/delegation.cert

        echo "Done!"        
        rm $CARDANO_KEYS_DIR/payment/stake.vkey 
        rm $CARDANO_POOL_DIR/delegation.cert
    fi

    sign-tx  "tx" $CARDANO_KEYS_DIR/payment/payment.skey $CARDANO_KEYS_DIR/payment/stake.skey $COLD_KEYS/cold.skey 
    send-tx  "tx"

    echo -e "\033[43m\033[30mPlease wait until the transaction is confirmed on the blockchain to check if the pool has been registered.\033[0m"

    for FILE in $(find $CARDANO_POOL_DIR -type f); do   
        chmod 0600 $FILE  
    done 

    for FILE in $(find $CARDANO_KEYS_DIR -type f); do   
        chmod 0600 $FILE  
    done
}

function get-kes-period-info {
    CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH \
        $CARDANO_BINARIES_DIR/cardano-cli query kes-period-info \
        --op-cert-file $KES_KEYS/node.cert \
        --out-file=/dev/stderr \
        "${MAGIC[@]}" 1>/dev/null
}

function gen-kes-keys {
    local COLD_KEYS=$CARDANO_KEYS_DIR/cold
    local KES_KEYS=$CARDANO_KEYS_DIR/kes
    

    local KES_DURATION=$(cat $CARDANO_CONFIG_DIR/shelley-genesis.json | jq .slotsPerKESPeriod)
    local CURRENT_SLOT=$(wrap-cli-command get-current-slot)
    local CURRENT_KES_PERIOD=$(expr $CURRENT_SLOT / $KES_DURATION)

    $CARDANO_BINARIES_DIR/cardano-cli node key-gen-KES \
        --verification-key-file $KES_KEYS/kes.vkey \
        --signing-key-file $KES_KEYS/kes.skey
    
    local COUNTER_VALUE=0
    if [ -f "$KES_KEYS/node.cert" ]; then
        local KES_PERIOD_INFO=$(wrap-cli-command get-kes-period-info)
        local ON_DISK_STATE=$(jq -r '.qKesOnDiskOperationalCertificateNumber' <<< "$KES_PERIOD_INFO")
        local NODE_STATE=$(jq -r '.qKesNodeStateOperationalCertificateNumber' <<< "$KES_PERIOD_INFO")

        if [ -z "$NODE_STATE" ] || [ "$NODE_STATE" == "null" ]; then
            COUNTER_VALUE=0
        elif [ "$NODE_STATE" -lt "$ON_DISK_STATE" ]; then
            COUNTER_VALUE="$ON_DISK_STATE"
        elif [ "$NODE_STATE" -ge "$ON_DISK_STATE" ]; then
            COUNTER_VALUE=$((NODE_STATE + 1))            
        fi   
    fi

    $CARDANO_BINARIES_DIR/cardano-cli node new-counter \
        --cold-verification-key-file $COLD_KEYS/cold.vkey \
        --counter-value $COUNTER_VALUE \
        --operational-certificate-issue-counter-file $COLD_KEYS/cold.counter       

    $CARDANO_BINARIES_DIR/cardano-cli node issue-op-cert \
        --kes-verification-key-file $KES_KEYS/kes.vkey \
        --cold-signing-key-file $COLD_KEYS/cold.skey \
        --operational-certificate-issue-counter $COLD_KEYS/cold.counter \
        --kes-period $CURRENT_KES_PERIOD \
        --out-file $KES_KEYS/node.cert        
    

    for FILE in $(find $CARDANO_KEYS_DIR -type f); do   
        chmod 0600 $FILE  
    done 
    
    echo ""
    echo "Done!"
    echo "New KES counter is $COUNTER_VALUE"
}
