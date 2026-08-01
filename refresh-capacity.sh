#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/lib.sh"
ensure_data

REMOTE_PATH=''
for source_id in $(source_ids); do
  if [ "$(read_source_setting "$source_id" enabled '1')" = 1 ]; then
    REMOTE_PATH=$(read_source_setting "$source_id" remote_path '')
    break
  fi
done
[ -n "$REMOTE_PATH" ] || exit 0

SHARE_NAME=${REMOTE_PATH%%/*}
TEMP_FILE="$STATE_DIR/nas-about.json.new.$$"
export LD_LIBRARY_PATH="$MODDIR"
if timeout 20 "$RCLONE" about "nas:$SHARE_NAME" --config "$CONFIG" --json > "$TEMP_FILE" 2>> "$LOG"; then
  mv "$TEMP_FILE" "$STATE_DIR/nas-about.json"
  date +%s > "$STATE_DIR/nas-about.epoch"
else
  rm -f "$TEMP_FILE"
  log_message 'capacity refresh failed'
  exit 1
fi
