#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/lib.sh"
ensure_data
SERVICE_PIDFILE="$STATE_DIR/service.pid"
HTTPD_PIDFILE="$STATE_DIR/httpd.pid"

if [ -r "$SERVICE_PIDFILE" ]; then
  service_pid=$(cat "$SERVICE_PIDFILE")
  [ -n "$service_pid" ] && kill "$service_pid" 2>/dev/null
  rm -f "$SERVICE_PIDFILE"
fi

if [ -r "$HTTPD_PIDFILE" ]; then
  httpd_pid=$(sed -n '1p' "$HTTPD_PIDFILE")
  [ -n "$httpd_pid" ] && kill "$httpd_pid" 2>/dev/null
  rm -f "$HTTPD_PIDFILE"
fi

nsenter -t 1 -m -- "$MODDIR/unmount.sh"
