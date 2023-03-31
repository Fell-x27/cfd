#!/bin/bash

function get_protocol(){
    CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH \
    $CARDANO_BINARIES_DIR/cardano-cli query protocol-parameters "${MAGIC[@]}" --out-file $CARDANO_CONFIG_DIR/protocol.json
}

function get_utxo_json(){
    CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH \
    $CARDANO_BINARIES_DIR/cardano-cli query utxo \
        --address $(cat $CARDANO_KEYS_DIR/payment/base.addr) \
        --out-file=/dev/stdout \
        "${MAGIC[@]}"
}

function build_tx(){
    local TX_NAME=$1
    local DEPOSIT=${2:-0}
    shift 2
    

    #local CERTIFICATES=( "${CERTIFICATES[@]/#/--certificate-file }" )

    local CERTIFICATES=("$@")
    local CERTIFICATES=( $(build_arg_array "--certificate-file" ${CERTIFICATES[@]}) )
    
    local UTXO_list=$(get_utxo_json)
    local UTXO_hashes=($(echo $UTXO_list | jq -r ". | keys" | jq -r ".[]"))
    local CHOSEN_UTXO=("0#0" 0)

    for i in "${UTXO_hashes[@]}"
    do
        AMOUNT=$(echo $UTXO_list | jq -r ".[\"$i\"].value.lovelace")
        if [ $AMOUNT -gt ${CHOSEN_UTXO[1]} ]; then
            CHOSEN_UTXO[0]=$i
            CHOSEN_UTXO[1]=$AMOUNT
        fi
    done


    CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH $CARDANO_BINARIES_DIR/cardano-cli transaction build-raw \
        --tx-in ${CHOSEN_UTXO[0]} \
        --tx-out $(cat $CARDANO_KEYS_DIR/payment/base.addr)+0 \
        --fee 200000 \
        --out-file $CARDANO_KEYS_DIR/$TX_NAME.raw \
        ${CERTIFICATES[@]}


    get_protocol

    local FEE=($($CARDANO_BINARIES_DIR/cardano-cli transaction calculate-min-fee \
     --protocol-params-file $CARDANO_CONFIG_DIR/protocol.json  \
     --tx-in-count 1 \
     --tx-out-count 1 \
     --witness-count 2 \
     --tx-body-file $CARDANO_KEYS_DIR/$TX_NAME.raw))

    local CHANGE=$(expr ${CHOSEN_UTXO[1]} - $DEPOSIT - ${FEE[0]})

    CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH $CARDANO_BINARIES_DIR/cardano-cli transaction build-raw \
        --tx-in ${CHOSEN_UTXO[0]} \
        --tx-out $(cat $CARDANO_KEYS_DIR/payment/base.addr)+$CHANGE \
        --fee $FEE \
        --out-file $CARDANO_KEYS_DIR/$TX_NAME.raw \
        ${CERTIFICATES[@]}
}

function sign_tx(){
    local TX_NAME=$1
    shift
    local SIGN_KEYS=("$@")
    #local SIGN_KEYS=( "${SIGN_KEYS[@]/#/--signing-key-file }" )
    local SIGN_KEYS=( $(build_arg_array "--signing-key-file" "${SIGN_KEYS[@]}") )

    CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH $CARDANO_BINARIES_DIR/cardano-cli transaction sign \
        --tx-body-file $CARDANO_KEYS_DIR/$TX_NAME.raw \
        "${SIGN_KEYS[@]}" \
        "${MAGIC[@]}" \
        --out-file $CARDANO_KEYS_DIR/$TX_NAME.signed

    rm $CARDANO_KEYS_DIR/$TX_NAME.raw
}

function send_tx(){
    local TX_NAME=$1

    CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH $CARDANO_BINARIES_DIR/cardano-cli transaction submit \
        --tx-file $CARDANO_KEYS_DIR/$TX_NAME.signed \
        "${MAGIC[@]}"

    rm $CARDANO_KEYS_DIR/$TX_NAME.signed
}
