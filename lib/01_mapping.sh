#!/bin/zsh
#######################################################
# PlayCover Manager - Mapping File Management Module
# マッピングファイルの読み書き、ロック管理
#######################################################

#######################################################
# Mapping Lock Functions
#######################################################

# Acquire lock for mapping file operations
# Returns: 0 on success, 1 on timeout
acquire_mapping_lock() {
    local timeout=10
    local elapsed=0
    
    while ! /bin/mkdir "$MAPPING_LOCK_FILE" 2>/dev/null; do
        /bin/sleep 0.1
        elapsed=$((elapsed + 1))
        
        if [[ $elapsed -ge $((timeout * 10)) ]]; then
            print_error "マッピングファイルのロック取得に失敗しました（タイムアウト）"
            return 1
        fi
    done
    
    return 0
}

# Release lock for mapping file operations
release_mapping_lock() {
    rmdir "$MAPPING_LOCK_FILE" 2>/dev/null || true
}

#######################################################
# Mapping File Operations
#######################################################

# Check if mapping file exists, create if not
# Returns: 0 if exists, 1 if not found or created
check_mapping_file() {
    # Ensure data directory exists
    if [[ ! -d "$DATA_DIR" ]]; then
        print_info "データディレクトリを作成します: $DATA_DIR"
        /bin/mkdir -p "$DATA_DIR"
        
        if [[ ! -d "$DATA_DIR" ]]; then
            print_error "データディレクトリの作成に失敗しました"
            return 1
        fi
    fi
    
    # Ensure mapping file exists
    if [[ ! -f "$MAPPING_FILE" ]]; then
        print_warning "マッピングファイルが見つかりません"
        print_info "空のマッピングファイルを作成します"
        touch "$MAPPING_FILE"
        
        if [[ ! -f "$MAPPING_FILE" ]]; then
            print_error "マッピングファイルの作成に失敗しました"
            return 1
        fi
        
        echo ""
        return 1
    fi
    
    return 0
}

# Read all mappings from file
# Output: TSV format (volume_name, bundle_id, display_name)
# Returns: 0 on success, 1 if file not found
read_mappings() {
    if [[ ! -f "$MAPPING_FILE" ]]; then
        return 1
    fi
    
    # Return mappings via stdout (caller captures with command substitution)
    /bin/cat "$MAPPING_FILE"
}

# Remove duplicate entries from mapping file
# Keeps first occurrence of each volume_name
# Returns: 0 on success
deduplicate_mappings() {
    if [[ ! -f "$MAPPING_FILE" ]]; then
        return 0
    fi
    
    acquire_mapping_lock || return 1
    
    local temp_file="${MAPPING_FILE}.dedup"
    local original_count=$(wc -l < "$MAPPING_FILE" 2>/dev/null || echo "0")
    
    # Remove duplicates based on volume_name (first column)
    # Keep first occurrence, remove subsequent duplicates
    /usr/bin/awk -F'\t' '!seen[$1]++' "$MAPPING_FILE" > "$temp_file"
    
    local new_count=$(wc -l < "$temp_file" 2>/dev/null || echo "0")
    local removed=$((original_count - new_count))
    
    if [[ $removed -gt 0 ]]; then
        /bin/mv "$temp_file" "$MAPPING_FILE"
        print_info "重複エントリを ${removed} 件削除しました"
    else
        /bin/rm -f "$temp_file"
    fi
    
    release_mapping_lock
    return 0
}

#######################################################
# Mapping CRUD Operations
#######################################################

# Add new mapping entry
# Args: volume_name, bundle_id, display_name
# Returns: 0 on success, 1 on lock failure
add_mapping() {
    local volume_name=$1
    local bundle_id=$2
    local display_name=$3
    
    acquire_mapping_lock || return 1
    
    # Check if mapping already exists (by volume_name OR bundle_id)
    if /usr/bin/grep -q "^${volume_name}"$'\t' "$MAPPING_FILE" 2>/dev/null; then
        print_warning "ボリューム名が既に存在します: $volume_name"
        release_mapping_lock
        return 0
    fi
    
    if /usr/bin/grep -q $'\t'"${bundle_id}"$'\t' "$MAPPING_FILE" 2>/dev/null; then
        print_warning "Bundle IDが既に存在します: $bundle_id"
        release_mapping_lock
        return 0
    fi
    
    # Add new mapping (4th column: last_launched timestamp, initially 0)
    echo "${volume_name}"$'\t'"${bundle_id}"$'\t'"${display_name}"$'\t'"0" >> "$MAPPING_FILE"
    
    release_mapping_lock
    print_success "マッピングを追加しました: $display_name"
    
    return 0
}

# Remove mapping entry by bundle_id
# Args: bundle_id
# Returns: 0 on success, 1 on lock failure
remove_mapping() {
    local bundle_id=$1
    
    acquire_mapping_lock || return 1
    
    # Create temporary file
    local temp_file="${MAPPING_FILE}.tmp"
    
    # Remove matching line
    /usr/bin/grep -v $'\t'"${bundle_id}"$'\t' "$MAPPING_FILE" > "$temp_file" 2>/dev/null || true
    
    # Replace original file
    /bin/mv "$temp_file" "$MAPPING_FILE"
    
    release_mapping_lock
    
    return 0
}

# Update existing mapping (remove old, add new)
# Args: volume_name, bundle_id, display_name
# Returns: 0 on success
update_mapping() {
    local volume_name=$1
    local bundle_id=$2
    local display_name=$3
    
    # Remove old mapping if exists, then add new one
    remove_mapping "$bundle_id"
    add_mapping "$volume_name" "$bundle_id" "$display_name"
}

#######################################################
# Recent Apps Tracking Functions
#######################################################

# Record app usage (timestamp + bundle_id + app_name)
# Args: bundle_id, app_name
# Returns: 0 on success
# Record app launch (update last_launched timestamp in mapping file)
# Args: bundle_id
# Returns: 0 on success
record_recent_app() {
    local bundle_id=$1
    local timestamp=$(date +%s)
    
    acquire_mapping_lock || return 1
    
    # Update last_launched timestamp for this bundle_id
    # Format: volume_name<TAB>bundle_id<TAB>display_name<TAB>last_launched
    local temp_file="${MAPPING_FILE}.tmp"
    
    while IFS=$'\t' read -r volume_name stored_bundle_id display_name last_launched; do
        if [[ "$stored_bundle_id" == "$bundle_id" ]]; then
            # Update timestamp for this app
            echo "${volume_name}"$'\t'"${stored_bundle_id}"$'\t'"${display_name}"$'\t'"${timestamp}"
        else
            # Keep other entries unchanged (preserve existing timestamp or 0)
            if [[ -z "$last_launched" ]]; then
                last_launched="0"
            fi
            echo "${volume_name}"$'\t'"${stored_bundle_id}"$'\t'"${display_name}"$'\t'"${last_launched}"
        fi
    done < "$MAPPING_FILE" > "$temp_file"
    
    /bin/mv "$temp_file" "$MAPPING_FILE"
    
    release_mapping_lock
    return 0
}

# Get most recently launched app (single app only)
# Output: bundle_id of most recent app
# Returns: 0 if found, 1 if none
get_recent_app() {
    if [[ ! -f "$MAPPING_FILE" ]]; then
        return 1
    fi
    
    # Find entry with largest last_launched timestamp
    local max_timestamp=0
    local recent_bundle_id=""
    
    while IFS=$'\t' read -r volume_name bundle_id display_name last_launched; do
        # Skip if no timestamp or timestamp is 0
        if [[ -z "$last_launched" ]] || [[ "$last_launched" == "0" ]]; then
            continue
        fi
        
        if [[ "$last_launched" -gt "$max_timestamp" ]]; then
            max_timestamp=$last_launched
            recent_bundle_id=$bundle_id
        fi
    done < "$MAPPING_FILE"
    
    if [[ -n "$recent_bundle_id" ]]; then
        echo "$recent_bundle_id"
        return 0
    else
        return 1
    fi
}

# Check if specific app is the most recently launched
# Args: bundle_id
# Returns: 0 if this is the most recent, 1 if not
is_recent_app() {
    local bundle_id=$1
    local recent=$(get_recent_app 2>/dev/null)
    
    if [[ "$recent" == "$bundle_id" ]]; then
        return 0
    else
        return 1
    fi
}
