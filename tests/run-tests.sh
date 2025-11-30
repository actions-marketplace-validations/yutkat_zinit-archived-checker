#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$SCRIPT_DIR"

# Ensure scripts are executable
chmod +x "$REPO_ROOT/scripts/check-plugins.sh" "$REPO_ROOT/scripts/extract-plugins.sh"

# -------------------------------------------------------------------
# Test extract-plugins.sh via ZINIT_HOME_DIR teleid files
# -------------------------------------------------------------------

ZINIT_HOME_DIR="$SCRIPT_DIR/zinit_home"
mkdir -p "$ZINIT_HOME_DIR/plugins/foo" "$ZINIT_HOME_DIR/snippets"

cat <<'EOF' >"$ZINIT_HOME_DIR/plugins/foo/teleid"
https://github.com/foo/bar.git
/tmp/local-plugin
EOF
printf 'baz/qux\n' >"$ZINIT_HOME_DIR/snippets/another.teleid"
printf 'other-user/sample-plugin' >"$ZINIT_HOME_DIR/teleid"

cat <<'EOF' >expected_github_repos.txt
baz/qux
foo/bar
other-user/sample-plugin
EOF

"$REPO_ROOT/scripts/extract-plugins.sh" "$ZINIT_HOME_DIR" "$SCRIPT_DIR/github_repos_home.txt"

DIFF_OUTPUT="$(diff -u expected_github_repos.txt github_repos_home.txt || true)"
if [ -n "$DIFF_OUTPUT" ]; then
  echo "❌ extract-plugins.sh (ZINIT_HOME_DIR) did not produce expected output"
  echo "$DIFF_OUTPUT"
  exit 1
else
  echo "✅ extract-plugins.sh (ZINIT_HOME_DIR) produced expected output"
fi

rm -rf "$ZINIT_HOME_DIR" expected_github_repos.txt github_repos_home.txt

# -------------------------------------------------------------------
# Test check-plugins.sh against known repositories
# -------------------------------------------------------------------

cat <<EOF >github_repos.txt
jose-elias-alvarez/null-ls.nvim
test-user/this-repo-does-not-exist-12345
glepnir/lspsaga.nvim
jose-elias-alvarez/typescript.nvim
folke/lazy.nvim
EOF

# Setup environment
export IGNORE_PLUGINS="jose-elias-alvarez/typescript.nvim"

# Provide a fake gh binary so tests do not hit the real API
FAKE_BIN_DIR="$SCRIPT_DIR/fake-bin"
mkdir -p "$FAKE_BIN_DIR"
OLD_PATH="$PATH"
cat <<'EOF' >"$FAKE_BIN_DIR/gh"
#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ] || [ "$1" != "api" ]; then
  echo "Unsupported gh invocation" >&2
  exit 1
fi

case "$2" in
  /repos/jose-elias-alvarez/null-ls.nvim)
    cat <<'JSON'
{
  "full_name": "jose-elias-alvarez/null-ls.nvim",
  "archived": true
}
JSON
    ;;
  /repos/test-user/this-repo-does-not-exist-12345)
    cat <<'JSON'
{
  "message": "Not Found"
}
JSON
    ;;
  /repos/glepnir/lspsaga.nvim)
    cat <<'JSON'
{
  "full_name": "nvimdev/lspsaga.nvim",
  "archived": false
}
JSON
    ;;
  /repos/folke/lazy.nvim)
    cat <<'JSON'
{
  "full_name": "folke/lazy.nvim",
  "archived": false
}
JSON
    ;;
  *)
    cat <<'JSON'
{}
JSON
    ;;
esac
EOF
chmod +x "$FAKE_BIN_DIR/gh"
export PATH="$FAKE_BIN_DIR:$PATH"

echo "Running check-plugins.sh with dummy data..."
# Run the script (expecting exit code 1 due to issues found)
"$REPO_ROOT/scripts/check-plugins.sh" "github_repos.txt" "results.json" || true

# Verify outputs
echo "Verifying results..."

get_output() {
  jq -r ".$1" results.json
}

ARCHIVED=$(jq -c '."archived_plugins"' results.json)
DELETED=$(jq -c '."deleted_plugins"' results.json)
MOVED=$(jq -c '."moved_plugins"' results.json)
HAS_ISSUES=$(get_output "has_issues")

echo "Archived Output: $ARCHIVED"
echo "Deleted Output: $DELETED"
echo "Moved Output: $MOVED"

FAILED=0

# Check Archived (null-ls should be there)
if echo "$ARCHIVED" | grep -q "jose-elias-alvarez/null-ls.nvim"; then
  echo "✅ null-ls.nvim detected as archived"
else
  echo "❌ FAIL: null-ls.nvim NOT detected as archived"
  FAILED=1
fi

# Check Ignored (typescript.nvim should NOT be there)
if echo "$ARCHIVED" | grep -q "jose-elias-alvarez/typescript.nvim"; then
  echo "❌ FAIL: typescript.nvim should be ignored but was detected"
  FAILED=1
else
  echo "✅ typescript.nvim correctly ignored"
fi

# Check Deleted
if echo "$DELETED" | grep -q "test-user/this-repo-does-not-exist-12345"; then
  echo "✅ Non-existent repo detected as deleted"
else
  echo "❌ FAIL: Non-existent repo NOT detected as deleted"
  FAILED=1
fi

# Check Moved (glepnir/lspsaga.nvim -> nvimdev/lspsaga.nvim)
if echo "$MOVED" | grep -q "glepnir/lspsaga.nvim"; then
  echo "✅ lspsaga.nvim detected as moved"
else
  echo "❌ FAIL: lspsaga.nvim NOT detected as moved"
  FAILED=1
fi

# Check Has Issues
if [ "$HAS_ISSUES" == "true" ]; then
  echo "✅ has-issues is true"
else
  echo "❌ FAIL: has-issues is not true"
  FAILED=1
fi

rm "github_repos.txt" "results.json"
rm -rf "$FAKE_BIN_DIR"
PATH="$OLD_PATH"

if [ $FAILED -eq 0 ]; then
  echo "🎉 ALL TESTS PASSED"
  exit 0
else
  echo "💥 SOME TESTS FAILED"
  exit 1
fi
