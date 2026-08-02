#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_DIR=$(mktemp -d)

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

MOCK_AM="$TEST_DIR/am"
AM_LOG="$TEST_DIR/am.log"
BATCH_INPUT="$TEST_DIR/batch.tsv"

printf '%s\n' \
  '#!/bin/sh' \
  'if IFS= read -r leaked_input; then exit 42; fi' \
  'printf "%s\n" "$*" > "$AM_LOG"' > "$MOCK_AM"
chmod 0755 "$MOCK_AM"
printf '%s\n' 'this input belongs to the outer scan loop' > "$BATCH_INPUT"

AM_BIN="$MOCK_AM" AM_LOG="$AM_LOG" sh "$ROOT_DIR/register-media-file.sh" \
  '/storage/emulated/0/DCIM/NAS-Test/Standalone.MOV' < "$BATCH_INPUT"

grep -Fq 'broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///storage/emulated/0/DCIM/NAS-Test/Standalone.MOV' "$AM_LOG"
grep -Fq 'register-media-file.sh' "$ROOT_DIR/scan-new.sh"
if AM_BIN="$MOCK_AM" AM_LOG="$AM_LOG" sh "$ROOT_DIR/register-media-file.sh" '/data/local/tmp/not-media.MOV'; then
  printf 'media scanner accepted a path outside DCIM\n' >&2
  exit 1
fi

printf 'media scanner stdin isolation test passed\n'
