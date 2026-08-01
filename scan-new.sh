#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/lib.sh"
ensure_data

SOURCE_ID=$1
source_exists "$SOURCE_ID" || exit 1
SOURCE_DIR="$SOURCES_DIR/$SOURCE_ID"
SOURCE_STATE="$SOURCE_DIR/state"
MOUNT_ROOT="$MOUNT_BASE/$SOURCE_ID"
LOCK_DIR="$SOURCE_STATE/scan.lock.d"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  lock_pid=0
  [ -r "$LOCK_DIR/pid" ] && lock_pid=$(sed -n '1p' "$LOCK_DIR/pid")
  [ -n "$lock_pid" ] && [ -d "/proc/$lock_pid" ] && exit 0
  rm -f "$LOCK_DIR/pid"
  rmdir "$LOCK_DIR" 2>/dev/null || exit 0
  mkdir "$LOCK_DIR" 2>/dev/null || exit 0
fi
printf '%s\n' "$$" > "$LOCK_DIR/pid"
chmod 0700 "$LOCK_DIR"

REMOTE_PATH=$(read_source_setting "$SOURCE_ID" remote_path '')
ALBUM_NAME=$(read_source_setting "$SOURCE_ID" album_name '')
BATCH_SIZE=$(read_source_setting "$SOURCE_ID" scan_batch_size '500')
FILTER_FILE="$SOURCE_STATE/exclude.rclone"
CASE_MARKER="$SOURCE_STATE/ignore-case"
CURRENT_RAW="$SOURCE_STATE/current.raw.$$"
CURRENT_ALL="$SOURCE_STATE/current.all.$$"
CURRENT_NEW="$SOURCE_STATE/current.tsv.new.$$"
PENDING_NEW="$SOURCE_STATE/pending.tsv.new.$$"
BATCH_NEW="$SOURCE_STATE/batch.tsv.new.$$"
SUBMITTED_NEW="$SOURCE_STATE/submitted.tsv.new.$$"
SEEN_NEW="$SOURCE_STATE/seen.tsv.new.$$"

cleanup() {
  rm -f "$CURRENT_RAW" "$CURRENT_ALL" "$CURRENT_NEW" "$PENDING_NEW" "$BATCH_NEW" "$SUBMITTED_NEW" "$SEEN_NEW"
  rm -f "$LOCK_DIR/pid"
  rmdir "$LOCK_DIR" 2>/dev/null || true
}
trap cleanup EXIT

valid_remote_path "$REMOTE_PATH" || exit 1
valid_album_name "$ALBUM_NAME" || exit 1
is_uint "$BATCH_SIZE" || BATCH_SIZE=500
[ "$BATCH_SIZE" -ge 1 ] || BATCH_SIZE=500
[ "$BATCH_SIZE" -le 5000 ] || BATCH_SIZE=5000

if ! mountpoint -q "$MOUNT_ROOT"; then
  printf '%s\n' 'error' > "$SOURCE_STATE/scan.status"
  printf '%s\n' 'mount is not active' > "$SOURCE_STATE/scan.error"
  exit 1
fi

"$MODDIR/compile-ignore.sh" "$SOURCE_DIR/ignore.syncthing" "$FILTER_FILE" "$CASE_MARKER" || exit 1
printf '%s\n' 'scanning' > "$SOURCE_STATE/scan.status"
: > "$SOURCE_STATE/scan.error"
date +%s > "$SOURCE_STATE/scan.started"

IGNORE_CASE_FLAG=''
[ -e "$CASE_MARKER" ] && IGNORE_CASE_FLAG='--ignore-case'
export LD_LIBRARY_PATH="$MODDIR"

if ! "$RCLONE" lsf "nas:$REMOTE_PATH" \
  --config "$CONFIG" --recursive --files-only --format stp --separator ';' \
  --exclude-from "$FILTER_FILE" $IGNORE_CASE_FLAG \
  --contimeout 5s --timeout 30s --low-level-retries 3 --retries 3 \
  > "$CURRENT_RAW" 2>> "$LOG"; then
  printf '%s\n' 'error' > "$SOURCE_STATE/scan.status"
  printf '%s\n' 'NAS inventory failed; see module log' > "$SOURCE_STATE/scan.error"
  exit 1
fi

"$BUSYBOX" awk -v prefix="$REMOTE_PATH;$ALBUM_NAME;" '{ print prefix $0 }' "$CURRENT_RAW" \
  | LC_ALL=C "$BUSYBOX" sort -u > "$CURRENT_ALL"

IGNORE_LIVE_PHOTO=$(read_source_setting "$SOURCE_ID" ignore_live_photo '0')
LIVE_FILTER_CHANGED=false
if [ "$IGNORE_LIVE_PHOTO" = 1 ]; then
  live_filter_result=$("$MODDIR/refresh-live-photo-filter.sh" "$SOURCE_ID" "$CURRENT_RAW" raw) || {
    printf '%s\n' 'error' > "$SOURCE_STATE/scan.status"
    printf '%s\n' 'Live Photo filter failed; see module log' > "$SOURCE_STATE/scan.error"
    exit 1
  }
  [ "$live_filter_result" = changed ] && LIVE_FILTER_CHANGED=true
  "$BUSYBOX" awk -F';' '
    NR == FNR { hidden[$0] = 1; next }
    {
      path = $0
      sub(/^[^;]*;[^;]*;[^;]*;[^;]*;/, "", path)
      if (!hidden[path]) print $0
    }
  ' "$SOURCE_STATE/live-photo-paths.txt" "$CURRENT_ALL" > "$CURRENT_NEW"
else
  mv "$CURRENT_ALL" "$CURRENT_NEW"
fi
LC_ALL=C "$BUSYBOX" sort -u "$SOURCE_STATE/seen.tsv" -o "$SOURCE_STATE/seen.tsv"
LC_ALL=C "$BUSYBOX" comm -23 "$CURRENT_NEW" "$SOURCE_STATE/seen.tsv" > "$PENDING_NEW"
"$BUSYBOX" head -n "$BATCH_SIZE" "$PENDING_NEW" > "$BATCH_NEW"
: > "$SUBMITTED_NEW"

submitted=0
while IFS= read -r record || [ -n "$record" ]; do
  rest=${record#*;}
  rest=${rest#*;}
  rest=${rest#*;}
  rest=${rest#*;}
  relative_path=$rest
  [ -n "$relative_path" ] || continue
  if am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE \
    -d "file:///storage/emulated/0/DCIM/$ALBUM_NAME/$relative_path" >/dev/null 2>&1; then
    submitted=$((submitted + 1))
    printf '%s\n' "$record" >> "$SUBMITTED_NEW"
  fi
done < "$BATCH_NEW"

LC_ALL=C "$BUSYBOX" sort -u "$SOURCE_STATE/seen.tsv" "$SUBMITTED_NEW" > "$SEEN_NEW"
mv "$SEEN_NEW" "$SOURCE_STATE/seen.tsv"
mv "$CURRENT_NEW" "$SOURCE_STATE/current.tsv"
chmod 0600 "$SOURCE_STATE/seen.tsv" "$SOURCE_STATE/current.tsv"

file_count=$("$BUSYBOX" wc -l < "$SOURCE_STATE/current.tsv" | tr -d ' ')
total_bytes=$("$BUSYBOX" awk -F';' '{ total += $3 } END { printf "%.0f", total + 0 }' "$SOURCE_STATE/current.tsv")
pending_before=$("$BUSYBOX" wc -l < "$PENDING_NEW" | tr -d ' ')
pending_after=$((pending_before - submitted))
[ "$pending_after" -ge 0 ] || pending_after=0

printf '%s\n' "$file_count" > "$SOURCE_STATE/current.files"
printf '%s\n' "$total_bytes" > "$SOURCE_STATE/current.bytes"
printf '%s\n' "$pending_after" > "$SOURCE_STATE/pending.files"
printf '%s\n' "$submitted" > "$SOURCE_STATE/last.submitted"
date +%s > "$SOURCE_STATE/last_scan.epoch"
printf '%s\n' 'idle' > "$SOURCE_STATE/scan.status"
secure_source_permissions "$SOURCE_DIR"
log_message "[$SOURCE_ID] inventory files=$file_count bytes=$total_bytes submitted=$submitted pending=$pending_after"
if [ "$LIVE_FILTER_CHANGED" = true ]; then
  "$BUSYBOX" setsid nsenter -t 1 -m -- "$MODDIR/remount.sh" "$SOURCE_ID" </dev/null >> "$LOG" 2>&1 &
fi
