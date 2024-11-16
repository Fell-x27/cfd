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

function reg-stake-key {
    if [ ! -f "$CARDANO_KEYS_DIR/payment/stake.skey" ] || \
       [ ! -f "$CARDANO_KEYS_DIR/payment/payment.skey" ]; then
        echo -e "${BOLD}${WHITE_ON_RED }ERROR ${NORMAL}: you have to create or restore wallet before!"
        exit 1
    fi

    local STAKE_ADDR=$(cat $CARDANO_KEYS_DIR/payment/stake.addr)

    local STAKE_ADDR_STATE=$(wrap-cli-command get-stake-key-state $STAKE_ADDR)

    if [ "$STAKE_ADDR_STATE" == "[]" ]; then
        #NOT REGISTERED
        DEPOSIT=$(jq -r ".stakeAddressDeposit" $CARDANO_CONFIG_DIR/protocol.json)

        $CARDANO_BINARIES_DIR/cardano-cli latest stake-address registration-certificate \
        --stake-verification-key-file $CARDANO_KEYS_DIR/payment/stake.vkey \
        --key-reg-deposit-amt $DEPOSIT \
        --out-file $CARDANO_KEYS_DIR/payment/stake.cert
       
        wrap-cli-command get-protocol   
 
        build-tx "tx" $DEPOSIT 0 $CARDANO_KEYS_DIR/payment/stake.cert
        sign-tx "tx" $CARDANO_KEYS_DIR/payment/payment.skey $CARDANO_KEYS_DIR/payment/stake.skey
        echo "Trying to register..."
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

}

function unreg-stake-key {
    if [ ! -f "$CARDANO_KEYS_DIR/payment/stake.skey" ] || \
       [ ! -f "$CARDANO_KEYS_DIR/payment/payment.skey" ]; then
        echo -e "${BOLD}${WHITE_ON_RED }ERROR ${NORMAL}: you have to create or restore wallet before!"
        exit 1
    fi
       
    local STAKE_ADDR=$(cat $CARDANO_KEYS_DIR/payment/stake.addr)
    
    local STAKE_ADDR_STATE=$(wrap-cli-command get-stake-key-state $STAKE_ADDR)

    if [ "$STAKE_ADDR_STATE" == "[]" ]; then
        echo -e "${BOLD}${WHITE_ON_RED} ERROR :${NORMAL} Your stake key is not registered"
    else
        local REWARDS=$(echo $STAKE_ADDR_STATE | jq -r '.[0].rewardAccountBalance')
        local DEPOSIT=$(echo $STAKE_ADDR_STATE | jq -r '.[0].delegationDeposit')

        echo -e "${BLACK_ON_YELLOW} Warning! ${NORMAL} Your stake key will be de-registered!"
        echo -e "All your pending rewards (if any) will be ${BOLD}${UNDERLINE}transered to your wallet${NORMAL}!"
        echo -e "You have $REWARDS Lovelace in rewards."
        echo -e "The deposit of ${DEPOSIT} Lovelace will also be returned to your wallet."


        if ! are-you-sure-dialog; then            
            echo "Aborted.";
            exit 1
        fi

        wrap-cli-command get-protocol

        $CARDANO_BINARIES_DIR/cardano-cli latest stake-address deregistration-certificate \
            --stake-verification-key-file $CARDANO_KEYS_DIR/payment/stake.vkey \
            --key-reg-deposit-amt $DEPOSIT \
            --out-file $CARDANO_KEYS_DIR/payment/stake.cert


        build-tx "tx" -$(jq -r ".stakeAddressDeposit" $CARDANO_CONFIG_DIR/protocol.json) $REWARDS $CARDANO_KEYS_DIR/payment/stake.cert
        sign-tx "tx" $CARDANO_KEYS_DIR/payment/payment.skey $CARDANO_KEYS_DIR/payment/stake.skey
        send-tx "tx"
                  
        rm $CARDANO_KEYS_DIR/payment/stake.cert
    fi
}


function gen-pools-keys {    
    local COLD_KEYS=$CARDANO_KEYS_DIR/cold
    local KES_KEYS=$CARDANO_KEYS_DIR/kes

    mkdir -p $COLD_KEYS
    mkdir -p $KES_KEYS

    if rewriting-prompt "$COLD_KEYS/cold.skey" "You are about to irreversibly delete an existing pool keys!"; then
        $CARDANO_BINARIES_DIR/cardano-cli node key-gen \
        --cold-verification-key-file $COLD_KEYS/cold.vkey \
        --cold-signing-key-file $COLD_KEYS/cold.skey \
        --operational-certificate-issue-counter-file $COLD_KEYS/cold.counter

        hide-key  $COLD_KEYS/cold.skey

        $CARDANO_BINARIES_DIR/cardano-cli node key-gen-VRF \
        --verification-key-file $KES_KEYS/vrf.vkey \
        --signing-key-file $KES_KEYS/vrf.skey

        hide-key $KES_KEYS/vrf.skey

        chmod 0600 $COLD_KEYS/cold.skey
        chmod 0600 $COLD_KEYS/cold.vkey
        chmod 0600 $KES_KEYS/vrf.skey
        chmod 0600 $KES_KEYS/vrf.vkey
        
        echo ""
        echo "New cold keys are successfully created!"
        echo -e "${UNDERLINE}cold.skey:${NORMAL} $COLD_KEYS/cold.skey"
        echo -e "${UNDERLINE}cold.vkey:${NORMAL} $COLD_KEYS/cold.vkey"
        echo -e "${UNDERLINE}vrf.skey:${NORMAL} $KES_KEYS/vrf.skey"
        echo -e "${UNDERLINE}vrf.vkey:${NORMAL} $KES_KEYS/vrf.vkey"
        return 0
    else
        return 1
    fi
}

function gen-pool-cert {
    local COLD_KEYS=$CARDANO_KEYS_DIR/cold
    local KES_KEYS=$CARDANO_KEYS_DIR/kes
    local PAYMENT_KEYS=$CARDANO_KEYS_DIR/payment

    if [ ! -f "$CARDANO_KEYS_DIR/payment/stake.skey" ]; then
        echo -e "${BOLD}${WHITE_ON_RED} ERROR ${NORMAL}: you have to create or restore wallet before!"
        exit 1
    fi

    if [ ! -f "$COLD_KEYS/cold.skey" ] || \
       [ ! -f "$KES_KEYS/vrf.skey" ]; then
        echo -e "${BOLD}${WHITE_ON_RED} ERROR ${NORMAL}: can't find [cold.skey, vrf.skey] keys. Please move them to $COLD_KEYS or launch 'init-pool' to create them."
        exit 1
    fi


    local POOL_CONF=$CARDANO_POOL_DIR/settings.json

    wrap-cli-command get-protocol 
    
    local MIN_POOL_COST=$(jq -r ".minPoolCost" $CARDANO_CONFIG_DIR/protocol.json)

    if ! test -f "$POOL_CONF"; then
        echo "{\"PLEDGE\":\"0\", \"OPCOST\":\"$MIN_POOL_COST\", \"MARGIN\":\"0\", \"META_URL\":\"\", \"RELAYS\":\"\"}" > $POOL_CONF
    fi


    local DEF_PLEDGE=$(jq -r '.PLEDGE' $POOL_CONF)
    local DEF_OPCOST=$(jq -r '.OPCOST' $POOL_CONF)
    local DEF_MARGIN=$(jq -r '.MARGIN' $POOL_CONF)
    local DEF_META_URL=$(jq -r '.META_URL' $POOL_CONF)
    local DEF_RELAYS=$(jq -r '.RELAYS' $POOL_CONF)

    echo "Please set the pool's parameters."
    echo "Leave fields blank to use the default values."
    echo "Your input will be saved as the new default values in the future."
    echo "Enter \"\" (an empty string with quotes) to remove any existing string values."
    echo ""

    local PLEDGE OPCOST MARGIN META_URL META_HASH URL_STATUS RELAYS

    read -p "Set pledge(in lovelaces)[$DEF_PLEDGE]:" PLEDGE
    PLEDGE=${PLEDGE:-$DEF_PLEDGE}
    PLEDGE=$(echo "$PLEDGE" | sed 's/"//g')

    read -p "Set operational cost(in lovelaces)[$DEF_OPCOST]:" OPCOST
    OPCOST=${OPCOST:-$DEF_OPCOST}
    OPCOST=$(echo "$OPCOST" | sed 's/"//g')
   
    if (( OPCOST < MIN_POOL_COST )); then
        OPCOST=$MIN_POOL_COST
        echo "Operational cost cannot be less than $MIN_POOL_COST. It has been set to $MIN_POOL_COST."
    fi


    read -p "Set margin(0-1)[$DEF_MARGIN]:" MARGIN
    MARGIN=${MARGIN:-$DEF_MARGIN}
    MARGIN=$(echo "$MARGIN" | sed 's/"//g')

    if (( $(echo "$MARGIN > 1" | bc -l) )); then
        MARGIN=1
        echo "Margin cannot be greater than 1. It has been set to 1."
    elif (( $(echo "$MARGIN < 0" | bc -l) )); then
        MARGIN=0
        echo "Margin cannot be less than 0. It has been set to 0."
    fi

    read -p "Set metadata URL(64 symbols)[$DEF_META_URL]:" META_URL
    META_URL=${META_URL:-$DEF_META_URL}
    META_URL=$(echo "$META_URL" | sed 's/"//g')

    if ! [ -z "$META_URL" ]; then     
        URL_STATUS=($(curl -Is $META_URL | head -1))

        if [ ${#META_URL} -le 64 ] && [ ${URL_STATUS[1]} == "200" ]; then
          META_HASH=$($CARDANO_BINARIES_DIR/cardano-cli latest stake-pool metadata-hash \
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


    RELAYS=($RELAYS) 
    RELAYS=( "${RELAYS[@]/#/--pool-relay-ipv4 }" )
    RELAYS=( "${RELAYS[@]/:/ --pool-relay-port }" )

    if ! [ -z "$META_URL" ]; then
        META_URL="--metadata-url $META_URL"
    fi

    if ! [ -z "$META_HASH" ]; then
        META_HASH="--metadata-hash $META_HASH"
    fi


    $CARDANO_BINARIES_DIR/cardano-cli latest stake-pool registration-certificate \
        --cold-verification-key-file $COLD_KEYS/cold.vkey \
        --vrf-verification-key-file $KES_KEYS/vrf.vkey \
        --pool-pledge $PLEDGE \
        --pool-cost $OPCOST \
        --pool-margin $MARGIN \
        --pool-reward-account-verification-key-file $PAYMENT_KEYS/stake.vkey \
        --pool-owner-stake-verification-key-file $PAYMENT_KEYS/stake.vkey \
        "${MAGIC[@]}" \
        "${RELAYS[@]}" \
        $META_URL \
        $META_HASH \
        --out-file $CARDANO_POOL_DIR/pool-registration.cert

    if ! are-you-sure-dialog "Submit it to the blockchain?" "y"; then
        echo "Aborted."
        exit 1
    else 
        echo "Submitting...." 
        reg-pool-cert   
    fi      
}

function get-pool-id {
    local COLD_KEYS=$CARDANO_KEYS_DIR/cold

    if [ ! -f "$CARDANO_KEYS_DIR/payment/stake.skey" ]; then
        echo -e "${BOLD}${WHITE_ON_RED }ERROR ${NORMAL}: you have to create or restore a wallet before!"
        exit 1
    fi

    if [ ! -f "$COLD_KEYS/cold.vkey" ]; then
        echo -e "${BOLD}${WHITE_ON_RED }ERROR ${NORMAL}: can't find [cold.vkey]. Please move it to $COLD_KEYS or launch 'init-pool' to create it."
        exit 1
    fi


    local POOL_ID=$($CARDANO_BINARIES_DIR/cardano-cli latest stake-pool id \
    --cold-verification-key-file $COLD_KEYS/cold.vkey)

    echo $POOL_ID
}

function get-pool-data {   
    local POOL_ID=$(get-pool-id)
    echo $(wrap-cli-command get-pool-state ${POOL_ID})    
}


function reg-pool-cert {
    local COLD_KEYS=$CARDANO_KEYS_DIR/cold
    local PAYMENT_KEYS=$CARDANO_KEYS_DIR/payment

    echo "Checking pool status..."
    local POOL_STATE=$(get-pool-data)
    
    local KEY=$(echo "$POOL_STATE" | jq -r 'keys[0]')
    local FUTURE_POOL_PARAMS=$(echo "$POOL_STATE" | jq -r ".\"$KEY\".futurePoolParams")
    local POOL_PARAMS=$(echo "$POOL_STATE" | jq -r ".\"$KEY\".poolParams")
    local POOL_RET=$(echo "$POOL_STATE" | jq -r ".\"$KEY\".retiring")        
    
    if [[ "$FUTURE_POOL_PARAMS" != "null" ]] || [[ "$POOL_PARAMS" != "null" ]]; then
        echo -n "POOL IS ALREADY REGISTERED..."
        echo "renewing pool cert;"
        build-tx "tx" 0 0 $CARDANO_POOL_DIR/pool-registration.cert        
    else 
        echo -n "POOL IS NOT REGISTERED..."
        echo "init registration process;"
        
        $CARDANO_BINARIES_DIR/cardano-cli latest stake-address stake-delegation-certificate \
            --stake-verification-key-file $PAYMENT_KEYS/stake.vkey \
            --cold-verification-key-file $COLD_KEYS/cold.vkey \
            --out-file $CARDANO_POOL_DIR/delegation.cert
        
    
        build-tx "tx" $(jq -r ".stakePoolDeposit" $CARDANO_CONFIG_DIR/protocol.json) 0 \
            $CARDANO_POOL_DIR/pool-registration.cert \
            $CARDANO_POOL_DIR/delegation.cert
                    
        rm $CARDANO_POOL_DIR/delegation.cert
    fi

    sign-tx  "tx" $CARDANO_KEYS_DIR/payment/payment.skey $CARDANO_KEYS_DIR/payment/stake.skey $COLD_KEYS/cold.skey 
    if send-tx "tx"; then
        echo "Done!"
        echo -e "${BLACK_ON_YELLOW}Please wait until the transaction is confirmed on the blockchain to check if the pool has been registered.${NORMAL}"
    fi    
}

function unreg-pool-cert {
    local COLD_KEYS=$CARDANO_KEYS_DIR/cold
    local KES_KEYS=$CARDANO_KEYS_DIR/kes
    local PAYMENT_KEYS=$CARDANO_KEYS_DIR/payment

    echo "Checking pool status..."
    local POOL_STATE=$(get-pool-data)
    
    local POOL_ID=$($CARDANO_BINARIES_DIR/cardano-cli latest stake-pool id \
    --cold-verification-key-file $COLD_KEYS/cold.vkey)
    
    local KEY=$(echo "$POOL_STATE" | jq -r 'keys[0]')   
   
    local FUTURE_POOL_PARAMS=$(echo "$POOL_STATE" | jq -r ".\"$KEY\".futurePoolParams")
    local POOL_PARAMS=$(echo "$POOL_STATE" | jq -r ".\"$KEY\".poolParams")
    local POOL_RET=$(echo "$POOL_STATE" | jq -r ".\"$KEY\".retiring")
    
    if ( [[ "$FUTURE_POOL_PARAMS" != "null" ]] ||  [[ "$POOL_PARAMS" != "null" ]] ); then
        echo "The pool [$POOL_ID] will be retired"
       
        if ! are-you-sure-dialog; then            
            echo "Aborted.";
            exit 1
        else
            local MAX_RETIREMENT_TIME=$(jq -r ".poolRetireMaxEpoch" $CARDANO_CONFIG_DIR/protocol.json)
            local NUMBER
            
            echo "You need to specify the number of epochs your pool will continue to work before retirement."
            read -p "Please enter a count between 1 and $MAX_RETIREMENT_TIME: " NUMBER
            if ! [[ $NUMBER =~ ^[0-9]+$ ]] || [ "$NUMBER" -lt 1 ] || [ "$NUMBER" -gt $MAX_RETIREMENT_TIME ]; then
                echo "Invalid input. Exiting."
                exit 1
            fi
            
            local CURRENT_EPOCH=$(wrap-cli-command get-current-epoch)
            
            $CARDANO_BINARIES_DIR/cardano-cli latest stake-pool deregistration-certificate \
                --cold-verification-key-file $COLD_KEYS/cold.vkey \
                --epoch $(expr $CURRENT_EPOCH + $NUMBER) \
                --out-file $CARDANO_POOL_DIR/pool-deregistration.cert     
                
            build-tx "tx" 0 0 $CARDANO_POOL_DIR/pool-deregistration.cert
            sign-tx  "tx" $CARDANO_KEYS_DIR/payment/payment.skey $COLD_KEYS/cold.skey 
            if send-tx "tx"; then                          
                echo -e "${BLACK_ON_YELLOW}Please wait until the transaction is confirmed on the blockchain to check if the pool has been unregistered.${NORMAL}"
            fi
            rm $CARDANO_POOL_DIR/pool-deregistration.cert   
        fi           
        
    else 
        echo "The pool is not registered..."        
    fi
}

function gen-kes-keys {
    local COLD_KEYS=$CARDANO_KEYS_DIR/cold
    local KES_KEYS=$CARDANO_KEYS_DIR/kes

    if [ ! -f "$COLD_KEYS/cold.skey" ] || \
       [ ! -f "$KES_KEYS/vrf.skey" ]; then
        echo -e "${BOLD}${WHITE_ON_RED }ERROR ${NORMAL}: can't find [cold.skey, vrf.skey] keys. Please move them to $COLD_KEYS or launch 'init-pool' to create them."
        exit 1
    fi    

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

    trap 'hide-key $COLD_KEYS/cold.skey' EXIT
    reveal-key $COLD_KEYS/cold.skey

    $CARDANO_BINARIES_DIR/cardano-cli node issue-op-cert \
        --kes-verification-key-file $KES_KEYS/kes.vkey \
        --cold-signing-key-file $COLD_KEYS/cold.skey \
        --operational-certificate-issue-counter $COLD_KEYS/cold.counter \
        --kes-period $CURRENT_KES_PERIOD \
        --out-file $KES_KEYS/node.cert

    hide-key $COLD_KEYS/cold.skey
    trap - EXIT

    chmod 0600 $KES_KEYS/kes.skey
    chmod 0600 $KES_KEYS/kes.vkey
    chmod 0600 $KES_KEYS/node.cert
    
    echo ""            
    echo "New KES are successfully created!"
    echo -e "${UNDERLINE}kes.skey:${NORMAL} $KES_KEYS/kes.skey"
    echo -e "${UNDERLINE}kes.vkey:${NORMAL} $KES_KEYS/kes.vkey"
    echo -e "${UNDERLINE}node.cert:${NORMAL} $KES_KEYS/node.cert"
    echo "Current KES counter is $COUNTER_VALUE"
}
