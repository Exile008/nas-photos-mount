#!/system/bin/sh

MODDIR=${MODDIR:-/data/adb/modules/nas_photos_mount}
DATA_DIR='/data/adb/nas_photos_mount'
SETTINGS_DIR="$DATA_DIR/settings"
STATE_DIR="$DATA_DIR/state"
SOURCES_DIR="$DATA_DIR/sources"
DELETED_DIR="$DATA_DIR/deleted-sources"
CONFIG="$DATA_DIR/rclone.conf"
BUSYBOX='/data/adb/magisk/busybox'
RCLONE="$MODDIR/rclone"
MOUNT_BASE='/mnt/nas-photos'
LOG="$DATA_DIR/nas-photos.log"
WEB_PORT='8686'

read_file_value() {
  value_file=$1
  default_value=$2
  if [ -r "$value_file" ]; then
    sed -n '1p' "$value_file"
  else
    printf '%s\n' "$default_value"
  fi
}

read_setting() {
  read_file_value "$SETTINGS_DIR/$1" "$2"
}

read_source_setting() {
  source_id=$1
  setting_name=$2
  default_value=$3
  read_file_value "$SOURCES_DIR/$source_id/$setting_name" "$default_value"
}

write_default() {
  setting_file=$1
  default_value=$2
  [ -e "$setting_file" ] || printf '%s\n' "$default_value" > "$setting_file"
}

source_ids() {
  for source_path in "$SOURCES_DIR"/*; do
    [ -d "$source_path" ] || continue
    source_id=${source_path##*/}
    valid_source_id "$source_id" && printf '%s\n' "$source_id"
  done
}

valid_source_id() {
  case "$1" in
    source-*) ;;
    *) return 1 ;;
  esac
  case "$1" in
    *[!a-z0-9-]*) return 1 ;;
  esac
  [ "$1" != 'source-' ]
}

source_exists() {
  valid_source_id "$1" && [ -d "$SOURCES_DIR/$1" ]
}

source_state_dir() {
  printf '%s\n' "$SOURCES_DIR/$1/state"
}

secure_source_permissions() {
  source_dir=$1
  source_state="$source_dir/state"
  chmod 0700 "$source_dir" "$source_state"
  for source_entry in "$source_dir"/* "$source_state"/*; do
    [ -f "$source_entry" ] && chmod 0600 "$source_entry"
    [ -d "$source_entry" ] && chmod 0700 "$source_entry"
  done
}

migrate_v2_source() {
  [ -e "$DATA_DIR/.v3-migrated" ] && return 0

  # A clean install has no v2 settings to migrate and should start without a source.
  if [ ! -r "$SETTINGS_DIR/remote_path" ] && [ ! -r "$SETTINGS_DIR/album_name" ] && [ ! -r "$STATE_DIR/seen.tsv" ]; then
    : > "$DATA_DIR/.v3-migrated"
    return 0
  fi

  source_id='source-1'
  source_dir="$SOURCES_DIR/$source_id"
  source_state="$source_dir/state"
  mkdir -p "$source_dir" "$source_state"

  remote_path=$(read_setting remote_path '')
  album_name=$(read_setting album_name 'NAS-Upload')
  auto_scan=$(read_setting auto_scan '1')
  interval=$(read_setting scan_interval_minutes '360')
  batch_size=$(read_setting scan_batch_size '500')

  write_default "$source_dir/remote_path" "$remote_path"
  write_default "$source_dir/album_name" "$album_name"
  write_default "$source_dir/enabled" '1'
  write_default "$source_dir/auto_scan" "$auto_scan"
  write_default "$source_dir/scan_interval_minutes" "$interval"
  write_default "$source_dir/scan_batch_size" "$batch_size"

  if [ ! -e "$source_dir/ignore.syncthing" ]; then
    if [ -r "$SETTINGS_DIR/ignore.syncthing" ]; then
      cp "$SETTINGS_DIR/ignore.syncthing" "$source_dir/ignore.syncthing"
    else
      cp "$MODDIR/default-ignore.syncthing" "$source_dir/ignore.syncthing"
    fi
  fi

  for state_name in seen.tsv current.tsv current.files current.bytes pending.files last.submitted last_scan.epoch scan.status scan.error rclone.pid active-album active-remote; do
    [ -r "$STATE_DIR/$state_name" ] && [ ! -e "$source_state/$state_name" ] && cp "$STATE_DIR/$state_name" "$source_state/$state_name"
  done
  [ -e "$source_state/seen.tsv" ] || : > "$source_state/seen.tsv"
  : > "$DATA_DIR/.v3-migrated"
}

ensure_data() {
  mkdir -p "$DATA_DIR" "$SETTINGS_DIR" "$STATE_DIR" "$SOURCES_DIR" "$DELETED_DIR"
  chmod 0700 "$DATA_DIR" "$SETTINGS_DIR" "$STATE_DIR" "$SOURCES_DIR" "$DELETED_DIR"

  if [ ! -r "$CONFIG" ] && [ -r "$MODDIR/rclone.conf" ]; then
    cp "$MODDIR/rclone.conf" "$CONFIG"
  fi

  if [ ! -s "$DATA_DIR/web.token" ]; then
    "$BUSYBOX" od -An -N24 -tx1 /dev/urandom | tr -d ' \r\n' > "$DATA_DIR/web.token"
  fi

  migrate_v2_source
  for source_id in $(source_ids); do
    source_dir="$SOURCES_DIR/$source_id"
    source_state="$source_dir/state"
    mkdir -p "$source_state"
    [ -e "$source_state/seen.tsv" ] || : > "$source_state/seen.tsv"
    secure_source_permissions "$source_dir"
  done
  chmod 0600 "$CONFIG" "$DATA_DIR/web.token" 2>/dev/null || true
}

log_message() {
  printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"
}

valid_remote_path() {
  candidate=$1
  [ -n "$candidate" ] || return 1
  [ "${#candidate}" -le 512 ] || return 1
  case "$candidate" in
    /*|*..*|*':'*|*';'*|*'"'*|*'\'*) return 1 ;;
  esac
  has_no_control_chars "$candidate" || return 1
  return 0
}

valid_album_name() {
  candidate=$1
  [ -n "$candidate" ] || return 1
  [ "${#candidate}" -le 80 ] || return 1
  case "$candidate" in
    '.'|'..'|*'/'*|*':'*|*';'*|*'"'*|*'\'*) return 1 ;;
  esac
  has_no_control_chars "$candidate" || return 1
  return 0
}

valid_connection_value() {
  candidate=$1
  max_length=$2
  [ "${#candidate}" -le "$max_length" ] || return 1
  case "$candidate" in
    *';'*|*'"'*|*'\'*) return 1 ;;
  esac
  has_no_control_chars "$candidate" || return 1
  return 0
}

has_no_control_chars() {
  candidate=$1
  [ "$(printf '%s' "$candidate" | LC_ALL=C tr -d '[:cntrl:]')" = "$candidate" ]
}

valid_host() {
  candidate=$1
  [ -n "$candidate" ] || return 1
  [ "${#candidate}" -le 255 ] || return 1
  case "$candidate" in
    *[!A-Za-z0-9._:-]*) return 1 ;;
  esac
  return 0
}

is_uint() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
  esac
  return 0
}

rclone_config_value() {
  config_key=$1
  [ -r "$CONFIG" ] || return 0
  sed -n "s/^[[:space:]]*$config_key[[:space:]]*=[[:space:]]*//p" "$CONFIG" | sed -n '1p'
}
