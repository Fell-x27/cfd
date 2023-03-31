#!/bin/bash

source $(dirname "$0")/startup.sh
source $(dirname "$0")/tx_tool.sh

$CARDANO_BINARIES_DIR/cardano-cli key verification-key \
    --signing-key-file $CARDANO_KEYS_DIR/payment/stake.skey \
    --verification-key-file $CARDANO_KEYS_DIR/payment/stake.vkey
    
$CARDANO_BINARIES_DIR/cardano-cli key non-extended-key \
    --extended-verification-key-file $CARDANO_KEYS_DIR/payment/stake.vkey \
    --verification-key-file $CARDANO_KEYS_DIR/payment/stake.vkey

STAKE_ADDR=$($CARDANO_BINARIES_DIR/cardano-cli stake-address build \
    --stake-verification-key-file $CARDANO_KEYS_DIR/payment/stake.vkey \
    "${MAGIC[@]}")


STAKE_ADDR_STATE=$(CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH \
$CARDANO_BINARIES_DIR/cardano-cli query stake-address-info \
--address $STAKE_ADDR \
"${MAGIC[@]}")

if [ "$STAKE_ADDR_STATE" == "[]" ]; then
    #NOT REGISTERED
    $CARDANO_BINARIES_DIR/cardano-cli stake-address registration-certificate \
    --stake-verification-key-file $CARDANO_KEYS_DIR/payment/stake.vkey \
    --out-file $CARDANO_KEYS_DIR/payment/stake.cert
    
    get_protocol   

    build_tx "tx" $(jq -r ".stakeAddressDeposit" $CARDANO_CONFIG_DIR/protocol.json) $CARDANO_KEYS_DIR/payment/stake.cert
    
    sign_tx  "tx" $CARDANO_KEYS_DIR/payment/payment.skey $CARDANO_KEYS_DIR/payment/stake.skey
    
    send_tx  "tx"
    
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


