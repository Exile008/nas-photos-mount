#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

assert_contains() {
  local file=$1
  local expected=$2
  grep -Fq "$expected" "$ROOT_DIR/$file" || {
    printf 'missing expected scan interval setting in %s: %s\n' "$file" "$expected" >&2
    exit 1
  }
}

assert_contains web/index.html 'class="source-interval" type="number" min="1" max="10080"'
assert_contains web/cgi-bin/sources '[ "$interval" -ge 1 ] && [ "$interval" -le 10080 ]'
assert_contains watchdog.sh '[ "$interval" -ge 1 ] || interval=1'

printf 'one-minute scan interval test passed\n'
