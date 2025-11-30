#!/usr/bin/env bash

set -Eeuo pipefail

# Usage: ./extract-plugins.sh <zinit_home_dir> [output_file]

if [ "$#" -lt 1 ]; then
  echo "Error: missing required zinit_home_dir argument" >&2
  exit 1
fi

ZINIT_HOME_DIR="$1"
shift

OUTPUT_FILE="${1:-github_repos.txt}"

TMP_OUTPUT="$(mktemp)"
trap 'rm -f "$TMP_OUTPUT"' EXIT

if [ ! -d "$ZINIT_HOME_DIR" ]; then
  echo "Error: ZINIT_HOME_DIR '$ZINIT_HOME_DIR' does not exist" >&2
  exit 1
fi

echo "Reading plugin metadata from $ZINIT_HOME_DIR..."
found_files=0
: >"$TMP_OUTPUT"
while IFS= read -r -d '' teleid_file; do
  found_files=1
  cat "$teleid_file" >>"$TMP_OUTPUT"
  printf '\n' >>"$TMP_OUTPUT"
done < <(find "$ZINIT_HOME_DIR" -type f -name '*teleid*' -print0)

if [ "$found_files" -eq 0 ]; then
  echo "Error: No teleid files found under $ZINIT_HOME_DIR" >&2
  exit 1
fi

# Normalise and filter the output (skip absolute file paths)
awk '{gsub(/^[[:space:]]+|[[:space:]]+$/, ""); if (length($0) > 0 && $0 !~ /^\//) print}' "$TMP_OUTPUT" |
  sed 's|^https://github.com/||' |
  sed 's|\.git$||' |
  LC_ALL=C sort -u >"$OUTPUT_FILE"

COUNT=$(wc -l <"$OUTPUT_FILE")
echo "Found $COUNT GitHub plugins"
cat "$OUTPUT_FILE"
echo ""
echo "Outputting to: $OUTPUT_FILE"
