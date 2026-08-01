#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_DIR=$(mktemp -d)

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

MODDIR="$ROOT_DIR"
. "$ROOT_DIR/lib.sh"

DATA_DIR="$TEST_DIR/data"
SETTINGS_DIR="$DATA_DIR/settings"
STATE_DIR="$DATA_DIR/state"
SOURCES_DIR="$DATA_DIR/sources"
DELETED_DIR="$DATA_DIR/deleted-sources"

mkdir -p "$SETTINGS_DIR" "$STATE_DIR" "$SOURCES_DIR" "$DELETED_DIR"
migrate_v2_source

[ -e "$DATA_DIR/.v3-migrated" ]
[ ! -e "$SOURCES_DIR/source-1" ]

printf 'clean-install migration test passed\n'
