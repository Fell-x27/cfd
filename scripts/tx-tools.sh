#!/bin/bash

function build-tx {
    if [[ -f $CARDANO_KEYS_DIR/chainbuffer ]]; then
        source $CARDANO_KEYS_DIR/chainbuffer
    else
        CHAINED_UTXO_ID=""
        CHAINED_UTXO_BALANCE=""
    fi
    
    if ! [ -z $CHAINED_UTXO_ID ]; then
        local IS_TX_IN_MEMPOOL=$(wrap-cli-command is-tx-in-mempool $(echo "$CHAINED_UTXO_ID#0" | cut -d'#' -f1))        
        local TX_STATUS=$(echo "$IS_TX_IN_MEMPOOL" | jq -r '.exists')                 
        if [ "$TX_STATUS" == "false" ]; then
            CHAINED_UTXO_ID=""
            CHAINED_UTXO_BALANCE=""
            rm $CARDANO_KEYS_DIR/chainbuffer     
        fi
    fi    
    
       

    local TX_NAME=$1
    local DEPOSIT=${2:-0}
    local MIN_UTXO=2000000
    shift 2
    
    if [ $DEPOSIT -gt 0 ]; then
        MIN_UTXO=$(expr $DEPOSIT + $MIN_UTXO)
    fi    

    local CERTIFICATES=("$@")
    local CERTIFICATES=( $(build-arg-array "--certificate-file" ${CERTIFICATES[@]}) )
    
    local CHOSEN_UTXO=("0#0" 0)
    local UTXO_list=$(wrap-cli-command get-utxo-json)      
    local UTXO_hashes=($(echo $UTXO_list | jq -r ". | keys" | jq -r ".[]"))    
  
   
    if [[ -z "$CHAINED_UTXO_ID" || -z "$CHAINED_UTXO_BALANCE" ]]; then  
#        echo -e "${WHITE_ON_RED} NOT CHAINED ${NORMAL}"              
        for i in "${UTXO_hashes[@]}"
        do
            AMOUNT=$(echo $UTXO_list | jq -r ".[\"$i\"].value.lovelace")
            if [ $AMOUNT -gt ${CHOSEN_UTXO[1]} ]; then
                CHOSEN_UTXO[0]=$i
                CHOSEN_UTXO[1]=$AMOUNT
            fi
        done
    else
#        echo -e "${WHITE_ON_RED} CHAINED ${NORMAL}"
        CHOSEN_UTXO[0]=$CHAINED_UTXO_ID
        CHOSEN_UTXO[1]=$CHAINED_UTXO_BALANCE        
    fi

    
    if [ ${CHOSEN_UTXO[1]} -lt $MIN_UTXO ]; then
        echo -e "${BOLD}${BLACK_ON_YELLOW} WARNING! ${NORMAL} Can't process transaction! The balance of the wallet is insufficient. Please, fund it."
        echo -e "There should be at least one UTxO with approximately ${BLACK_ON_LIGHT_GRAY} $(expr $MIN_UTXO / 1000000) ADA ${NORMAL} and no assets:"
        wrap-cli-command get-utxo-pretty
        exit 0
    fi   

    CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH $CARDANO_BINARIES_DIR/cardano-cli transaction build-raw \
        --tx-in ${CHOSEN_UTXO[0]} \
        --tx-out $(cat $CARDANO_KEYS_DIR/payment/base.addr)+0 \
        --fee 200000 \
        --out-file $CARDANO_KEYS_DIR/$TX_NAME.raw \
        ${CERTIFICATES[@]}


    get-protocol

    local FEE=($($CARDANO_BINARIES_DIR/cardano-cli transaction calculate-min-fee \
     --protocol-params-file $CARDANO_CONFIG_DIR/protocol.json  \
     --tx-in-count 2 \
     --tx-out-count 2 \
     --witness-count 2 \
     --tx-body-file $CARDANO_KEYS_DIR/$TX_NAME.raw \
    "${MAGIC[@]}"     
     ))

    local CHANGE=$(expr ${CHOSEN_UTXO[1]} - $DEPOSIT - ${FEE[0]})

    CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH $CARDANO_BINARIES_DIR/cardano-cli transaction build-raw \
        --tx-in ${CHOSEN_UTXO[0]} \
        --tx-out $(cat $CARDANO_KEYS_DIR/payment/base.addr)+$CHANGE \
        --fee $FEE \
        --out-file $CARDANO_KEYS_DIR/$TX_NAME.raw \
        ${CERTIFICATES[@]}
        
    CHAINED_UTXO_BALANCE=$CHANGE
    CHAINED_UTXO_ID="$($CARDANO_BINARIES_DIR/cardano-cli transaction txid --tx-file $CARDANO_KEYS_DIR/$TX_NAME.raw)#0"
    
    echo "CHAINED_UTXO_ID='$CHAINED_UTXO_ID'" > $CARDANO_KEYS_DIR/chainbuffer
    echo "CHAINED_UTXO_BALANCE='$CHAINED_UTXO_BALANCE'" >> $CARDANO_KEYS_DIR/chainbuffer
}

function sign-tx {
    local TX_NAME=$1
    shift
    local SIGN_KEYS=("$@")
    local SIGN_KEYS_PATHS=()

    for key in "${SIGN_KEYS[@]}"; do
        reveal-key "$key"
        SIGN_KEYS_PATHS+=( "$key" )
    done

    trap 'for key in "${SIGN_KEYS_PATHS[@]}"; do hide-key "$key"; done' EXIT

    CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH $CARDANO_BINARIES_DIR/cardano-cli transaction sign \
        --tx-body-file $CARDANO_KEYS_DIR/$TX_NAME.raw \
        $(build-arg-array "--signing-key-file" "${SIGN_KEYS[@]}") \
        "${MAGIC[@]}" \
        --out-file $CARDANO_KEYS_DIR/$TX_NAME.signed

    trap - EXIT

    for key in "${SIGN_KEYS_PATHS[@]}"; do
        hide-key "$key"
    done

    rm $CARDANO_KEYS_DIR/$TX_NAME.raw
}



function send-tx {
    local TX_NAME=$1

    RESPONSE=$(CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH $CARDANO_BINARIES_DIR/cardano-cli transaction submit \
        --tx-file $CARDANO_KEYS_DIR/$TX_NAME.signed \
        "${MAGIC[@]}" 2>&1)
    
    rm $CARDANO_KEYS_DIR/$TX_NAME.signed
    
    if ! echo "$RESPONSE" | grep -q "successfully"; then
        rm $CARDANO_KEYS_DIR/chainbuffer
    fi
    
    if echo $RESPONSE | grep -q "BadInputsUTxO"; then
        echo "Transaction cannot be made at the moment, please wait until the previous transaction is placed in the blockchain."
        return 1
    elif echo $RESPONSE | grep -q "StakeDelegationImpossibleDELEG" || echo $RESPONSE | grep -q "StakeKeyNotRegisteredDELEG"; then
        #rm $CARDANO_KEYS_DIR/chainbuffer
        echo -e "${BOLD}${WHITE_ON_RED} ERROR :${NORMAL} Can't register the pool - your staking key is not registered!" 
        return 1
    else
        echo $RESPONSE
        return 0
    fi    
}
