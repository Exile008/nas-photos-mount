#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
VERSION=$(sed -n 's/^version=//p' "$ROOT_DIR/module.prop")
RCLONE_VERSION=$(sed -n 's/^version=//p' "$ROOT_DIR/tools/rclone.conf")
RCLONE_ARCHIVE_SHA256=$(sed -n 's/^archive_sha256=//p' "$ROOT_DIR/tools/rclone.conf")
RCLONE_ARCHIVE="rclone-v${RCLONE_VERSION}-linux-arm64.zip"
RCLONE_URL="https://downloads.rclone.org/v${RCLONE_VERSION}/${RCLONE_ARCHIVE}"
CACHE_DIR="$ROOT_DIR/.cache"
DIST_DIR="$ROOT_DIR/dist"
STAGE_DIR=$(mktemp -d)

cleanup() {
  rm -rf "$STAGE_DIR"
}
trap cleanup EXIT

mkdir -p "$CACHE_DIR" "$DIST_DIR"

verify_sha256() {
  local expected=$1
  local file=$2
  local actual
  if command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$file" | awk '{print $1}')
  else
    actual=$(shasum -a 256 "$file" | awk '{print $1}')
  fi
  [ "$actual" = "$expected" ] || {
    printf 'SHA-256 mismatch for %s\nexpected: %s\nactual:   %s\n' "$file" "$expected" "$actual" >&2
    return 1
  }
}

module_dir="$STAGE_DIR/module"
mkdir -p "$module_dir"

while IFS= read -r path; do
  [ -n "$path" ] || continue
  cp -R "$ROOT_DIR/$path" "$module_dir/$path"
done < "$ROOT_DIR/tools/module-files.txt"

if [ -n "${RCLONE_BIN:-}" ]; then
  [ -f "$RCLONE_BIN" ] || { printf 'RCLONE_BIN does not exist: %s\n' "$RCLONE_BIN" >&2; exit 1; }
  cp "$RCLONE_BIN" "$module_dir/rclone"
else
  archive_path="$CACHE_DIR/$RCLONE_ARCHIVE"
  if [ ! -f "$archive_path" ] || ! verify_sha256 "$RCLONE_ARCHIVE_SHA256" "$archive_path"; then
    curl -fL --retry 3 --retry-delay 2 -o "$archive_path.tmp" "$RCLONE_URL"
    verify_sha256 "$RCLONE_ARCHIVE_SHA256" "$archive_path.tmp"
    mv "$archive_path.tmp" "$archive_path"
  fi
  unzip -q "$archive_path" -d "$STAGE_DIR/rclone-extract"
  cp "$STAGE_DIR/rclone-extract/rclone-v${RCLONE_VERSION}-linux-arm64/rclone" "$module_dir/rclone"
fi
cp "$ROOT_DIR/vendor/arm64-v8a/fusermount3" "$module_dir/fusermount3"
cp "$ROOT_DIR/vendor/arm64-v8a/libandroid-support.so" "$module_dir/libandroid-support.so"

chmod 0755 "$module_dir"/*.sh "$module_dir/rclone" "$module_dir/fusermount3" "$module_dir"/web/cgi-bin/*
chmod 0644 "$module_dir/module.prop" "$module_dir/libandroid-support.so"

output="$DIST_DIR/nas-photos-mount-v${VERSION}.zip"
(cd "$module_dir" && zip -qr9 "$output" .)
unzip -tq "$output"

if command -v sha256sum >/dev/null 2>&1; then
  output_hash=$(sha256sum "$output" | awk '{print $1}')
else
  output_hash=$(shasum -a 256 "$output" | awk '{print $1}')
fi
printf '%s  %s\n' "$output_hash" "$(basename "$output")" > "$output.sha256"

printf '%s\n' "$output"
