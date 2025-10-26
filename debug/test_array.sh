#!/bin/bash

MAPPING_FILE="playcover-map.txt"

echo "=== Test 1: Direct file read ==="
declare -a mappings_array=()
while IFS=$'\t' read -r volume_name bundle_id display_name; do
    [[ -z "$volume_name" || -z "$bundle_id" ]] && continue
    mappings_array+=("${volume_name}|${bundle_id}|${display_name}")
    echo "Added: [$volume_name] [$bundle_id] [$display_name]"
done < "$MAPPING_FILE"

echo ""
echo "=== Array contents ==="
echo "Size: ${#mappings_array[@]}"
for ((i=0; i<${#mappings_array[@]}; i++)); do
    echo "[$i]: ${mappings_array[$i]}"
done
