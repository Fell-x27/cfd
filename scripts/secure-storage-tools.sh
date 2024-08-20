    #!/bin/bash

check-gpg-is-ready() {
    local gpg_id="cfd-storage" 
    local keyring="$CARDANO_KEYS_DIR/.keyring"
    chmod 700 ~/.gnupg
    chown -R $(whoami):$(whoami) ~/.gnupg

    if ! gpg --list-keys "$gpg_id" &> /dev/null; then
        echo ""
        echo "GPG key '$gpg_id' not found. Creating a new GPG key..."
        echo ""
        gpg --pinentry-mode loopback --quick-gen-key "$gpg_id" default default 365000d
        if [ $? -ne 0 ]; then
            echo "Failed to create GPG key. Please check your GPG setup."
            exit 1
        else
            echo "GPG key '$gpg_id' successfully created."
        fi
    fi
    #gpg --yes --batch  --pinentry-mode loopback --delete-secret-key 537F315E1901B9F22BA663C5B795B1D32A6C38FC
    #gpg --yes --batch  --pinentry-mode loopback --delete-key 537F315E1901B9F22BA663C5B795B1D32A6C38FC
}

check-pass-initialized() {
    local gpg_id="cfd-storage" 
    local keyring="$CARDANO_KEYS_DIR/.keyring"

    check-gpg-is-ready

    if [ ! -d "$keyring/$gpg_id" ]; then
        echo "The cfd-storage is not initialized. Setting up secure storage..."
        mkdir -p "$keyring/$gpg_id"
        echo "Secure storage initialized at $keyring/$gpg_id."
    fi
}


store-in-pass() {
    local gpg_id="cfd-storage" 
    local keyring="$CARDANO_KEYS_DIR/.keyring" 
    local path="$keyring/$gpg_id/$1.gpg"
    local data="$2"
    echo "$data" | gpg --encrypt --armor --recipient "$gpg_id" > "$path"
}

read-from-pass() {
    local gpg_id="cfd-storage" 
    local keyring="$CARDANO_KEYS_DIR/.keyring"
    local path="$keyring/$gpg_id/$1.gpg"   
    if [ -f "$path" ]; then        
        gpg --quiet --pinentry-mode loopback --decrypt "$path" 2>/dev/null
    else        
        echo ""
    fi
}

function show-key {
    check-pass-initialized

    local filepath="$1"
    local key_name=$(basename "$filepath")

    if [ -f "$filepath" ] && [ "$(cat "$filepath")" == "hidden" ]; then
        local content=$(read-from-pass "$key_name")
        if [ -n "$content" ]; then
            echo "$content" > "$filepath"
        fi
    fi
}


function hide-key {
    check-pass-initialized

    local filepath="$1"
    local key_name=$(basename "$filepath")

    if [ -f "$filepath" ]; then
        local content="$(cat "$filepath")"
        if [ "$content" != "hidden" ]; then
            store-in-pass "$key_name" "$content"
            echo "hidden" > "$filepath"
        fi
    fi
}

