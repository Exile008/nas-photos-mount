#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/lib.sh"
ensure_data

if [ -z "$1" ]; then
  for source_id in $(source_ids); do
    [ "$(read_source_setting "$source_id" enabled '1')" = 1 ] || continue
    [ "$(read_source_setting "$source_id" paused '0')" = 0 ] && "$0" "$source_id"
  done
  exit 0
fi

SOURCE_ID=$1
source_exists "$SOURCE_ID" || exit 1
SOURCE_DIR="$SOURCES_DIR/$SOURCE_ID"
SOURCE_STATE="$SOURCE_DIR/state"
REMOTE_PATH=$(read_source_setting "$SOURCE_ID" remote_path '')
ALBUM_NAME=$(read_source_setting "$SOURCE_ID" album_name '')
ENABLED=$(read_source_setting "$SOURCE_ID" enabled '1')
PAUSED=$(read_source_setting "$SOURCE_ID" paused '0')
IGNORE_LIVE_PHOTO=$(read_source_setting "$SOURCE_ID" ignore_live_photo '0')
REMOTE="nas:$REMOTE_PATH"
REL_PATH="DCIM/$ALBUM_NAME"
STORAGE_PATH="/storage/emulated/0/$REL_PATH"
MOUNT_ROOT="$MOUNT_BASE/$SOURCE_ID"
PIDFILE="$SOURCE_STATE/rclone.pid"
FILTER_FILE="$SOURCE_STATE/exclude.rclone"
CASE_MARKER="$SOURCE_STATE/ignore-case"
LIVE_FILTER_FILE="$SOURCE_STATE/live-photo-exclude.rclone"
CACHE_DIR="$SOURCE_STATE/cache"

export PATH="$MODDIR:/system/bin:/system/xbin"
export LD_LIBRARY_PATH="$MODDIR"

[ "$ENABLED" = 1 ] || exit 0
[ "$PAUSED" = 0 ] || { printf '%s\n' 'paused' > "$SOURCE_STATE/mount.status"; exit 0; }
valid_remote_path "$REMOTE_PATH" || { log_message "[$SOURCE_ID] invalid remote path"; exit 1; }
valid_album_name "$ALBUM_NAME" || { log_message "[$SOURCE_ID] invalid album name"; exit 1; }
[ -x "$RCLONE" ] && [ -r "$CONFIG" ] || { log_message "[$SOURCE_ID] rclone or config missing"; exit 1; }

"$MODDIR/compile-ignore.sh" "$SOURCE_DIR/ignore.syncthing" "$FILTER_FILE" "$CASE_MARKER" || exit 1
set --
if [ "$IGNORE_LIVE_PHOTO" = 1 ]; then
  if ! "$MODDIR/refresh-live-photo-filter.sh" "$SOURCE_ID" >/dev/null; then
    printf '%s\n' 'error' > "$SOURCE_STATE/mount.status"
    log_message "[$SOURCE_ID] mount stopped because the Live Photo filter could not be refreshed"
    exit 1
  fi
  set -- --exclude-from "$LIVE_FILTER_FILE"
fi
mkdir -p "$MOUNT_ROOT" "$CACHE_DIR" "/data/media/0/$REL_PATH"
chmod 0700 "$CACHE_DIR"
mountpoint -q "$MOUNT_ROOT" || chmod 0700 "$MOUNT_ROOT"
chown media_rw:media_rw "/data/media/0/$REL_PATH"
chmod 0770 "/data/media/0/$REL_PATH"

if mountpoint -q "$MOUNT_ROOT" && ! timeout 20 ls "$MOUNT_ROOT" >/dev/null 2>&1; then
  "$MODDIR/unmount.sh" "$SOURCE_ID"
fi

if ! mountpoint -q "$MOUNT_ROOT"; then
  IGNORE_CASE_FLAG=''
  [ -e "$CASE_MARKER" ] && IGNORE_CASE_FLAG='--ignore-case'
  nohup "$RCLONE" mount "$REMOTE" "$MOUNT_ROOT" \
    --config "$CONFIG" --read-only --allow-other --uid 0 --gid 9997 \
    --dir-perms 0770 --file-perms 0440 --umask 007 \
    --exclude-from "$FILTER_FILE" "$@" $IGNORE_CASE_FLAG \
    --vfs-cache-mode off --buffer-size 0 \
    --vfs-read-chunk-size 4M --vfs-read-chunk-size-limit 64M \
    --dir-cache-time 5m --attr-timeout 1s --poll-interval 0 \
    --contimeout 5s --timeout 30s --low-level-retries 3 --retries 3 \
    --cache-dir "$CACHE_DIR" --log-file "$LOG" --log-level INFO \
    </dev/null >/dev/null 2>&1 &

  rclone_pid=$!
  printf '%s\n' "$rclone_pid" > "$PIDFILE"
  wait_count=0
  until mountpoint -q "$MOUNT_ROOT"; do
    if ! kill -0 "$rclone_pid" 2>/dev/null; then
      log_message "[$SOURCE_ID] rclone exited before mount was ready"
      rm -f "$PIDFILE"
      exit 1
    fi
    sleep 1
    wait_count=$((wait_count + 1))
    if [ "$wait_count" -ge 20 ]; then
      log_message "[$SOURCE_ID] mount timeout"
      kill "$rclone_pid" 2>/dev/null
      rm -f "$PIDFILE"
      exit 1
    fi
  done
fi

for view in default read write full; do
  base="/mnt/runtime/$view/emulated/0"
  [ -d "$base" ] || continue
  target="$base/$REL_PATH"
  mkdir -p "$target"
  mountpoint -q "$target" || mount --bind "$MOUNT_ROOT" "$target" || log_message "[$SOURCE_ID] bind failed: $target"
done

printf '%s\n' "$ALBUM_NAME" > "$SOURCE_STATE/active-album"
printf '%s\n' "$REMOTE_PATH" > "$SOURCE_STATE/active-remote"
printf '%s\n' 'mounted' > "$SOURCE_STATE/mount.status"
secure_source_permissions "$SOURCE_DIR"
log_message "[$SOURCE_ID] mounted $REMOTE at $STORAGE_PATH"
