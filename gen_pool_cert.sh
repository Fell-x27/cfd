#!/bin/bash
# сначала нужно сделать холодные ключи
source $(dirname "$0")/startup.sh
source $(dirname "$0")/tx_tool.sh

POOL_CONF=$CARDANO_POOL_DIR/settings.json

get_protocol

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

echo "Sertificate has been saved. Now you can register your pool."
rm $CARDANO_KEYS_DIR/payment/stake.vkey


