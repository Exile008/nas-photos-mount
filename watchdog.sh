#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/lib.sh"
ensure_data

SERVICE_PIDFILE="$STATE_DIR/service.pid"
trap 'rm -f "$SERVICE_PIDFILE"' EXIT

count=0
until [ "$(getprop sys.boot_completed)" = 1 ] && [ -d /data/media/0 ]; do
  sleep 10
  count=$((count + 1))
  [ "$count" -ge 120 ] && exit 1
done

nsenter -t 1 -m -- "$MODDIR/mount-once.sh"
"$MODDIR/start-web.sh"
"$MODDIR/refresh-capacity.sh" >/dev/null 2>&1 || true
tick=0

while true; do
  sleep 60
  tick=$((tick + 1))
  now=$(date +%s)

  for source_id in $(source_ids); do
    enabled=$(read_source_setting "$source_id" enabled '1')
    if [ "$enabled" != 1 ]; then
      continue
    fi

    source_state="$SOURCES_DIR/$source_id/state"
    source_mount="$MOUNT_BASE/$source_id"
    source_pid=$(read_file_value "$source_state/rclone.pid" '0')
    source_process_ok=false
    if is_uint "$source_pid" && [ -r "/proc/$source_pid/cmdline" ]; then
      source_cmdline=$(tr '\000' ' ' < "/proc/$source_pid/cmdline")
      case "$source_cmdline" in
        *"$MODDIR/rclone"*"$source_mount"*) source_process_ok=true ;;
      esac
    fi
    if ! mountpoint -q "$source_mount" || [ "$source_process_ok" != true ]; then
      nsenter -t 1 -m -- "$MODDIR/mount-once.sh" "$source_id"
    fi

    auto_scan=$(read_source_setting "$source_id" auto_scan '1')
    interval=$(read_source_setting "$source_id" scan_interval_minutes '360')
    is_uint "$interval" || interval=360
    [ "$interval" -ge 1 ] || interval=1
    last_scan=$(read_file_value "$source_state/last_scan.epoch" '0')
    if [ "$auto_scan" = 1 ] && [ $((now - last_scan)) -ge $((interval * 60)) ]; then
      "$BUSYBOX" setsid "$MODDIR/scan-new.sh" "$source_id" </dev/null >> "$LOG" 2>&1 &
    fi
  done

  "$MODDIR/start-web.sh"
  if [ "$tick" -ge 5 ]; then
    "$MODDIR/refresh-capacity.sh" >/dev/null 2>&1 || true
    tick=0
  fi
done
