# Repository Guidelines

## Project Structure & Module Organization
- Root: GitHub Action metadata (`action.yml`), docs (`README.md`, `GEMINI.md`, this guide).
- `scripts/`: Core Bash utilities. `extract-plugins.sh` scans `teleid` files under the passed Zinit home directory to produce `github_repos.txt`; `check-plugins.sh` queries the GitHub API via `gh api` and surfaces annotations.
- `tests/`: `run-tests.sh` performs integration-style checks using fixture teleid files and a stubbed `gh` binary.
- `.github/workflows/`: Example CI, release, and self-check workflows suitable for downstream repositories.

## Build, Test, and Development Commands
- `./scripts/extract-plugins.sh "$HOME/.local/share/zinit" github_repos.txt`: Reads all `teleid` files under the configured Zinit home and writes normalized `owner/repo` pairs.
- `./scripts/check-plugins.sh github_repos.txt check-results.json`: Consumes the repo list, hits the GitHub API, and emits JSON plus GitHub annotations.
- `./tests/run-tests.sh`: End-to-end validation; automatically sets up fixture teleid directories and a fake `gh` binary so runs stay deterministic.

## Coding Style & Naming Conventions
- Shell scripts use `#!/usr/bin/env bash`, `set -Eeuo pipefail`, two-space indentation, and descriptive variable names (e.g., `found_files`, `TMP_OUTPUT`).
- Prefer POSIX-friendly tooling (`awk`, `sed`, `jq`) and keep pipelines readable. Add brief comments only when intent is non-obvious.
- Environment variables are UPPER_SNAKE_CASE (`IGNORE_PLUGINS`, `GITHUB_TOKEN`). Temporary outputs (e.g., `github_repos.txt`, `check-results.json`) live in the working directory.

## Testing Guidelines
- Tests are Bash-based; no external framework. Keep fixtures inside `tests/` and clean up temporary files after each block.
- Extend `tests/run-tests.sh` by following the existing arrange/run/assert pattern: prepare inputs, execute the script, diff against expected output, and fail fast on mismatches.
- Mock GitHub responses via the fake `gh` shim so new tests do not require network access.

## Commit & Pull Request Guidelines
- Write imperative commit subjects focused on the change scope (e.g., `Switch extraction to teleid scan`).
- Pull requests should state the motivation, summarize script/doc updates, and list verification steps (usually `./tests/run-tests.sh`). Link related issues and include log samples if annotations change behavior.
