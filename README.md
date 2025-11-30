# Zinit Archived Plugin Checker

A GitHub Action that verifies whether the repositories backing your [Zinit](https://github.com/zdharma-continuum/zinit) plugins are still active.

## Features

- Reads plugin metadata directly from existing Zinit installations by scanning their `teleid` files (provide the directory via the `zinit-home-dir` input)
- Ignores `teleid` entries that point to absolute filesystem paths, focusing the check on GitHub repositories only
- Detects archived, deleted, and moved repositories via the GitHub API
- Surfaces issues with GitHub Actions annotations (warnings for archived/moved, errors for deleted)
- Exposes machine-readable JSON outputs for downstream workflow steps

## Requirements

- A prepared Zinit installation directory (the action reads its `teleid` files). Set the `zinit-home-dir` input to point at this path.
- `zsh` with `zinit` available on the runner if you need to populate/refresh that directory ahead of time.
- GitHub CLI (`gh`) and `jq`. They are preinstalled on GitHub-hosted runners.

## Usage

### Basic workflow

```yaml
name: Check Zinit Plugins

on:
  schedule:
    - cron: "0 9 * * 1" # Every Monday at 09:00 UTC
  workflow_dispatch:

permissions:
  contents: read

jobs:
  check-zinit-plugins:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout dotfiles
        uses: actions/checkout@v6
        with:
          repository: your-username/dotfiles
          path: dotfiles

      - name: Install required packages
        run: sudo apt-get update && sudo apt-get install -y git zsh

      - name: Prepare zinit environment
        run: |
          zsh -ic '
            source ~/.zshrc
            exit 0
          '
        env:
          HOME: ${{ github.workspace }}/dotfiles
          TERM: "screen-256color"

      - name: Check plugins
        uses: yutkat/zinit-archived-checker@v1
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          zinit-home-dir: your-zinit-home
```

### Inputs

| Input            | Description                                                                                 | Required | Default               |
| ---------------- | ------------------------------------------------------------------------------------------- | -------- | --------------------- |
| `github-token`   | GitHub token used for API requests                                                          | No       | `${{ github.token }}` |
| `ignore-plugins` | List of plugins to ignore (newline or comma separated)                                      | No       | `""`                  |
| `zinit-home-dir` | Path to your Zinit installation; plugins are read from `teleid` files under this directory. | Yes      | —                     |

### Outputs

| Output             | Description                          |
| ------------------ | ------------------------------------ |
| `archived-plugins` | JSON array of archived repositories  |
| `deleted-plugins`  | JSON array of deleted repositories   |
| `moved-plugins`    | JSON array of moved repositories     |
| `has-issues`       | Boolean flag indicating any findings |

## How It Works

1. Runs `scripts/extract-plugins.sh`, which walks all `teleid` files under the provided Zinit home directory and writes `github_repos.txt`.
2. `scripts/check-plugins.sh` calls the GitHub API through `gh api` for each repository, checking deletion, archive status, and repository renames.
3. Issues are surfaced via GitHub Actions annotations and collected into `check-results.json` for downstream use.
