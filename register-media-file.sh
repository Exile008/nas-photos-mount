#!/system/bin/sh

MEDIA_PATH=$1
AM_BIN=${AM_BIN:-/system/bin/am}

case "$MEDIA_PATH" in
  /storage/emulated/0/DCIM/*) ;;
  *) exit 1 ;;
esac

[ -x "$AM_BIN" ] || exit 1
exec "$AM_BIN" broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE \
  -d "file://$MEDIA_PATH" </dev/null >/dev/null 2>&1
