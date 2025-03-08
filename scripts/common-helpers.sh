#!/bin/bash

# ANSI escape codes
BOLD="\033[1m"
NORMAL="\033[0m"
UNDERLINE="\033[4m"

BLACK="\033[30m"
WHITE="\033[37m"
GREEN="\033[32m"
RED="\033[31m"

ON_YELLOW="\033[43m"
ON_LIGHT_GRAY="\033[47m"
ON_RED="\033[41m"
ON_BLACK="\033[40m"

BLACK_ON_YELLOW="${BLACK}${ON_YELLOW}"
BLACK_ON_LIGHT_GRAY="${BLACK}${ON_LIGHT_GRAY}"
WHITE_ON_RED="${WHITE}${ON_RED}"
GREEN_ON_BLACK="${GREEN}${ON_BLACK}"


spin() {
  local -r CHARS="/-\|"

  while :; do
    for (( I=0; I<${#CHARS}; I++ )); do
      sleep 0.1
      echo -ne "${CHARS:$I:1}" "\r"
    done
  done
}


function check-db-sync-state {
    local PGPASS_FILE=$1
    local PORT=$(cut -d ':' -f 2 $PGPASS_FILE)

    if pg_isready -p $PORT >/dev/null 2>&1; then
        echo "Port $PORT is active. PostgreSQL is running." 1>&2
    else
        echo -e "${BOLD}${WHITE_ON_RED} ERROR: ${NORMAL} Port $PORT is not active. PostgreSQL might not be installed or running." 1>&2
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
        echo -e "${BOLD}${WHITE_ON_RED}ERROR${NORMAL}: you have to create or restore wallet before!" 1>&2
    fi
}

function get-utxo-pretty {
    if [ -f "$CARDANO_KEYS_DIR/payment/base.addr" ]; then
        echo "" 1>&2
        cat $CARDANO_KEYS_DIR/payment/base.addr
        echo "" 1>&2
        echo "" 1>&2
        CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH \
        $CARDANO_BINARIES_DIR/cardano-cli query utxo \
        --address $(cat $CARDANO_KEYS_DIR/payment/base.addr) \
        "${MAGIC[@]}"
    else
        echo -e "${BOLD}${WHITE_ON_RED}ERROR${NORMAL}: you have to create or restore wallet before!" 1>&2
    fi
}

inspect_cardano_address() {
    local address_file="$CARDANO_KEYS_DIR/payment/base.addr"

    if [ -f "$address_file" ]; then
        local address
        address=$(<"$address_file")  # Читаем содержимое файла в переменную

        if [[ -z "$address" ]]; then
            echo "No address in file"
            return 1
        fi
        echo ""
        echo "Your address:"
        echo -e "${BOLD}$address${NORMAL}"
        echo "$address" | "$CARDANO_BINARIES_DIR/cardano-address" address inspect
    else
        echo -e "${BOLD}${WHITE_ON_RED}ERROR${NORMAL}: you have to create or restore wallet before!" 1>&2
        return 1
    fi
}

function from-config {
    local PARAM_PATH=$1
    echo $(jq -r "$PARAM_PATH" "$CONFIG_FILE")   
}

function check-node-sync {
    if [ ! -f "$CARDANO_SOCKET_PATH" ]; then
        echo "" 1>&2
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

function wrap-cli-command {
    local COMMAND=$1
    shift
    local args=("$@")
    local output
    local error_output

    local tmp_error_file
    tmp_error_file=$(mktemp)

    {
        output=$("$COMMAND" "${args[@]}" 2> "$tmp_error_file")
    }

    error_output=$(cat "$tmp_error_file")
    rm -f "$tmp_error_file"

    if [[ -n "$error_output" ]]; then
        if echo "$error_output" | grep -q "cardano-cli: Network.Socket.connect: <socket:"; then
            echo -e "\e[1;41mERROR\e[1;m Can't connect to the Cardano node. Please, check if it launched." 1>&2
        else
            echo "$error_output" 1>&2
        fi
        return 1
    fi

    if [[ " ${args[*]} " == *" transaction submit "* ]] && echo "$output" | grep -q "Transaction successfully submitted"; then
        local tx_file=""
        for ((i = 0; i < ${#args[@]}; i++)); do
            if [[ "${args[i]}" == "--tx-file" ]]; then
                tx_file="${args[i+1]}"
                break
            fi
        done

        if [[ -n "$tx_file" ]]; then
            local txid_output
            txid_output=$(cli latest transaction txid --tx-file "$tx_file" 2>/dev/null)
            echo -e "$output"
            echo -e "Transaction ID: $txid_output"
        fi
    elif [ -n "$output" ]; then
        echo -e "$output"
    fi

    return 0
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

function get-package-manager() {
  if command -v apt &> /dev/null; then
    echo "apt"
  elif command -v yum &> /dev/null; then
    echo "yum"
  elif command -v dnf &> /dev/null; then
    echo "dnf"
  elif command -v pacman &> /dev/null; then
    echo "pacman"
  elif command -v zypper &> /dev/null; then
    echo "zypper"
  elif command -v emerge &> /dev/null; then
    echo "emerge"
  else
    echo "unknown"
  fi
}


function check-dependencies() {
    local missing_packages=()
    local package_manager=$(get-package-manager)

    for cmd in "$@"; do
        if ! command -v $cmd &> /dev/null; then
            if [ "$package_manager" = "apt" ]; then
                # Проверка установки через dpkg-query
                if ! dpkg-query -W -f='${Status}' $cmd 2>/dev/null | grep -q "install ok installed"; then
                    missing_packages+=($cmd)
                fi
            elif [ "$package_manager" = "yum" ]; then
                if ! rpm -q $cmd &> /dev/null; then
                    missing_packages+=($cmd)
                fi
            elif [ "$package_manager" = "dnf" ]; then
                if ! dnf list installed $cmd &> /dev/null; then
                    missing_packages+=($cmd)
                fi
            elif [ "$package_manager" = "pacman" ]; then
                if ! pacman -Q $cmd &> /dev/null; then
                    missing_packages+=($cmd)
                fi
            elif [ "$package_manager" = "zypper" ]; then
                if ! zypper search --installed-only $cmd &> /dev/null; then
                    missing_packages+=($cmd)
                fi
            elif [ "$package_manager" = "emerge" ]; then
                if ! equery list $cmd &> /dev/null; then
                    missing_packages+=($cmd)
                fi
            else
                echo "Error: Unsupported package manager." 1>&2
                echo "You must install all the required packages manually." 1>&2
                exit 1
            fi
        fi
    done

    if [ ${#missing_packages[@]} -ne 0 ]; then
        echo "" 1>&2
        echo "Error: The following packages are not installed: ${missing_packages[@]}" 1>&2

        if [ "$package_manager" = "unknown" ]; then
            echo "Error: Unable to determine the package manager for this system." 1>&2
            echo "You must install all the required packages manually." 1>&2
            exit 1
        fi

        case $package_manager in
            apt)
                install_command="sudo apt update && sudo apt install -y ${missing_packages[@]}"
                ;;
            yum)
                install_command="sudo yum install -y ${missing_packages[@]}"
                ;;
            dnf)
                install_command="sudo dnf install -y ${missing_packages[@]}"
                ;;
            pacman)
                install_command="sudo pacman -S --noconfirm ${missing_packages[@]}"
                ;;
            zypper)
                install_command="sudo zypper install -y ${missing_packages[@]}"
                ;;
            emerge)
                install_command="sudo emerge ${missing_packages[@]}"
                ;;
            *)
                echo "Error: Unsupported package manager." 1>&2
                echo "You must install all the required packages manually." 1>&2
                exit 1
                ;;
        esac

        echo -e "The following command will be executed to install the missing packages:\n    \033[1m$install_command\033[0m"
        if ! are-you-sure-dialog "Do you want to proceed with the installation?" "y"; then
            echo "Aborted."; 1>&2
            exit 1
        else
            eval "$install_command"
        fi
    fi
}





function check-ip {
    local IP_LIST=($(hostname -I) "127.0.0.1")    
    local CURRENT_IP=$(from-config '.global.ip')

    if [[ -z "$CURRENT_IP" ]]; then
        echo ""
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
        local NEW_IP=${IP_LIST[$((IP_NUM-1))]}
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
        echo ""
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
    
    CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH $CARDANO_BINARIES_DIR/cardano-cli query tip $OUTPUT_MODE "${MAGIC[@]}"
}

function get-kes-period-info {
    local tmp_file
    tmp_file=$(mktemp)

    CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH \
        $CARDANO_BINARIES_DIR/cardano-cli query kes-period-info \
        --op-cert-file "$KES_KEYS/node.cert" \
        --out-file="$tmp_file" \
        "${MAGIC[@]}" 1>/dev/null

    local json_output
    json_output=$(<"$tmp_file")

    rm -f "$tmp_file"

    echo "$json_output"
}

function get-sf-version {
    local SF_NAME="$1"
    local SF_GLOBAL_META=$(from-config ".global.software.\"${SF_NAME}\"")
    local SF_LOCAL_META=$(from-config ".networks.\"${NETWORK_NAME}\".software.\"${SF_NAME}\"")    
    
    if ! [ "$SF_LOCAL_META" == null ]; then
        local DESIRED_SF_VERSION=$(echo $SF_LOCAL_META | jq -r ".version")
        echo $DESIRED_SF_VERSION
    else
        echo -e "${BOLD}${WHITE_ON_RED} ERROR ${NORMAL}: unknown software - $SF_NAME"
    fi
    
}

function validate-node-sync {
    local LIMIT=${1:-"100"}
    wrap-cli-command run-check-sync "silent"
    SYNC_STATE=$(run-check-sync)  
    SYNC_STATE=$(echo "$SYNC_STATE" | jq -r '.syncProgress')    
    if (( $(echo "$SYNC_STATE < $LIMIT" | bc -l) )); then
        echo -e "${BOLD}${BLACK_ON_YELLOW}WARNING${NORMAL}: The node is not synced yet, please wait."
        echo "Current sync level: $SYNC_STATE%"
        exit
    fi
}


function get-current-slot {
    CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH $CARDANO_BINARIES_DIR/cardano-cli \
     query \
     tip \
     "${MAGIC[@]}" | jq .slot
}

function get-current-epoch {
    CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH $CARDANO_BINARIES_DIR/cardano-cli \
     query \
     tip \
     "${MAGIC[@]}" | jq .epoch
}

function is-tx-in-mempool {
    TX_ID=$1
    CARDANO_NODE_SOCKET_PATH=$CARDANO_SOCKET_PATH $CARDANO_BINARIES_DIR/cardano-cli \
    query \
    tx-mempool \
    tx-exists $TX_ID \
    "${MAGIC[@]}"
}

