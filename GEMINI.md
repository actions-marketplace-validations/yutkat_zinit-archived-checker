# Lazy.nvim Archived Plugin Checker

## Project Overview

This project is a **GitHub Action** designed to automatically check the status of Neovim plugins managed by the `lazy.nvim` package manager. It helps maintainers keep their Neovim configurations healthy by identifying:
*   **Archived** repositories (warnings).
*   **Deleted** repositories (errors).
*   **Moved/Renamed** repositories (warnings).

The core logic is implemented in Bash, leveraging the GitHub API and `jq` for JSON parsing.

## Key Files

*   **`action.yml`**: Defines the GitHub Action's inputs, outputs, and execution steps. This is the entry point for the Action.
*   **`scripts/check-plugins.sh`**: The main script that iterates through a list of GitHub repositories (`github_repos.txt`), queries the GitHub API, and reports their status.
*   **`scripts/extract-plugins.sh`**: Reads every `teleid` file under the provided Zinit home directory (passed as the first argument) to build `github_repos.txt`.
*   **`tests/run-tests.sh`**: An integration test script that mocks the plugin list and verifies that the `check-plugins.sh` script correctly identifies archived, deleted, and moved repositories.

## Building and Running

Since this is a Bash-based GitHub Action, there is no "build" step. However, you can run the logic locally or execute the tests.

### Prerequisites

*   `bash`
*   `gh` (GitHub CLI) - Required for interacting with the GitHub API.
*   `jq`
*   `nvim` (Neovim) - Required for extracting the plugin list (handled automatically in CI, but needed locally if running the extraction step).

### Running Locally

To simulate the check process locally:

1.  **Prepare a Repository List**: Create a file named `github_repos.txt` in the root directory containing a list of repositories to check (one per line, format: `owner/repo`).
    ```text
    folke/lazy.nvim
    jose-elias-alvarez/null-ls.nvim
    ```

2.  **Run the Script**: Execute the script with a valid GitHub token.
    ```bash
    export GITHUB_TOKEN="your_github_token"
    ./scripts/check-plugins.sh
    ```

### Running Tests

The project includes an integration test script in the `tests` directory.

```bash
cd tests
GITHUB_TOKEN="your_github_token" ./run-tests.sh
```

**Note:** The tests require a real GitHub token because they query the actual GitHub API to verify the status of known archived/deleted/moved repositories.

## Development Conventions

*   **Scripting**: The logic is written in standard Bash (`#!/usr/bin/env bash`).
*   **Error Handling**: Scripts use `set -Eeuo pipefail` for robust error handling.
*   **GitHub Actions Interface**:
    *   **Inputs**: Defined in `action.yml` (e.g., `nvim-config-path`, `ignore-plugins`).
    *   **Outputs**: Writes to `$GITHUB_OUTPUT` (e.g., `archived-plugins`, `deleted-plugins`).
    *   **Annotations**: Uses the `::warning file=...::` and `::error file=...::` syntax to create annotations in the GitHub Actions runner.
*   **Git Workflow**: Changes are typically committed directly to `main` or via Pull Requests. The `action.yml` points to the scripts in the repository, so changes are immediate for users referencing the `@main` branch.
