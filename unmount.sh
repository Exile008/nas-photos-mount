#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/lib.sh"
ensure_data

if [ -z "$1" ]; then
  for source_id in $(source_ids); do "$0" "$source_id"; done
  mountpoint -q "$MOUNT_BASE" && umount -lf "$MOUNT_BASE" 2>/dev/null || true
  exit 0
fi

SOURCE_ID=$1
source_exists "$SOURCE_ID" || exit 0
SOURCE_DIR="$SOURCES_DIR/$SOURCE_ID"
SOURCE_STATE="$SOURCE_DIR/state"
MOUNT_ROOT="$MOUNT_BASE/$SOURCE_ID"
ALBUM_NAME=$(read_source_setting "$SOURCE_ID" album_name '')
[ -r "$SOURCE_STATE/active-album" ] && ALBUM_NAME=$(sed -n '1p' "$SOURCE_STATE/active-album")
REL_PATH="DCIM/$ALBUM_NAME"
PIDFILE="$SOURCE_STATE/rclone.pid"

[ -n "$ALBUM_NAME" ] && umount -lf "/storage/emulated/0/$REL_PATH" 2>/dev/null || true
for view in full write read default; do
  [ -n "$ALBUM_NAME" ] || continue
  umount -lf "/mnt/runtime/$view/emulated/0/$REL_PATH" 2>/dev/null || true
done

if [ -r "$PIDFILE" ]; then
  pid=$(sed -n '1p' "$PIDFILE")
  if [ -n "$pid" ] && [ -r "/proc/$pid/cmdline" ]; then
    cmdline=$(tr '\000' ' ' < "/proc/$pid/cmdline")
    case "$cmdline" in
      *"$MODDIR/rclone"*"$MOUNT_ROOT"*|*"$MODDIR/rclone"*"$MOUNT_BASE --config"*) kill "$pid" 2>/dev/null ;;
    esac
  fi
  rm -f "$PIDFILE"
fi

mountpoint -q "$MOUNT_ROOT" && umount -lf "$MOUNT_ROOT" 2>/dev/null || true
printf '%s\n' 'unmounted' > "$SOURCE_STATE/mount.status"
log_message "[$SOURCE_ID] unmounted"
exit 0
