# pr-manager

A command-line tool written in Go for automating GitHub Pull Request review and merge workflows. It wraps the GitHub CLI (`gh`) to combine the approval and merge steps into a single, consistent command with safety checks built in.

## Prerequisites

- [GitHub CLI (`gh`)](https://cli.github.com/) installed and authenticated
- Git — must be run from inside a git repository
- Go 1.21+ — only required if building from source

### Authenticate with GitHub CLI

```bash
gh auth login
```

Select SSH when prompted to avoid repeated authentication prompts.

---

## Installation

If you want to install the latest release, [click here](https://github.com/mayurathavale18/pr-manager/releases/latest).

### Linux / macOS — one-liner (recommended)

```bash
curl -fsSL https://github.com/mayurathavale18/pr-manager/releases/latest/download/install.sh | sh
```

The script detects your OS and architecture, verifies the SHA-256 checksum, and installs
the binary to `/usr/local/bin` (when run as root) or `~/.local/bin` (regular user).

To pin a specific version instead of latest:

```bash
VERSION=v2.0.0 curl -fsSL https://github.com/mayurathavale18/pr-manager/releases/latest/download/install.sh | sh
```

### Linux / macOS — binary tarball (manual)

Download the archive for your platform from the [releases page](https://github.com/mayurathavale18/pr-manager/releases), extract, and place the binary on your `PATH`.

```bash
# Linux amd64 — replace <version> with the tag you want, e.g. v2.0.0
curl -LO https://github.com/mayurathavale18/pr-manager/releases/download/<version>/pr-manager-<version>-linux-amd64.tar.gz
tar -xzf pr-manager-<version>-linux-amd64.tar.gz
sudo mv pr-manager /usr/local/bin/

# macOS Apple Silicon (arm64)
curl -LO https://github.com/mayurathavale18/pr-manager/releases/download/<version>/pr-manager-<version>-darwin-arm64.tar.gz
tar -xzf pr-manager-<version>-darwin-arm64.tar.gz
sudo mv pr-manager /usr/local/bin/

# Verify
pr-manager --version
```

Available platform archives:

| File | Platform |
|------|----------|
| `pr-manager-<version>-linux-amd64.tar.gz` | Linux x86-64 |
| `pr-manager-<version>-linux-arm64.tar.gz` | Linux ARM64 (Raspberry Pi, AWS Graviton) |
| `pr-manager-<version>-darwin-amd64.tar.gz` | macOS Intel |
| `pr-manager-<version>-darwin-arm64.tar.gz` | macOS Apple Silicon |
| `pr-manager-<version>-windows-amd64.zip` | Windows x86-64 |

### Debian / Ubuntu — .deb package

```bash
# amd64
curl -LO https://github.com/mayurathavale18/pr-manager/releases/download/<version>/pr-manager_<version>_amd64.deb
sudo dpkg -i pr-manager_<version>_amd64.deb
sudo apt-get install -f    # resolve any missing dependencies

# arm64
curl -LO https://github.com/mayurathavale18/pr-manager/releases/download/<version>/pr-manager_<version>_arm64.deb
sudo dpkg -i pr-manager_<version>_arm64.deb

# Verify
pr-manager --version
```

To uninstall:

```bash
sudo apt remove pr-manager
```

### Windows

Download `pr-manager-<version>-windows-amd64.zip` from the [releases page](https://github.com/mayurathavale18/pr-manager/releases), extract the `.exe`, and add its directory to your `PATH`.

### Verify download integrity

Every release includes a `checksums.txt` with SHA-256 hashes for all assets.

```bash
sha256sum -c checksums.txt
```

---

## Building from source

Requires Go 1.21 or later.

```bash
git clone https://github.com/mayurathavale18/pr-manager.git
cd pr-manager

# Build for the current platform
make build              # output: dist/pr-manager

# Install to /usr/local/bin (or ~/.local/bin if not root)
make install

# Cross-compile for all supported platforms
make build-all          # output: dist/pr-manager-<os>-<arch>[.exe]

# Run tests
make test

# See all available targets
make help
```

---

## Usage

```
pr-manager <command> <PR_NUMBER> [flags]
```

### Commands

| Command | Description |
|---------|-------------|
| `review <PR_NUMBER>` | Approve the pull request |
| `merge <PR_NUMBER>` | Merge the pull request |
| `full <PR_NUMBER>` | Approve then merge (the default workflow) |

### Flags

| Flag | Short | Default | Description |
|------|-------|---------|-------------|
| `--auto` | `-a` | false | Skip all interactive prompts (CI-friendly) |
| `--verbose` | `-v` | false | Print extra diagnostic output |
| `--merge-method` | `-m` | `merge` | Merge strategy: `merge`, `squash`, `rebase`, `auto` |
| `--help` | `-h` | — | Show help for a command |
| `--version` | — | — | Print version and exit |

### Examples

```bash
# Full workflow — approve then merge PR #42 interactively
pr-manager full 42

# Full workflow non-interactively (for CI/CD)
pr-manager full 42 --auto

# Approve only
pr-manager review 42

# Merge only with squash strategy
pr-manager merge 42 --merge-method squash

# Auto squash-merge with verbose output
pr-manager merge 42 --auto --merge-method squash --verbose

# Rebase merge without prompts
pr-manager merge 42 -a -m rebase
```

---

## How it works

### The full workflow (step by step)

Running `pr-manager full 42` executes the following sequence:

1. **Environment checks** — confirms `gh` is installed, the working directory is a git repository, and `gh auth status` passes.
2. **Fetch PR metadata** — calls `gh pr view 42 --json ...` and maps the response to an internal `PRInfo` struct.
3. **Guard: PR must be OPEN** — if the PR is already merged or closed, the command exits with a clear error.
4. **Check existing approvals** — if an APPROVED review already exists, the approval step is skipped silently to prevent the GitHub "already approved" error.
5. **Approve** — calls `gh pr review 42 --approve`.
6. **Intermediate prompt** — unless `--auto` is set, asks "Proceed with merge?" so you can inspect CI status before merging.
7. **Conflict check** — if `mergeable == CONFLICTING`, exits with an error before attempting a merge that would fail.
8. **Merge** — calls `gh pr merge 42 --<method> --delete-branch=false`.

The `review` and `merge` commands run the same pre-flight checks independently, so they are also safe to call in isolation.

---

## Project structure

```
pr-manager/
├── cmd/
│   └── pr-manager/
│       └── main.go               entry point; Version injected via -ldflags
├── internal/
│   ├── cli/
│   │   └── app.go                cobra command tree; the only place concrete types are wired
│   ├── config/
│   │   └── config.go             Options struct and merge-method constants
│   ├── executor/
│   │   └── executor.go           Executor interface + OSExecutor (os/exec wrapper)
│   ├── gh/
│   │   ├── models.go             PRInfo domain type, PRState, Mergeable constants
│   │   ├── interfaces.go         EnvironmentChecker, PRFetcher, PRReviewer, PRMerger, Client
│   │   └── client.go             GHClient — concrete implementation using the gh CLI
│   ├── commands/
│   │   ├── review.go             ReviewCommand.Execute()
│   │   ├── merge.go              MergeCommand.Execute()
│   │   └── full.go               FullCommand.Execute() — composes review + merge
│   └── output/
│       └── printer.go            Printer interface + ConsolePrinter (ANSI colours)
├── packaging/
│   └── debian/
│       └── DEBIAN/               control, postinst, prerm, postrm
├── .github/
│   └── workflows/
│       └── release.yml           three-job CI: build, package-deb, release
├── go.mod
├── go.sum
├── Makefile
└── README.md
```

---

## Architecture — SOLID principles

The codebase is structured so that every design decision maps to one of the five SOLID principles. If you are learning Go, this section explains both *what* was done and *why*.

### S — Single Responsibility

Each type in `internal/` has exactly one job:

- `executor.OSExecutor` — runs shell commands, nothing else.
- `gh.GHClient` — translates Go method calls into `gh` CLI invocations.
- `commands.ReviewCommand` — orchestrates the approval workflow.
- `commands.MergeCommand` — orchestrates the merge workflow.
- `output.ConsolePrinter` — the only place that knows about ANSI colour codes.

No type crosses these boundaries. If you want to change how colours work, you touch `printer.go` alone.

### O — Open/Closed

`FullCommand` extends behaviour by *composing* `ReviewCommand` and `MergeCommand` logic without modifying either. Adding a future step — say, posting a Slack notification after a merge — means writing a new `NotifyCommand` and composing it inside `FullCommand`, not editing the existing commands.

### L — Liskov Substitution

Every command accepts `gh.Client` and `output.Printer` as interface parameters. You can substitute `GHClient` with a mock, a REST-API-based client, or a dry-run client, and the commands work identically. The substitution is transparent.

### I — Interface Segregation

`gh.Client` is defined as the *composition* of four small interfaces:

```
EnvironmentChecker  CheckGHInstalled, CheckGitRepo, CheckAuth
PRFetcher           GetPR
PRReviewer          IsAlreadyApproved, ApprovePR
PRMerger            MergePR
```

A command that only merges declares `gh.PRMerger` as its dependency, not the full `Client`. Tests mock only the methods they need.

### D — Dependency Inversion

High-level commands depend on *abstractions* (interfaces), never on concrete types directly. The concrete types — `executor.OSExecutor`, `gh.GHClient`, `output.ConsolePrinter` — are instantiated in exactly one place: `internal/cli/app.go`. This is called the *composition root*. Swapping the real executor for a fake one in tests requires changing nothing in the command layer.

---

## CI/CD — release pipeline

The release workflow (`.github/workflows/release.yml`) runs automatically when a version tag (`v*`) is pushed and produces the following assets:

| Job | What it does |
|-----|-------------|
| `build` | Cross-compiles for 5 platforms using a matrix; packages each as `.tar.gz` or `.zip` |
| `package-deb` | Compiles Linux binaries and wraps them in proper Debian packages for `amd64` and `arm64` |
| `release` | Collects all artifacts, generates `checksums.txt`, and publishes a GitHub Release |

To trigger a release:

```bash
git tag v2.1.0
git push origin v2.1.0
```

The pipeline uses `CGO_ENABLED=0` and `-trimpath` to produce fully static, reproducible binaries with no external C dependencies.

---

## Troubleshooting

**`gh` not found**

```bash
# Debian / Ubuntu
sudo apt install gh

# macOS
brew install gh

# Or follow https://cli.github.com/
```

**Not authenticated**

```bash
gh auth login
# Choose SSH for the authentication method
```

**PR not found**

Confirm you are inside the correct git repository and the PR number is valid:

```bash
gh pr view <PR_NUMBER>
```

**Merge conflict**

`pr-manager` detects conflicts before attempting a merge and exits with an error. Resolve the conflicts in the branch first, then re-run.

**Broken .deb dependencies**

```bash
sudo apt-get install -f
```

---

## Contributing

1. Fork the repository.
2. Create a feature branch off `master`.
3. Write your changes; run `make test` and `make lint` before committing.
4. Open a pull request against `master`.

---

## License

MIT License — Copyright (c) 2024 Mayur Athavale
