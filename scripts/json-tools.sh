function compare_json_recursive() {
    local JSON1_JSON=$1
    local JSON2_JSON=$2
    local SELECTOR=$3
    local CHANGES_BUFFER=$4
    
    local JSON1_VALUE
    local JSON2_VALUE
    local JSON_TYPE
    
    JSON_TYPE=$(echo $JSON2_JSON | jq -r 'type' 2>/dev/null)

    echo -n "*" >&2

    if [ "$JSON_TYPE" == "object" ] || [ "$JSON_TYPE" == "array" ]; then
        local JSON1_KEYS=""
        local JSON2_KEYS=""

        if [ "$(echo $JSON1_JSON | jq -r 'type' 2>/dev/null)" == "object" ] || [ "$(echo $JSON1_JSON | jq -r 'type' 2>/dev/null)" == "array" ]; then
            JSON1_KEYS=$(echo $JSON1_JSON | jq -r 'keys[]' 2>/dev/null)
        fi

        if [ "$JSON_TYPE" == "object" ] || [ "$JSON_TYPE" == "array" ]; then
            JSON2_KEYS=$(echo $JSON2_JSON | jq -r 'keys[]' 2>/dev/null)
        fi
        
        # Combine keys from both JSONs
        local ALL_KEYS=$(echo -e "$JSON1_KEYS\n$JSON2_KEYS" | sort | uniq)
        
        for KEY in $ALL_KEYS; do
            if [ "$JSON_TYPE" == "object" ]; then
                local KEY_ESCAPED="\"${KEY}\""
            elif [ "$JSON_TYPE" == "array" ]; then
                local KEY_ESCAPED="[$KEY]"
            fi

            JSON1_VALUE=$(echo $JSON1_JSON | jq ".$KEY_ESCAPED" 2>/dev/null)
            JSON2_VALUE=$(echo $JSON2_JSON | jq ".$KEY_ESCAPED" 2>/dev/null)

            echo -n "." >&2
            
            local VALUE_TYPE_JSON1=$(echo $JSON1_VALUE | jq -r 'type' 2>/dev/null)
            local VALUE_TYPE_JSON2=$(echo $JSON2_VALUE | jq -r 'type' 2>/dev/null)
            
            if [ "$VALUE_TYPE_JSON1" == "object" ] || [ "$VALUE_TYPE_JSON1" == "array" ] || [ "$VALUE_TYPE_JSON2" == "object" ] || [ "$VALUE_TYPE_JSON2" == "array" ]; then
                local TEMP_BUFFER
                TEMP_BUFFER=$(compare_json_recursive "$JSON1_VALUE" "$JSON2_VALUE" "$SELECTOR.$KEY_ESCAPED" "")
                if [ -n "$TEMP_BUFFER" ]; then
                    CHANGES_BUFFER+="${TEMP_BUFFER}\n"
                fi
            else
                if [ "$JSON1_VALUE" != "$JSON2_VALUE" ]; then
                    echo -n "!" >&2
                    if [ "$JSON1_VALUE" == "null" ] && [ "$VALUE_TYPE_JSON2" != "null" ]; then
                        # Key is only in JSON2
                        CHANGES_BUFFER+="+${SELECTOR}.${KEY_ESCAPED}%|#${JSON2_VALUE}\n"
                    elif [ "$JSON2_VALUE" == "null" ] && [ "$VALUE_TYPE_JSON1" != "null" ]; then
                        # Key is only in JSON1
                        CHANGES_BUFFER+="-${SELECTOR}.${KEY_ESCAPED}\n"
                    else
                        # Key is in both, but values are different
                        if [ "${JSON1_VALUE}" != '"auto"' ] && [ "${JSON1_VALUE}" != '""' ]; then
                            CHANGES_BUFFER+="^${SELECTOR}.${KEY_ESCAPED}%|#${JSON1_VALUE}||${JSON2_VALUE}\n"
                        fi
                    fi
                fi
            fi
        done
    else    
        JSON1_VALUE=$JSON1_JSON
        JSON2_VALUE=$JSON2_JSON        
        local VALUE_TYPE_JSON1=$(echo $JSON1_VALUE | jq -r 'type' 2>/dev/null)
        local VALUE_TYPE_JSON2=$(echo $JSON2_VALUE | jq -r 'type' 2>/dev/null)

        if [ "$JSON1_VALUE" != "$JSON2_VALUE" ]; then
            echo -n "!" >&2
            if [ "$JSON1_VALUE" == "null" ] && [ "$VALUE_TYPE_JSON2" != "null" ]; then
                # Key is only in JSON2
                CHANGES_BUFFER+="+${SELECTOR}%|#${JSON2_VALUE}\n"
            elif [ "$JSON2_VALUE" == "null" ] && [ "$VALUE_TYPE_JSON1" != "null" ]; then
                # Key is only in JSON1
                CHANGES_BUFFER+="-${SELECTOR}\n"
            else
                # Key is in both, but values are different
                CHANGES_BUFFER+="^${SELECTOR}%|#${JSON1_VALUE}||${JSON2_VALUE}\n"
            fi
        fi
    fi
    

    CHANGES_BUFFER=$(echo -e "$CHANGES_BUFFER" | sed '/^$/d')
    
    echo -e "$CHANGES_BUFFER"
}



function apply_diff() {
    local DIFF_TEXT="$1"
    local JSON_INPUT="$2"

    IFS=$'\n' read -d '' -r -a DIFF_LINES <<< "$DIFF_TEXT"


    local UPDATED_JSON="$JSON_INPUT"


    for DIFF_LINE in "${DIFF_LINES[@]}"; do
        local ACTION="${DIFF_LINE:0:1}"
        local JPATH="${DIFF_LINE:1}"
        local KEY_PATH="${JPATH%%"%|#"*}"
        local VALUE="${JPATH#*"%|#"*}"

        KEY_PATH=$(echo "$KEY_PATH" | sed 's/\.\[/[/g')

        case "$ACTION" in
            +)
                UPDATED_JSON=$(echo "$UPDATED_JSON" | jq "$KEY_PATH = $VALUE")
                ;;
            ^)
                NEW_VAL=${VALUE#*||}
                UPDATED_JSON=$(echo "$UPDATED_JSON" | jq "$KEY_PATH = $NEW_VAL")
                ;;
            -)
                UPDATED_JSON=$(echo "$UPDATED_JSON" | jq "del($KEY_PATH)")
                ;;
        esac
    done
    
    echo "$UPDATED_JSON"
}

function visualize_diff() {
    local DIFF_TEXT="$1"
    

    local ADD_MARKER="\e[32m●\e[0m"    
    local CHANGE_MARKER="\e[33m●\e[0m" 
    local REMOVE_MARKER="\e[31m●\e[0m" 


    IFS=$'\n' read -d '' -r -a DIFF_LINES <<< "$DIFF_TEXT"


    for DIFF_LINE in "${DIFF_LINES[@]}"; do
        local ACTION="${DIFF_LINE:0:1}"
        local JPATH="${DIFF_LINE:1}"
        local KEY_PATH="${JPATH%%"%|#"*}"
        local VALUE="${JPATH#*"%|#"*}"


        READABLE_PATH=$(echo "$KEY_PATH" | sed 's/\./\//g')
        READABLE_PATH=$(echo "$READABLE_PATH" | sed 's/\"//g')
        READABLE_PATH=$(echo "$READABLE_PATH" | sed 's/\[//g; s/\]//g')


        case "$ACTION" in
            +)
                echo -e "${ADD_MARKER} ${READABLE_PATH} was added with value <${VALUE}>"
                ;;
            ^)
                OLD_VAL=${VALUE%%||*}
                NEW_VAL=${VALUE#*||}
                echo -e "${CHANGE_MARKER} ${READABLE_PATH} was changed from <${OLD_VAL}> to <${NEW_VAL}>"
                ;;
            -)
                echo -e "${REMOVE_MARKER} ${READABLE_PATH} was removed"
                ;;
        esac
    done
}

function check_and_compare_json() {
    local OLD_DEF_JSON_FILE=$1
    local NEW_DEF_JSON_FILE=$2
    local OLD_USER_JSON_FILE=$3
    local NEW_USER_JSON_FILE=$4
    local MODE=${5:-loud}
    local FILE_NAME=$(basename "$OLD_DEF_JSON_FILE")

    if [ "$MODE" != "silent" ]; then
        echo ""
        echo "Checking $FILE_NAME"
    fi

    if [[ "$FILE_NAME" == *"-genesis.json" ]]; then
        if [ "$MODE" != "silent" ]; then
            echo "Genesis file accepted as is."
        fi
        cp "${NEW_DEF_JSON_FILE}" "${NEW_USER_JSON_FILE}"
        return 1 
    fi

    local OLD_DEF_JSON=$(jq -c '.' "$OLD_DEF_JSON_FILE")
    local NEW_DEF_JSON=$(jq -c '.' "$NEW_DEF_JSON_FILE")
    local OLD_USER_JSON=$(jq -c '.' "$OLD_USER_JSON_FILE")
    local NEW_USER_JSON=$(jq -c '.' "$NEW_USER_JSON_FILE")

    local OLD_DEF_HASH=$(echo "$OLD_DEF_JSON" | md5sum | awk '{ print $1 }')
    local NEW_DEF_HASH=$(echo "$NEW_DEF_JSON" | md5sum | awk '{ print $1 }')
    local OLD_USER_HASH=$(echo "$OLD_USER_JSON" | md5sum | awk '{ print $1 }')

    if [ "$OLD_DEF_HASH" == "$NEW_DEF_HASH" ]; then
        if [ "$MODE" != "silent" ]; then
            echo "No changes detected."
        fi
        return 1 
    fi

    echo "Changes detected. Proceeding with comparison."
    echo "Looking for changes in default files:"
    DEF_CHANGES=$(compare_json_recursive "$OLD_DEF_JSON" "$NEW_DEF_JSON" "" "")

    if [ -n "$DEF_CHANGES" ]; then
        echo ""
        echo "Global changes:"
        visualize_diff "$DEF_CHANGES"
        echo -n "applying..."
        NEW_USER_JSON=$(apply_diff "$DEF_CHANGES" "$NEW_USER_JSON")
        echo "done!"
    fi

    if [ "$OLD_DEF_HASH" != "$OLD_USER_HASH" ]; then
        echo "Looking for changes made by the user:"
        CUSTOM_CHANGES=$(compare_json_recursive "$OLD_DEF_JSON" "$OLD_USER_JSON" "" "")
        if [ -n "$CUSTOM_CHANGES" ]; then
            echo ""
            echo "User's customization:"
            visualize_diff "$CUSTOM_CHANGES"
            echo -n "applying..."
            NEW_USER_JSON=$(apply_diff "$CUSTOM_CHANGES" "$NEW_USER_JSON")
            echo "done!"
        fi
    fi
    echo "$NEW_USER_JSON" | jq '.' > tmp.json && mv tmp.json "$NEW_USER_JSON_FILE"

    return 0 
}


