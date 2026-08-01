#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

assert_contains() {
  local file=$1
  local expected=$2
  grep -Fq "$expected" "$ROOT_DIR/$file" || {
    printf 'missing expected source control behavior in %s: %s\n' "$file" "$expected" >&2
    exit 1
  }
}

assert_not_contains() {
  local file=$1
  local unexpected=$2
  if grep -Fq "$unexpected" "$ROOT_DIR/$file"; then
    printf 'unexpected legacy UI behavior in %s: %s\n' "$file" "$unexpected" >&2
    exit 1
  fi
}

assert_contains web/cgi-bin/action 'pauseMount)'
assert_contains web/cgi-bin/action 'resumeMount)'
assert_contains watchdog.sh '[ "$enabled" != 1 ] || [ "$paused" = 1 ]'
assert_contains mount-once.sh '[ "$PAUSED" = 0 ]'
assert_contains web/index.html 'ignoreLivePhoto: '\''忽略 Live Photo，只上传静态图'\'''
assert_contains web/index.html "ignoreLivePhoto: 'Ignore Live Photos; upload still images only'"
assert_not_contains web/index.html '媒体登记队列'
assert_not_contains web/index.html 'Media registration queue'
assert_not_contains web/cgi-bin/status '"pendingFiles"'
assert_not_contains web/cgi-bin/status '"totalPending"'

printf 'source controls test passed\n'
