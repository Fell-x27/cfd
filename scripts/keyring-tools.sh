#!/bin/bash

check-gpg-is-ready() {
    local gpg_id="cfd-storage"
    local keyring="$CARDANO_KEYS_DIR/.keyring"
    mkdir -p ~/.gnupg
    chmod 700 ~/.gnupg
    chown -R $(whoami):$(whoami) ~/.gnupg

    if ! gpg --list-keys "$gpg_id" &> /dev/null; then
        echo ""
        echo "GPG key '$gpg_id' not found. Creating a new GPG key..."


        local attempts=3

        for (( i=0; i<$attempts; i++ )); do
            echo ""
            read -s -p "Enter passphrase for new GPG key: " passphrase
            echo
            read -s -p "Confirm passphrase: " passphrase_confirm
            echo
            if [ "$passphrase" != "$passphrase_confirm" ]; then
                echo ""
                echo "Passphrases do not match. Please try again."
                if [ $i -eq $((attempts-1)) ]; then
                    echo ""
                    echo "Failed to create GPG key after $attempts attempts. Exiting."
                    exit 1
                fi
            else
                break
            fi
        done

        echo "Key-Type: RSA
Key-Length: 3072
Subkey-Type: RSA
Name-Real: $gpg_id
Expire-Date: 0
Passphrase: $passphrase
%commit" | gpg --batch --gen-key --pinentry-mode loopback

        if [ $? -ne 0 ]; then
            echo ""
            echo "Failed to create GPG key. Please check your GPG setup."
            exit 1
        else
            echo ""
            echo "GPG key '$gpg_id' successfully created."
        fi
    fi
}


check-keyring-initialized() {
    local gpg_id="cfd-storage"
    local keyring="$CARDANO_KEYS_DIR/.keyring"

    if [ ! -d "$keyring/$gpg_id" ]; then
        echo "Setting up secure storage..."
        mkdir -p "$keyring/$gpg_id"
        echo "Secure storage initialized at $keyring/$gpg_id."
    fi
}

derive-missed-public-keys() {
    local keys_output=$(list-keys)
    local CCLI=$CARDANO_BINARIES_DIR/cardano-cli
    while IFS= read -r line; do
        if [[ "$line" =~ \.skey$ ]]; then
            local skey_path=$(echo "$line" | awk '{print $NF}')
            local vkey_path="${skey_path%.skey}.vkey"
            if [ ! -f "$vkey_path" ]; then
                echo "Deriving public key for $skey_path"
                
                trap 'hide-key "$skey_path"' EXIT
                reveal-key "$skey_path"
                $CCLI key verification-key \
                    --signing-key-file "$skey_path" \
                    --verification-key-file "$vkey_path"

                $CCLI key non-extended-key \
                    --extended-verification-key-file "$vkey_path" \
                    --verification-key-file "$vkey_path"
                hide-key "$skey_path"
                trap - EXIT
                chmod 600 "$vkey_path"
                chmod 600 "$skey_path"
            fi
        fi
    done <<< "$keys_output"
}


derive-missed-addresses() {
    local dir="$CARDANO_KEYS_DIR/payment"
    local cli="$CARDANO_BINARIES_DIR/cardano-cli"

    if [ ! -f "$dir/stake.addr" ]; then
        if [ -f "$dir/stake.vkey" ]; then
            echo "Creating stake.addr..."
            $cli stake-address build \
                --stake-verification-key-file "$dir/stake.vkey" \
                --out-file "$dir/stake.addr" \
                "${MAGIC[@]}"
        fi
    fi

    if [ ! -f "$dir/base.addr" ]; then
        if [ -f "$dir/payment.vkey" ] && [ -f "$dir/stake.vkey" ]; then
            echo "Creating base.addr..."
            $cli address build \
                --payment-verification-key-file "$dir/payment.vkey" \
                --stake-verification-key-file "$dir/stake.vkey" \
                --out-file "$dir/base.addr" \
                "${MAGIC[@]}"
        fi
    fi
}


store-in-keyring() {
    local gpg_id="cfd-storage"
    local keyring="$CARDANO_KEYS_DIR/.keyring"
    local path="$keyring/$gpg_id/$1.gpg"
    local data="$2"
    echo "$data" | gpg --quiet --encrypt --armor --recipient "$gpg_id" > "$path"
}

read-from-keyring() {
    local gpg_id="cfd-storage"
    local keyring="$CARDANO_KEYS_DIR/.keyring"
    local path="$keyring/$gpg_id/$1.gpg"
    if [ -f "$path" ]; then
        gpg --quiet --pinentry-mode loopback --decrypt "$path"
    else
        echo ""
    fi
}

function reveal-key {
    local filepath="$1"
    local key_name=$(basename "$filepath")

    if [ -f "$filepath" ] && [ "$(cat "$filepath")" == "hidden" ]; then
        local content
        if ! content=$(read-from-keyring "$key_name"); then
            echo "Failed to reveal the key. Exiting."
            exit 1
        fi

        if [ -n "$content" ]; then
            echo "$content" > "$filepath"
        fi
    fi
}


function hide-key {

    local filepath="$1"
    local key_name=$(basename "$filepath")

    if [ -f "$filepath" ]; then
        local content="$(cat "$filepath")"
        if [ "$content" != "hidden" ]; then
            if ! store-in-keyring "$key_name" "$content"; then
                echo "Failed to hide the key. Exiting."
                exit 1
            fi
            echo "hidden" > "$filepath"
        fi
    fi
}


function list-keys {
    local files=($(find "$CARDANO_KEYS_DIR" -type f \( -name "*.skey" -o -name "*.vkey" \) | sort))
    local count=1

    for file in "${files[@]}"; do
        local filename=$(basename "$file")
        local extension="${filename##*.}"
        local filepath=$(realpath "$file")

        local formatted_count=$(printf "%3d. " "$count")

        if [[ "$extension" == "skey" ]]; then
            if [[ "$filename" == "kes.skey" || "$filename" == "vrf.skey" ]]; then
                local status="\e[33m●\e[0m online "
            else
                local content=$(cat "$file")
                if [[ "$content" == "hidden" ]]; then
                    local status="\e[32m●\e[0m hidden "
                else
                    local status="\e[31m●\e[0m exposed"
                fi
            fi
        elif [[ "$extension" == "vkey" ]]; then
            local status="\e[33m●\e[0m public "
        fi

        echo -e "$formatted_count$status $filename $filepath"
        count=$((count + 1))
    done
}



function reveal-keys {
    local keys_output=$(list-keys)
    local hidden_keys=()
    local index=1

    while IFS= read -r line; do
        if [[ "$line" =~ " hidden  " ]]; then
            local stripped_line=$(echo "$line" | sed 's/^[0-9]\+\.\s*//')
            hidden_keys+=("$((index)). $stripped_line")
            index=$index+1
        fi
    done <<< "$keys_output"

    if [ ${#hidden_keys[@]} -eq 0 ]; then
        echo "No hidden keys found."
        return
    fi

    echo ""
    echo "Found hidden keys:"
    printf "%s\n" "${hidden_keys[@]}"
    echo ""

    read -e -p "Enter the numbers of the keys to reveal (separated by spaces), or press Enter to reveal all: " selected_keys

    local keys_to_process=()
    declare -A seen

    if [ -n "$selected_keys" ]; then
        echo ""
        for num in $selected_keys; do
            if [[ "$num" =~ ^[0-9]+$ ]] && ((num >= 1 && num <= ${#hidden_keys[@]})); then
                if [ -z "${seen[$num]}" ]; then
                    keys_to_process+=("${hidden_keys[$((num-1))]}")
                    seen[$num]=1
                fi
            else
                echo "Invalid selection: [$num], ignored."
            fi
        done
    else
        keys_to_process=("${hidden_keys[@]}")
    fi

    echo ""
    echo "Selected keys:"
    printf "%s\n" "${keys_to_process[@]}"
    echo ""

    echo "WARNING: Revealing keys will expose them until they are manually hidden again. CFD will automatically hide them during interaction, but until then they will be vulnerable."
    if ! are-you-sure-dialog; then            
        echo "Aborted.";
        exit 1
    fi

    for key_line in "${keys_to_process[@]}"; do
        local key_path=$(echo "$key_line" | awk '{print $NF}')
        reveal-key "$key_path"
    done

    echo "Done!"
}

function hide-keys {
    local keys_output=$(list-keys)
    local revealed_keys=()
    local index=1

    while IFS= read -r line; do
        if [[ "$line" =~ " exposed " ]]; then
            local stripped_line=$(echo "$line" | sed 's/^[0-9]\+\.\s*//')
            revealed_keys+=("$((index)). $stripped_line")
            index=$((index+1))
        fi
    done <<< "$keys_output"

    if [ ${#revealed_keys[@]} -eq 0 ]; then
        echo "No exposed keys found."
        return
    fi

    echo ""
    echo "Found exposed keys:"
    printf "%s\n" "${revealed_keys[@]}"
    echo ""

    read -e -p "Enter the numbers of the keys to hide (separated by spaces), or press Enter to hide all: " selected_keys

    local keys_to_process=()
    declare -A seen

    if [ -n "$selected_keys" ]; then
        echo ""
        for num in $selected_keys; do
            if [[ "$num" =~ ^[0-9]+$ ]] && ((num >= 1 && num <= ${#revealed_keys[@]})); then
                if [ -z "${seen[$num]}" ]; then
                    keys_to_process+=("${revealed_keys[$((num-1))]}")
                    seen[$num]=1
                fi
            else
                echo "Invalid selection: [$num], ignored."
            fi
        done
    else
        keys_to_process=("${revealed_keys[@]}")
    fi

    echo ""
    echo "Selected keys:"
    printf "%s\n" "${keys_to_process[@]}"
    echo ""

    echo "WARNING: Hiding these keys will make them inaccessible to scripts and applications other than CFD until they are revealed again."
    if ! are-you-sure-dialog; then            
        echo "Aborted.";
        exit 1
    fi

    for key_line in "${keys_to_process[@]}"; do
        local key_path=$(echo "$key_line" | awk '{print $NF}')
        hide-key "$key_path"
    done

    echo "Done!"
}

function export-keys {

    local keys_output=$(list-keys)
    local keys=()
    local hidden_present=false

    while IFS= read -r line; do
        if [[ "$line" =~ ^([0-9]+)\. ]]; then
            keys+=("$line")
            if [[ "$line" =~ "hidden" ]]; then
                hidden_present=true
            fi
        fi
    done <<< "$keys_output"

    echo ""
    echo "Known keys:"
    echo "$keys_output"
    echo ""

    read -e -p "Enter the numbers of the keys to export (separated by spaces), or press Enter to export all: " selected_keys

    local reveal_warning=false
    local keys_to_process=()

    echo ""
    if [ -n "$selected_keys" ]; then
        for num in $selected_keys; do
            if [[ "$num" =~ ^[0-9]+$ ]] && ((num >= 1 && num <= ${#keys[@]})); then
                if [ -z "${seen[$num]}" ]; then
                    keys_to_process+=("${keys[$((num-1))]}")
                    seen[$num]=1
                fi
            else
                echo "Invalid selection: [$num], ignored;"
            fi
        done
    else
        keys_to_process=("${keys[@]}")
    fi

    echo ""
    echo "Selected keys:"
    printf "%s\n" "${keys_to_process[@]}"

    for key_line in "${keys_to_process[@]}"; do
        if [[ "$key_line" =~ "hidden" ]]; then
            reveal_warning=true
            break
        fi
    done

    if [ "$reveal_warning" = true ]; then
        echo ""
        echo "WARNING: Hidden keys will be exported in an unprotected, revealed state. Ensure that you handle them securely."
        if ! are-you-sure-dialog; then            
            echo "Aborted.";
            exit 1
        fi
    fi

    echo ""
    read -e -p "Enter the directory to export the keys to [$CARDANO_DIR]: " export_dir
    export_dir=${export_dir:-$CARDANO_DIR}

    local temp_dir=$(mktemp -d)

    local keys_to_export=()
    for key_line in "${keys_to_process[@]}"; do
        local key_path=$(echo "$key_line" | awk '{print $NF}')
        local key_name=$(basename "$key_path")
        keys_to_export+=("$key_name")
        cp "$key_path" "$temp_dir/$key_name"
        if [[ "$key_line" =~ \.skey ]]; then
            reveal-key "$temp_dir/$key_name"
        fi
    done

    tar -czf "$export_dir/cardano_keys.tar.gz" -C "$temp_dir" "${keys_to_export[@]}"

    for key_name in "${keys_to_export[@]}"; do
        if [[ "$key_name" =~ \.skey ]]; then
            hide-key "$temp_dir/$key_name"
        fi
    done

    rm -rf "$temp_dir"
    echo ""
    echo "Export completed. The keys archive is located at $export_dir/cardano_keys.tar.gz"
}


