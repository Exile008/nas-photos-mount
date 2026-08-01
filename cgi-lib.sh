#!/system/bin/sh

MODDIR='/data/adb/modules/nas_photos_mount'
. "$MODDIR/lib.sh"
ensure_data

send_json_header() {
  printf 'Content-Type: application/json; charset=utf-8\r\n'
  printf 'Cache-Control: no-store\r\n\r\n'
}

send_text_header() {
  printf 'Content-Type: text/plain; charset=utf-8\r\n'
  printf 'Cache-Control: no-store\r\n\r\n'
}

fail_json() {
  status_code=$1
  error_code=$2
  printf 'Status: %s\r\n' "$status_code"
  send_json_header
  printf '{"ok":false,"error":"%s"}\n' "$error_code"
  exit 0
}

require_auth() {
  expected_token=$(sed -n '1p' "$DATA_DIR/web.token")
  [ -n "$expected_token" ] || fail_json '500 Internal Server Error' 'token_missing'
  [ "$HTTP_X_NAS_TOKEN" = "$expected_token" ] || fail_json '403 Forbidden' 'forbidden'
}

state_value() {
  state_file=$1
  fallback=$2
  if [ -r "$STATE_DIR/$state_file" ]; then
    sed -n '1p' "$STATE_DIR/$state_file"
  else
    printf '%s\n' "$fallback"
  fi
}

decode_form_value() {
  "$BUSYBOX" httpd -d "$1"
}

read_request_body() {
  content_length=${CONTENT_LENGTH:-0}
  is_uint "$content_length" || fail_json '400 Bad Request' 'invalid_length'
  [ "$content_length" -le 131072 ] || fail_json '413 Payload Too Large' 'request_too_large'
  "$BUSYBOX" dd bs=1 count="$content_length" 2>/dev/null
}
