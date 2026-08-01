#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_DIR=$(mktemp -d)

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

INPUT="$TEST_DIR/input.txt"
PATHS="$TEST_DIR/paths.txt"
FILTER="$TEST_DIR/filter.txt"
EXPECTED_PATHS="$TEST_DIR/expected-paths.txt"
EXPECTED_FILTER="$TEST_DIR/expected-filter.txt"

printf '%s\n' \
  'A/IMG_0001.HEIC' \
  'A/IMG_0001.MOV' \
  'A/standalone.MOV' \
  'B/Mixed.HeIc' \
  'B/Mixed.mov' \
  'C/IMG[2]*?.HEIC' \
  'C/IMG[2]*?.MOV' \
  'D/IMG_0004.JPG' \
  'D/IMG_0004.MOV' > "$INPUT"

sh "$ROOT_DIR/build-live-photo-excludes.sh" "$INPUT" "$PATHS" "$FILTER"

printf '%s\n' \
  'A/IMG_0001.MOV' \
  'B/Mixed.mov' \
  'C/IMG[2]*?.MOV' > "$EXPECTED_PATHS"
printf '%s\n' \
  '/A/IMG_0001.MOV' \
  '/B/Mixed.mov' \
  '/C/IMG\[2\]\*\?.MOV' > "$EXPECTED_FILTER"

cmp "$EXPECTED_PATHS" "$PATHS"
cmp "$EXPECTED_FILTER" "$FILTER"
! grep -Fq 'standalone.MOV' "$PATHS"
! grep -Fq 'IMG_0004.MOV' "$PATHS"

printf 'Live Photo pair filter test passed\n'
