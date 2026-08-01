#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/lib.sh"
ensure_data

SERVICE_PIDFILE="$STATE_DIR/service.pid"
if [ -r "$SERVICE_PIDFILE" ]; then
  service_pid=$(sed -n '1p' "$SERVICE_PIDFILE")
  if [ -n "$service_pid" ] && [ -r "/proc/$service_pid/cmdline" ]; then
    cmdline=$(tr '\000' ' ' < "/proc/$service_pid/cmdline")
    case "$cmdline" in
      *"$MODDIR/watchdog.sh"*)
        "$MODDIR/start-web.sh"
        exit 0
        ;;
    esac
  fi
  rm -f "$SERVICE_PIDFILE"
fi

"$BUSYBOX" setsid "$MODDIR/watchdog.sh" </dev/null >> "$LOG" 2>&1 &
printf '%s\n' "$!" > "$SERVICE_PIDFILE"
