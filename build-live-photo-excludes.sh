#!/system/bin/sh

INPUT_PATHS=$1
OUTPUT_PATHS=$2
OUTPUT_FILTER=$3
BUSYBOX_BIN=${4:-}
TEMP_PATHS="$OUTPUT_PATHS.new.$$"
TEMP_FILTER="$OUTPUT_FILTER.new.$$"

cleanup() {
  rm -f "$TEMP_PATHS" "$TEMP_FILTER"
}
trap cleanup EXIT

run_awk() {
  if [ -n "$BUSYBOX_BIN" ]; then
    "$BUSYBOX_BIN" awk "$@"
  else
    awk "$@"
  fi
}

run_sort() {
  if [ -n "$BUSYBOX_BIN" ]; then
    "$BUSYBOX_BIN" sort "$@"
  else
    sort "$@"
  fi
}

run_awk '
  {
    path = $0
    lower = tolower(path)
    if (lower ~ /\.heic$/) {
      heic[substr(lower, 1, length(lower) - 5)] = 1
    } else if (lower ~ /\.mov$/) {
      mov_path[NR] = path
      mov_stem[NR] = substr(lower, 1, length(lower) - 4)
    }
  }
  END {
    for (line = 1; line <= NR; line++) {
      if (mov_stem[line] != "" && heic[mov_stem[line]]) print mov_path[line]
    }
  }
' "$INPUT_PATHS" | LC_ALL=C run_sort -u > "$TEMP_PATHS" || exit 1

run_awk '
  function escaped_pattern(path, output, position, char) {
    output = "/"
    for (position = 1; position <= length(path); position++) {
      char = substr(path, position, 1)
      if (char == "*" || char == "?" || char == "\\" || char == "[" || char == "]" || char == "{" || char == "}") output = output "\\"
      output = output char
    }
    return output
  }
  { print escaped_pattern($0) }
' "$TEMP_PATHS" > "$TEMP_FILTER" || exit 1

mv "$TEMP_PATHS" "$OUTPUT_PATHS"
mv "$TEMP_FILTER" "$OUTPUT_FILTER"
chmod 0600 "$OUTPUT_PATHS" "$OUTPUT_FILTER"
trap - EXIT
exit 0
