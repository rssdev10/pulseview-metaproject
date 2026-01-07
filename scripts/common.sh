#!/usr/bin/env bash
set -euo pipefail  # Exit on error, treat unset vars as errors, pipefail enabled

# Default environment variables for branch selections (use defaults if unset)
PULSEVIEW_REF="${PULSEVIEW_REF:-master}"
LIBSIGROK_REF="${LIBSIGROK_REF:-master}"
LIBSIGROK_REPO="${LIBSIGROK_REPO:-sigrokproject/libsigrok}"
LIBSIGROKDECODE_REF="${LIBSIGROKDECODE_REF:-master}"
LIBSERIALPORT_REF="${LIBSERIALPORT_REF:-master}"
SIGROK_CLI_REF="${SIGROK_CLI_REF:-master}"
SIGROK_UTIL_REF="${SIGROK_UTIL_REF:-master}"

# Ensure PKG_CONFIG_PATH is at least an empty string to avoid unbound variable issues
PKG_CONFIG_PATH="${PKG_CONFIG_PATH:-}"
export PKG_CONFIG_PATH

# Helper logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Helper to check if command exists
need() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        log "ERROR: Required command '$cmd' not found"
        exit 1
    fi
}

# Helper function to clone from GitHub repo (supports owner/repo or full URL)
clone_repo() {
    local repo="$1"
    local ref="$2"
    local target_dir="${3:-.}"
    
    log "Cloning $repo @ $ref into $target_dir"
    
    if [[ "$repo" == http* ]]; then
        git clone --depth 1 -b "$ref" "$repo" "$target_dir"
    else
        git clone --depth 1 -b "$ref" "https://github.com/$repo.git" "$target_dir"
    fi
}

# Helper function for checkout_sigrok_deps.sh - supports org/repo syntax
checkout_repo() {
    local org="$1"
    local repo="$2"
    local ref="$3"
    local target_dir="$4"
    
    log "Checking out $org/$repo @ $ref into $target_dir"
    
    if [[ -d "$target_dir" ]]; then
        log "Directory $target_dir already exists, skipping checkout"
        return 0
    fi
    
    mkdir -p "$(dirname "$target_dir")"
    git clone --depth 1 -b "$ref" "https://github.com/$org/$repo.git" "$target_dir"
}
