#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/lib.sh"
ensure_data

PIDFILE="$STATE_DIR/httpd.pid"
if [ -r "$PIDFILE" ]; then
  httpd_pid=$(sed -n '1p' "$PIDFILE")
  if [ -n "$httpd_pid" ] && [ -r "/proc/$httpd_pid/cmdline" ]; then
    cmdline=$(tr '\000' ' ' < "/proc/$httpd_pid/cmdline")
    case "$cmdline" in
      *httpd*"127.0.0.1:$WEB_PORT"*) exit 0 ;;
    esac
  fi
  rm -f "$PIDFILE"
fi

"$BUSYBOX" setsid "$BUSYBOX" httpd -f -p "127.0.0.1:$WEB_PORT" -h "$MODDIR/web" \
  </dev/null >> "$DATA_DIR/httpd.log" 2>&1 &
printf '%s\n' "$!" > "$PIDFILE"
