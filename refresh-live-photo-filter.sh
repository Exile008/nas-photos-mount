#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/lib.sh"
ensure_data

SOURCE_ID=$1
INPUT_FILE=${2:-}
INPUT_FORMAT=${3:-paths}
source_exists "$SOURCE_ID" || exit 1

SOURCE_DIR="$SOURCES_DIR/$SOURCE_ID"
SOURCE_STATE="$SOURCE_DIR/state"
REMOTE_PATH=$(read_source_setting "$SOURCE_ID" remote_path '')
IGNORE_LIVE_PHOTO=$(read_source_setting "$SOURCE_ID" ignore_live_photo '0')
FILTER_FILE="$SOURCE_STATE/exclude.rclone"
CASE_MARKER="$SOURCE_STATE/ignore-case"
LIVE_PATHS="$SOURCE_STATE/live-photo-paths.txt"
LIVE_FILTER="$SOURCE_STATE/live-photo-exclude.rclone"
LIVE_SIGNATURE="$SOURCE_STATE/live-photo-source.signature"
TEMP_INPUT="$SOURCE_STATE/live-photo-input.$$"
TEMP_PATHS="$SOURCE_STATE/live-photo-paths.new.$$"
TEMP_FILTER="$SOURCE_STATE/live-photo-exclude.new.$$"
TEMP_SIGNATURE="$SOURCE_STATE/live-photo-source.signature.new.$$"

cleanup() {
  rm -f "$TEMP_INPUT" "$TEMP_PATHS" "$TEMP_FILTER" "$TEMP_SIGNATURE"
}
trap cleanup EXIT

valid_remote_path "$REMOTE_PATH" || exit 1
[ "$IGNORE_LIVE_PHOTO" = 0 ] || [ "$IGNORE_LIVE_PHOTO" = 1 ] || exit 1

{
  printf 'remote=%s\n' "$REMOTE_PATH"
  if [ -e "$CASE_MARKER" ]; then
    printf 'ignore_case=1\n'
  else
    printf 'ignore_case=0\n'
  fi
  cat "$FILTER_FILE" 2>/dev/null
} > "$TEMP_SIGNATURE" || exit 1

if [ "$IGNORE_LIVE_PHOTO" = 0 ]; then
  : > "$TEMP_INPUT"
elif [ -n "$INPUT_FILE" ]; then
  [ -r "$INPUT_FILE" ] || exit 1
  case "$INPUT_FORMAT" in
    raw)
      "$BUSYBOX" awk '{ path=$0; sub(/^[^;]*;[^;]*;/, "", path); print path }' "$INPUT_FILE" > "$TEMP_INPUT" || exit 1
      ;;
    paths) cp "$INPUT_FILE" "$TEMP_INPUT" || exit 1 ;;
    *) exit 1 ;;
  esac
elif [ -r "$LIVE_SIGNATURE" ] && [ -r "$LIVE_PATHS" ] && [ -r "$LIVE_FILTER" ] \
  && "$BUSYBOX" cmp -s "$TEMP_SIGNATURE" "$LIVE_SIGNATURE"; then
  printf '%s\n' 'unchanged'
  exit 0
else
  IGNORE_CASE_FLAG=''
  [ -e "$CASE_MARKER" ] && IGNORE_CASE_FLAG='--ignore-case'
  export LD_LIBRARY_PATH="$MODDIR"
  if ! "$RCLONE" lsf "nas:$REMOTE_PATH" --config "$CONFIG" --recursive --files-only --format p \
    --exclude-from "$FILTER_FILE" $IGNORE_CASE_FLAG \
    --contimeout 5s --timeout 30s --low-level-retries 3 --retries 3 \
    > "$TEMP_INPUT" 2>> "$LOG"; then
    log_message "[$SOURCE_ID] Live Photo inventory failed"
    exit 1
  fi
fi

"$MODDIR/build-live-photo-excludes.sh" "$TEMP_INPUT" "$TEMP_PATHS" "$TEMP_FILTER" "$BUSYBOX" || exit 1

changed=false
"$BUSYBOX" cmp -s "$TEMP_PATHS" "$LIVE_PATHS" 2>/dev/null || changed=true
"$BUSYBOX" cmp -s "$TEMP_FILTER" "$LIVE_FILTER" 2>/dev/null || changed=true
"$BUSYBOX" cmp -s "$TEMP_SIGNATURE" "$LIVE_SIGNATURE" 2>/dev/null || changed=true

mv "$TEMP_PATHS" "$LIVE_PATHS"
mv "$TEMP_FILTER" "$LIVE_FILTER"
mv "$TEMP_SIGNATURE" "$LIVE_SIGNATURE"
chmod 0600 "$LIVE_PATHS" "$LIVE_FILTER" "$LIVE_SIGNATURE"
secure_source_permissions "$SOURCE_DIR"

if [ "$changed" = true ]; then
  pair_count=$("$BUSYBOX" wc -l < "$LIVE_PATHS" | tr -d ' ')
  log_message "[$SOURCE_ID] Live Photo filter updated pairs=$pair_count"
  printf '%s\n' 'changed'
else
  printf '%s\n' 'unchanged'
fi

trap - EXIT
exit 0
