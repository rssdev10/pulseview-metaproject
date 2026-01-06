#!/usr/bin/env bash
set -euo pipefail  # Exit on error, treat unset vars as errors, pipefail enabled

# Default environment variables for branch selections (use defaults if unset)
PULSEVIEW_REF="${PULSEVIEW_REF:-master}"
LIBSIGROK_REF="${LIBSIGROK_REF:-master}"
LIBSIGROKDECODE_REF="${LIBSIGROKDECODE_REF:-master}"

# Ensure PKG_CONFIG_PATH is at least an empty string to avoid unbound variable issues
PKG_CONFIG_PATH="${PKG_CONFIG_PATH:-}"
export PKG_CONFIG_PATH
