#!/bin/bash

# ANSI escape codes
BOLD="\033[1m"
NORMAL="\033[0m"

BLACK_ON_YELLOW="\033[30;43m"
BLACK_ON_LIGHT_GRAY="\033[30;47m"
WHITE_ON_RED="\033[37;41m"


spin() {
  local -r chars="/-\|"

  while :; do
    for (( i=0; i<${#chars}; i++ )); do
      sleep 0.1
      echo -ne "${chars:$i:1}" "\r"
    done
  done
}

function check-db-sync-state {
    local PGPASS_FILE=$1
    local PORT=$(cut -d ':' -f 2 $PGPASS_FILE)

    if netstat -tuln | grep $PORT >/dev/null; then
        echo "Port $PORT is active. PostgreSQL might be running."
    else
        echo -e "${BOLD}${WHITE_ON_RED} ERROR: ${NORMAL} Port $PORT is not active. PostgreSQL might not be installed or running."
        exit 1
    fi
}

function get-protocol {
    CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH \
    $CARDANO_BINARIES_DIR/cardano-cli query protocol-parameters "${MAGIC[@]}" --out-file $CARDANO_CONFIG_DIR/protocol.json
}

function get-utxo-json {
    if [ -f "$CARDANO_KEYS_DIR/payment/base.addr" ]; then
        CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH \
        $CARDANO_BINARIES_DIR/cardano-cli query utxo \
            --address $(cat $CARDANO_KEYS_DIR/payment/base.addr) \
            --out-file=/dev/stdout \
            "${MAGIC[@]}"
    else
        echo -e "${BOLD}${WHITE_ON_RED}ERROR${NORMAL}: you have to create or restore wallet before!"
    fi
}

function get-utxo-pretty {
    if [ -f "$CARDANO_KEYS_DIR/payment/base.addr" ]; then
        echo ""
        cat $CARDANO_KEYS_DIR/payment/base.addr
        echo ""
        echo ""
        CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH \
        $CARDANO_BINARIES_DIR/cardano-cli query utxo \
        --address $(cat $CARDANO_KEYS_DIR/payment/base.addr) \
        "${MAGIC[@]}"
    else
        echo -e "${BOLD}${WHITE_ON_RED}ERROR${NORMAL}: you have to create or restore wallet before!"
    fi
}

function from-config {
    local PARAM_PATH=$1
    echo $(jq -r "$PARAM_PATH" "$CONFIG_FILE")   
}

function check-node-sync {
    if [ ! -f "$CARDANO_SOCKET_PATH" ]; then
        echo ""
    fi
}

function get-version-from-path {
    local MY_PATH=$1
    local MY_PREFIX=$2
    local PATH_WITHOUT_PREFIX
    local FIRST_SLASH_POSITION
    local VERSION=""

    if [ ! -z "$MY_PATH" ]; then
        PATH_WITHOUT_PREFIX=${MY_PATH//$MY_PREFIX\//}
        FIRST_SLASH_POSITION=$(awk -v a="$PATH_WITHOUT_PREFIX" 'BEGIN{print index(a, "/")}')
        VERSION=${PATH_WITHOUT_PREFIX:0:FIRST_SLASH_POSITION-1}        
    fi

    echo "$VERSION"
}


function rewriting-prompt {    
    if [[ -f "$1" ]]; then
        printf "${BOLD}${WHITE_ON_RED}Warning!${NORMAL} $2 Are you sure? (Y/N) "
        read answer
        case ${answer^^} in
            Y|YES)
                return 0
                ;;
            *)
                echo "Operation canceled."
                return 1
                ;;
        esac
    fi
}

function wrap-cli-command {
    local COMMAND=$1
    output=$("$COMMAND" "${@:2}" 2>&1)
    if echo "$output" | grep -q "does not exist ("; then
        echo -e "\e[1;41mERROR\e[1;m Can't connect to the Cardano node. Plese, check if it launched."
        echo ""
        exit 1
    else
        echo -e  "$output"
    fi    
}

function get-binary {
    local SF_NAME=$1        
    SUBPATH=$(echo $(from-config ".global.software.\"${SF_NAME}\"") | jq -r '.path')

    $CARDANO_BINARIES_DIR/$SF_NAME/$SUBPATH/
}

function build-arg-array {
    local param_name="$1"
    shift
    local values=("$@")
    local result=()

    for value in "${values[@]}"; do
        result+=( "$param_name" "$value" )
    done

    echo "${result[@]}"
}

function replace-placeholders {
    local STR_TO_REPLACE="$1"
    local VERSION_TO_REPLACE="$2"
    local NETWORK_NAME_TO_REPLACE="$3"
    STR_TO_REPLACE=$(echo "$STR_TO_REPLACE" | sed "s/#/${VERSION_TO_REPLACE}/g")
    STR_TO_REPLACE=$(echo "$STR_TO_REPLACE" | sed "s/%/${NETWORK_NAME_TO_REPLACE}/g")
    echo "$STR_TO_REPLACE"
}

function check-ip {
    local IP_LIST=($(hostname -I) "127.0.0.1")    
    local CURRENT_IP=$(from-config '.global.ip')

    if [[ -z "$CURRENT_IP" ]]; then
        echo "No IP is set. Please select a valid IP:"
    elif [[ ! " ${IP_LIST[@]} " =~ " ${CURRENT_IP} " ]]; then
        echo "Current IP: $CURRENT_IP is not valid. Please select a valid IP:"
    else
        return
    fi
    

    for i in "${!IP_LIST[@]}"; do
        echo "$((i+1)): ${IP_LIST[$i]}"
    done
    
    read -p "Enter the number of the desired IP: " IP_NUM
    

    if [[ $IP_NUM -ge 1 ]] && [[ $IP_NUM -le ${#IP_LIST[@]} ]]; then
        NEW_IP=${IP_LIST[$((IP_NUM-1))]}
        jq ".global.ip = \"$NEW_IP\"" conf.json > temp.json && mv temp.json conf.json
        echo "IP updated to: $NEW_IP"
    else
        echo "Invalid selection. Exiting."
        exit 1
    fi
}



function check-deployment-path {
   
    local CARDANO_DIR=$(from-config '.global."cardano-dir"')
    local DEFAULT_DIR="$(dirname "$(readlink -f "$0")")"


    if [[ -z "$CARDANO_DIR" || ! -d "$CARDANO_DIR" ]]; then

        echo "No software location directory chosen!"
        read -p "Please specify the path to it ($DEFAULT_DIR): " CARDANO_DIR
        

        CARDANO_DIR=${CARDANO_DIR:-$DEFAULT_DIR}
        

        jq --arg dir "$CARDANO_DIR" '.global."cardano-dir" = $dir' $CONFIG_FILE > temp.json && mv temp.json $CONFIG_FILE
    fi

    if [ ! -d "$CARDANO_DIR" ] || [ ! -w "$CARDANO_DIR" ]; then
      echo "Error: $CARDANO_DIR does not exist or is not writable;"
      echo "Please, set another path in the $CONFIG_FILE"
      exit 1
    fi
}

function run-check-sync {
    local VERBOSITY=${1:-"all"}
    local OUTPUT_MODE=""
    
    if [ $VERBOSITY == "silent" ];then
        OUTPUT_MODE="--out-file=/dev/null"
    fi
    
    CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH $CARDANO_BINARIES_DIR/cardano-cli query tip $OUTPUT_MODE ${MAGIC[@]}
}

function get-kes-period-info {
    CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH \
        $CARDANO_BINARIES_DIR/cardano-cli query kes-period-info \
        --op-cert-file $KES_KEYS/node.cert \
        --out-file=/dev/stderr \
        "${MAGIC[@]}" 1>/dev/null
}

function get-sf-version {
    local SF_NAME=$1
    local SF_GLOBAL_META=$(from-config ".global.software.\"${SF_NAME}\"")
    local SF_LOCAL_META=$(from-config ".networks.\"${NETWORK_NAME}\".\"${SF_NAME}\"")    
    
    if ! [ "$SF_META" == null ]; then
        local DESIRED_SF_VERSION=$(echo $SF_LOCAL_META | jq -r ".version")
        echo $DESIRED_SF_VERSION
    else
        echo -e "${BOLD}${WHITE_ON_RED}  ${NORMAL}"
        exit 1
    fi
    
}

