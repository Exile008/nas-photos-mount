#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/lib.sh"
ensure_data
"$MODDIR/start-web.sh"
sleep 1

token=$(sed -n '1p' "$DATA_DIR/web.token")
am start --user 0 -a android.intent.action.VIEW \
  -d "http://127.0.0.1:$WEB_PORT/#$token" >/dev/null 2>&1
