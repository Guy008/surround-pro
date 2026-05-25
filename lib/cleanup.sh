#!/bin/bash

cleanup_work_dir() {
    local work_dir="$1"
    if [ -n "$work_dir" ] && [ -d "$work_dir" ]; then
        rm -rf "$work_dir"
    fi
}

get_unique_filename() {
    local base_path="$1"
    local extension="$2"
    local final_path="${base_path}${extension}"
    local counter=1
    while [ -f "$final_path" ]; do
        final_path="${base_path}_${counter}${extension}"
        counter=$((counter + 1))
    done
    echo "$final_path"
}
