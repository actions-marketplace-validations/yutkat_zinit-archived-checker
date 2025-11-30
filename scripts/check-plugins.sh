#!/usr/bin/env bash

set -Eeuo pipefail

if [ "$#" -eq 0 ]; then
  echo "Error: No input file specified. Usage: $0 <github_repos_file>"
  exit 1
fi

GITHUB_REPOS_FILE="$1"

archived_plugins=()
deleted_plugins=()
moved_plugins=()
has_issues=false

# Parse ignore list
ignore_list=""
if [ -n "${IGNORE_PLUGINS:-}" ]; then
  # Replace commas with newlines, trim whitespace
  ignore_list=$(echo "$IGNORE_PLUGINS" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
fi

echo "Checking plugin status..."

while IFS= read -r repo; do
  if [ -z "$repo" ]; then
    continue
  fi

  # Check if plugin is ignored
  if echo "$ignore_list" | grep -Fxq "$repo"; then
    echo "  ⏭️ IGNORED: $repo"
    continue
  fi

  echo "Checking: $repo"

  # Use GitHub API to check repository status
  response=$(gh api /repos/"$repo" || true)

  # Check if repository exists
  if echo "$response" | jq -e '.message == "Not Found"' >/dev/null 2>&1; then
    echo "  ❌ DELETED: $repo"
    echo "::error file=$repo::[DELETED] This plugin repository has been deleted"
    deleted_plugins+=("$repo")
    has_issues=true
    continue
  fi

  # Check for moves/renames
  full_name=$(echo "$response" | jq -r '.full_name')

  # Case-insensitive comparison
  repo_lower=$(echo "$repo" | tr '[:upper:]' '[:lower:]')
  full_name_lower=$(echo "$full_name" | tr '[:upper:]' '[:lower:]')

  if [ "$repo_lower" != "$full_name_lower" ]; then
    echo "  ➡️ MOVED: $repo -> $full_name"
    echo "::warning file=$repo::[MOVED] This plugin has moved to $full_name"
    # Store as JSON object string
    moved_plugins+=("{\"old\": \"$repo\", \"new\": \"$full_name\"}")
    has_issues=true
  fi

  # Check if repository is archived
  is_archived=$(echo "$response" | jq -r '.archived // false')

  if [ "$is_archived" = "true" ]; then
    echo "  📦 ARCHIVED: $repo"
    echo "::warning file=$repo::[ARCHIVED] This plugin is archived and no longer maintained"
    archived_plugins+=("$repo")
    has_issues=true
  else
    if [ "$repo_lower" == "$full_name_lower" ]; then
      echo "  ✅ OK: $repo"
    fi
  fi

  # Rate limiting: sleep briefly between requests
  sleep 0.5
done <"$GITHUB_REPOS_FILE"

OUTPUT_FILE="${2:-check-results.json}"

# Output results as JSON arrays
if [ ${#archived_plugins[@]} -eq 0 ]; then
  archived_json="[]"
else
  archived_json=$(printf '%s\n' "${archived_plugins[@]}" | jq -R . | jq -s .)
fi

if [ ${#deleted_plugins[@]} -eq 0 ]; then
  deleted_json="[]"
else
  deleted_json=$(printf '%s\n' "${deleted_plugins[@]}" | jq -R . | jq -s .)
fi

if [ ${#moved_plugins[@]} -eq 0 ]; then
  moved_json="[]"
else
  moved_json=$(printf '%s\n' "${moved_plugins[@]}" | jq -s .)
fi

# Write results to JSON file
jq -n \
  --argjson archived "$archived_json" \
  --argjson deleted "$deleted_json" \
  --argjson moved "$moved_json" \
  --argjson has_issues "$has_issues" \
  '{
    "archived_plugins": $archived,
    "deleted_plugins": $deleted,
    "moved_plugins": $moved,
    "has_issues": $has_issues
  }' >"$OUTPUT_FILE"

echo "Results written to $OUTPUT_FILE"

# Print summary
echo ""
echo "========================================"
echo "Summary:"
echo "  Archived: ${#archived_plugins[@]}"
echo "  Deleted: ${#deleted_plugins[@]}"
echo "  Moved: ${#moved_plugins[@]}"
echo "========================================"

if [ "$has_issues" = true ]; then
  exit 1
fi
