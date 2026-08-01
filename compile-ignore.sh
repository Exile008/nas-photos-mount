#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/lib.sh"

INPUT=${1:-$SETTINGS_DIR/ignore.syncthing}
OUTPUT=${2:-$STATE_DIR/exclude.rclone}
CASE_MARKER=${3:-$STATE_DIR/ignore-case}
TEMP_OUTPUT="$OUTPUT.new.$$"

: > "$TEMP_OUTPUT" || exit 1
rm -f "$CASE_MARKER"

while IFS= read -r rule || [ -n "$rule" ]; do
  rule=$(printf '%s' "$rule" | sed 's/\r$//; s/^[[:space:]]*//; s/[[:space:]]*$//')
  case "$rule" in
    ''|'#'*) continue ;;
  esac

  while true; do
    case "$rule" in
      '(?d)'*) rule=${rule#'(?d)'} ;;
      '(?i)'*)
        rule=${rule#'(?i)'}
        : > "$CASE_MARKER"
        ;;
      *) break ;;
    esac
  done

  case "$rule" in
    '#'* ) rule="[#]${rule#'#'}" ;;
  esac
  if [ -n "$rule" ]; then
    case "$rule" in
      /*)
        printf '%s\n' "$rule" "$rule/**" >> "$TEMP_OUTPUT"
        ;;
      *)
        printf '%s\n' "$rule" "$rule/**" "**/$rule" "**/$rule/**" >> "$TEMP_OUTPUT"
        ;;
    esac
  fi
done < "$INPUT"

mv "$TEMP_OUTPUT" "$OUTPUT"
chmod 0600 "$OUTPUT"
[ -e "$CASE_MARKER" ] && chmod 0600 "$CASE_MARKER"
exit 0
