#!/bin/bash

source $(dirname "$0")/startup.sh
source $(dirname "$0")/tx_tool.sh

COLD_KEYS=$CARDANO_KEYS_DIR/cold
KES_KEYS=$CARDANO_KEYS_DIR/kes
PAYMENT_KEYS=$CARDANO_KEYS_DIR/payment

POOL_ID=$($CARDANO_BINARIES_DIR/cardano-cli stake-pool id \
--cold-verification-key-file $COLD_KEYS/cold.vkey)

echo "Checking pool status..."

POOL_STATE=$(CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH \
            $CARDANO_BINARIES_DIR/cardano-cli query pool-params \
                "${MAGIC[@]}" \
                --stake-pool-id $POOL_ID)

FUTURE_POOL_PARAMS=$(echo "$POOL_STATE" | jq -r ".futurePoolParams")
POOL_PARAMS=$(echo "$POOL_STATE" | jq -r ".poolParams")
POOL_RET=$(echo "$POOL_STATE" | jq -r ".retiring")


if ! [ "$FUTURE_POOL_PARAMS" == null ] || ! [ "$POOL_PARAMS" == null ] && [ "$POOL_RET" == null ] ; then
    echo -n "POOL IS ALREADY REGISTERED..."
    echo "renewing pool cert;"
    
    build_tx "tx" 0 $CARDANO_POOL_DIR/pool-registration.cert
else 
    echo -n "POOL IS NOT REGISTERED..."
    echo "init registration process;"
    
    $CARDANO_BINARIES_DIR/cardano-cli key verification-key \
        --signing-key-file $CARDANO_KEYS_DIR/payment/stake.skey \
        --verification-key-file $CARDANO_KEYS_DIR/payment/stake.vkey
    
    $CARDANO_BINARIES_DIR/cardano-cli key non-extended-key \
        --extended-verification-key-file $CARDANO_KEYS_DIR/payment/stake.vkey \
        --verification-key-file $CARDANO_KEYS_DIR/payment/stake.vkey
    
    $CARDANO_BINARIES_DIR/cardano-cli  stake-address delegation-certificate \
        --stake-verification-key-file $PAYMENT_KEYS/stake.vkey \
        --cold-verification-key-file $COLD_KEYS/cold.vkey \
        --out-file $CARDANO_POOL_DIR/delegation.cert
    
 
    build_tx "tx" $(jq -r ".stakePoolDeposit" $CARDANO_CONFIG_DIR/protocol.json) \
        $CARDANO_POOL_DIR/pool-registration.cert \
        $CARDANO_POOL_DIR/delegation.cert

  
    echo "Done!"
    rm $CARDANO_KEYS_DIR/payment/stake.vkey 
    rm $CARDANO_POOL_DIR/delegation.cert
fi

sign_tx  "tx" $CARDANO_KEYS_DIR/payment/payment.skey $CARDANO_KEYS_DIR/payment/stake.skey $COLD_KEYS/cold.skey 
send_tx  "tx"

for FILE in $(find $CARDANO_POOL_DIR -type f); do   
    chmod 0600 $FILE  
done 

for FILE in $(find $CARDANO_KEYS_DIR -type f); do   
    chmod 0600 $FILE  
done 

