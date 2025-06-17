# PR Review and Merge Script

A comprehensive bash script for reviewing and merging GitHub Pull Requests using the GitHub CLI. This script streamlines the PR workflow by combining review approval and merge operations into a single command.

## Prerequisites

- **GitHub CLI (`gh`)**: Install from [https://cli.github.com/](https://cli.github.com/)
- **Git repository**: Must be run from within a git repository
- **SSH Authentication**: Ensure you're authenticated with GitHub using SSH keys to avoid redundant auth prompts

### Setup Authentication

```bash
# Login to GitHub CLI
gh auth login

# Make sure to select SSH when prompted for authentication method
```

## Installation

Choose one of the following installation methods:

### Method 1: .deb Package Installation (Recommended for Debian/Ubuntu)

1. Download the latest `.deb` package from the [releases page](https://github.com/your-repo/pr-script/releases)

2. Install using `dpkg`:
```bash
sudo dpkg -i pr-script_1.0.0_all.deb
```

3. If there are dependency issues, resolve them:
```bash
sudo apt-get install -f
```

4. Verify installation:
```bash
pr-script --help
```

**Benefits of .deb installation:**
- Automatic dependency management
- System-wide availability
- Easy uninstallation with `sudo apt remove pr-script`
- Integration with system package manager
- Automatic man page installation

### Method 2: Makefile Installation

1. Clone the repository:
```bash
git clone https://github.com/your-repo/pr-script.git
cd pr-script
```

2. Install using Makefile:
```bash
# Install system-wide (requires sudo)
sudo make install

# Or install to user directory
make install PREFIX=$HOME/.local
```

3. Verify installation:
```bash
pr-script --help
```

**Makefile targets:**
- `make install` - Install the script system-wide
- `make uninstall` - Remove the script from system
- `make build-deb` - Build .deb package
- `make clean` - Clean build artifacts
- `make test` - Run tests (if available)

### Method 3: Manual Installation

1. Download the script directly:
```bash
wget https://raw.githubusercontent.com/your-repo/pr-script/main/src/pr-script.sh
# or
curl -O https://raw.githubusercontent.com/your-repo/pr-script/main/src/pr-script.sh
```

2. Make it executable:
```bash
chmod +x pr-script.sh
```

3. (Optional) Move to PATH for global access:
```bash
sudo mv pr-script.sh /usr/local/bin/pr-script
```

### Method 4: Build from Source

1. Clone and build:
```bash
git clone https://github.com/your-repo/pr-script.git
cd pr-script
make build-deb
sudo dpkg -i packaging/pr-script_*.deb
```

## Usage

```bash
pr-script <COMMAND> <PR_NUMBER> [OPTIONS]
```

### Commands

| Command | Description |
|---------|-------------|
| `review <PR_NUMBER>` | Review and approve the PR |
| `merge <PR_NUMBER>` | Merge the PR (with safety checks) |
| `full <PR_NUMBER>` | Review and merge the PR (default) |
| `<PR_NUMBER>` | Same as `full` (backward compatibility) |

### Options

| Option | Short | Description |
|--------|-------|-------------|
| `--auto` | `-a` | Enable auto mode (skip interactive prompts) |
| `--verbose` | `-v` | Enable verbose output with detailed logs |
| `--quiet` | `-q` | Enable detailed output (same as verbose) |
| `--merge-method` | `-m` | Set merge method (`auto`, `merge`, `squash`, `rebase`) |
| `--help` | `-h` | Show help message |

## Examples

### Basic Usage
```bash
# Review and merge PR #123 (interactive mode)
pr-script 123

# Review and merge PR #123 (same as above)
pr-script full 123

# Only review PR #123
pr-script review 123

# Only merge PR #123
pr-script merge 123
```

### Advanced Usage
```bash
# Auto merge with squash method and verbose output
pr-script merge 123 --auto --verbose --merge-method squash

# Review with detailed logs
pr-script review 123 --verbose

# Auto merge using rebase method
pr-script merge 123 -a -m rebase

# Full workflow with auto mode and verbose output
pr-script full 123 -a -v
```

## Features

### Safety Checks
- Validates PR number format (numeric only)
- Checks if running in a git repository
- Verifies GitHub CLI installation and authentication
- Confirms PR exists and is in OPEN state
- Detects merge conflicts before attempting merge
- Checks if PR is already approved (skips duplicate approval)

### Interactive Mode
- Prompts for confirmation before merging
- Shows review status and allows manual review
- Provides option to cancel operations at any step

### Auto Mode
- Non-interactive execution for automation
- Perfect for CI/CD pipelines
- Combines with verbose mode for detailed logging

### Merge Methods
- `auto`: GitHub's default merge method
- `merge`: Standard merge commit
- `squash`: Squash and merge all commits
- `rebase`: Rebase and merge

## Workflow

### Full Workflow (`full` command)
1. **Review Phase**:
   - Checks if PR exists
   - Checks if already approved (skips if yes)
   - Approves the PR using `gh pr review -a`
   - Waits for user confirmation (unless auto mode)

2. **Merge Phase**:
   - Validates PR state (must be OPEN)
   - Checks for merge conflicts
   - Confirms merge with user (unless auto mode)
   - Executes merge with specified method
   - Provides success/failure feedback

## Uninstallation

### .deb Package Uninstallation
```bash
sudo apt remove pr-script
```

### Makefile Uninstallation
```bash
# If installed system-wide
sudo make uninstall

# If installed to user directory
make uninstall PREFIX=$HOME/.local
```

### Manual Uninstallation
```bash
sudo rm /usr/local/bin/pr-script
```

## Error Handling

The script includes comprehensive error handling for common scenarios:

- **Invalid PR numbers**: Must be numeric
- **Non-existent PRs**: Validates PR exists before operations
- **Authentication issues**: Checks GitHub CLI auth status
- **Repository context**: Ensures running in a git repository
- **Merge conflicts**: Detects and reports conflicts
- **Closed PRs**: Prevents operations on non-open PRs

## Customization

### Repository-Specific Usage
While the script is designed to work with any GitHub repository, you can customize it for your specific repo by:

1. Hardcoding the repository URL
2. Setting default merge methods
3. Adding custom validation rules
4. Implementing organization-specific workflows

### Colored Output
The script uses colored output for better readability:
- <span style="color: red"><b>Red</b></span>: Errors and failures
- <span style="color: green"><b>Green</b></span>: Success messages
- <span style="color: yellow"><b>Yellow</b></span>: Warnings and prompts
- <span style="color: blue"><b>Blue</b></span>: Information and status updates

## Development

### Building the Project

```bash
# Build .deb package
make build-deb

# Install development dependencies
make dev-setup

# Run tests
make test

# Clean build artifacts
make clean
```

### Project Structure

```
pr-script/
├── src/
│   └── pr-script.sh                 # Main script
├── packaging/
│   ├── debian/                      # Debian package files
│   ├── build-deb.sh                # Build script for .deb
│   ├── create-binary-release.sh    # Binary release script
│   └── install.sh                  # Installation script
├── .github/
│   └── workflows/
│       └── release.yml              # CI/CD pipeline
├── README.md                        # This file
├── LICENSE                          # MIT License
└── Makefile                         # Build automation
```

## Troubleshooting

### Common Issues

**GitHub CLI not found**:
```bash
# Install GitHub CLI
sudo apt install gh  # Ubuntu/Debian
brew install gh       # macOS
```

**Authentication failed**:
```bash
# Re-authenticate with SSH
gh auth login
# Select SSH when prompted
```

**Permission denied**:
```bash
# For .deb installation
sudo dpkg -i pr-script_*.deb

# For manual installation
chmod +x pr-script.sh
```

**PR not found**:
- Verify PR number is correct
- Ensure you're in the correct repository
- Check if PR exists and is accessible

**Package installation failed**:
```bash
# Fix broken dependencies
sudo apt-get install -f

# Force reinstall
sudo dpkg -i --force-overwrite pr-script_*.deb
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly using `make test`
5. Build and test the .deb package
6. Submit a pull request

## License

This script is provided as-is under the MIT License. Feel free to modify and distribute according to your needs.

## Support

For issues, questions, or feature requests, please:
1. Check the troubleshooting section
2. Review GitHub CLI documentation
3. Open an issue in the repository
4. Ensure you're using the latest version of the script

---

License 📄
MIT © Mayur Athavale
