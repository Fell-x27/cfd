    #!/bin/bash

check-gpg-is-ready() {
    local gpg_id="cfd-storage" 
    local keyring="$CARDANO_KEYS_DIR/.keyring"
    chmod 700 ~/.gnupg
    chown -R $(whoami):$(whoami) ~/.gnupg

    if ! gpg --list-keys "$gpg_id" &> /dev/null; then
        echo "GPG key '$gpg_id' not found. Creating a new GPG key..."
        gpg --pinentry-mode loopback --quick-gen-key "$gpg_id" default default 365000d
        if [ $? -ne 0 ]; then
            echo "Failed to create GPG key. Please check your GPG setup."
            exit 1
        else
            echo "GPG key '$gpg_id' successfully created."
        fi
    fi
}

check-pass-initialized() {
    local gpg_id="cfd-storage" 
    local keyring="$CARDANO_KEYS_DIR/.keyring"
    check-gpg-is-ready 
    if [ ! -d "$keyring" ]; then
        echo "The cfd-storage is not initialized. You need to set up secure storage."
        
        read -p "Do you want to initialize the cfd-storage now? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then            
            mkdir -p "$keyring"/$gpg_id
        else
            echo "Initialization aborted. Exiting."
            exit 1
        fi
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

function show-keys {
    check-pass-initialized    
    if [ -f "$2" ] && [ "$(cat $2)" == "hidden" ]; then
        local content=$(read-from-pass "$1")
        if [ -n "$content" ]; then
            echo "$content" > "$2"
        fi
    fi
}

function hide-keys {
    check-pass-initialized
    content="$(cat $2)"
    if [ -f "$2" ] && [ "$content" != "hidden" ]; then          
        store-in-pass "$1" "$content"
        echo "hidden" > "$2"
    fi
}

