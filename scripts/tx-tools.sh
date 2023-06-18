#!/bin/bash

function get-protocol {
    CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH \
    $CARDANO_BINARIES_DIR/cardano-cli query protocol-parameters "${MAGIC[@]}" --out-file $CARDANO_CONFIG_DIR/protocol.json
}

function get-utxo-json {
    CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH \
    $CARDANO_BINARIES_DIR/cardano-cli query utxo \
        --address $(cat $CARDANO_KEYS_DIR/payment/base.addr) \
        --out-file=/dev/stdout \
        "${MAGIC[@]}"
}

function get-utxo-pretty {
    echo ""
    cat $CARDANO_KEYS_DIR/payment/base.addr
    echo ""
    echo ""
    CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH \
    $CARDANO_BINARIES_DIR/cardano-cli query utxo \
    --address $(cat $CARDANO_KEYS_DIR/payment/base.addr) \
    "${MAGIC[@]}"
}

function build-tx {
    local TX_NAME=$1
    local DEPOSIT=${2:-0}
    local MIN_UTXO=$(expr $DEPOSIT + 2000000)
    shift 2
    

    local CERTIFICATES=("$@")
    local CERTIFICATES=( $(build-arg-array "--certificate-file" ${CERTIFICATES[@]}) )
    
    local UTXO_list=$(wrap-cli-command get-utxo-json)
    
    
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

    
    if [ ${CHOSEN_UTXO[1]} -lt $MIN_UTXO ]; then
        echo -e "\e[30;43mWARNING!\e[0m Can't process transaction! The balance of the wallet is insufficient. Please, fund it."
        echo "There should be at least one UTxO with approximately $MIN_UTXO lovelaces and no assets:"
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
     --tx-in-count 1 \
     --tx-out-count 1 \
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
}

function sign-tx {
    local TX_NAME=$1
    shift
    local SIGN_KEYS=("$@")
    local SIGN_KEYS=( $(build-arg-array "--signing-key-file" "${SIGN_KEYS[@]}") )

    CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH $CARDANO_BINARIES_DIR/cardano-cli transaction sign \
        --tx-body-file $CARDANO_KEYS_DIR/$TX_NAME.raw \
        "${SIGN_KEYS[@]}" \
        "${MAGIC[@]}" \
        --out-file $CARDANO_KEYS_DIR/$TX_NAME.signed

    rm $CARDANO_KEYS_DIR/$TX_NAME.raw
}

function send-tx {
    local TX_NAME=$1

    CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH $CARDANO_BINARIES_DIR/cardano-cli transaction submit \
        --tx-file $CARDANO_KEYS_DIR/$TX_NAME.signed \
        "${MAGIC[@]}"

    rm $CARDANO_KEYS_DIR/$TX_NAME.signed
}
