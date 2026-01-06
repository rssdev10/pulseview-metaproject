#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

need git

: "${SIGROK_ORG:?}"
: "${DEPS_DIR:?}"

mkdir -p "$DEPS_DIR"

checkout_repo "$SIGROK_ORG" "pulseview"       "${PULSEVIEW_REF:?}"       "$DEPS_DIR/pulseview"
checkout_repo "$SIGROK_ORG" "libsigrok"       "${LIBSIGROK_REF:?}"       "$DEPS_DIR/libsigrok"
checkout_repo "$SIGROK_ORG" "libsigrokdecode" "${LIBSIGROKDECODE_REF:?}" "$DEPS_DIR/libsigrokdecode"
checkout_repo "$SIGROK_ORG" "libserialport"   "${LIBSERIALPORT_REF:?}"   "$DEPS_DIR/libserialport"
checkout_repo "$SIGROK_ORG" "sigrok-cli"      "${SIGROK_CLI_REF:?}"      "$DEPS_DIR/sigrok-cli"
checkout_repo "$SIGROK_ORG" "sigrok-util"     "${SIGROK_UTIL_REF:?}"     "$DEPS_DIR/sigrok-util"

log "All deps are ready in $DEPS_DIR"
