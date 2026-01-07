#!/usr/bin/env bash
set -euo pipefail  # Exit on error, treat unset vars as errors, pipefail enabled

# Default environment variables for branch selections (use defaults if unset)
PULSEVIEW_REF="${PULSEVIEW_REF:-master}"
LIBSIGROK_REF="${LIBSIGROK_REF:-master}"
LIBSIGROK_REPO="${LIBSIGROK_REPO:-sigrokproject/libsigrok}"
LIBSIGROKDECODE_REF="${LIBSIGROKDECODE_REF:-master}"
LIBSERIALPORT_REF="${LIBSERIALPORT_REF:-master}"

# Ensure PKG_CONFIG_PATH is at least an empty string to avoid unbound variable issues
PKG_CONFIG_PATH="${PKG_CONFIG_PATH:-}"
export PKG_CONFIG_PATH

# Helper function to clone from GitHub repo (supports owner/repo or full URL)
clone_repo() {
    local repo="$1"
    local ref="$2"
    local target_dir="$3"
    
    if [[ "$repo" == http* ]]; then
        git clone --depth 1 -b "$ref" "$repo" "$target_dir"
    else
        git clone --depth 1 -b "$ref" "https://github.com/$repo.git" "$target_dir"
    fi
}
