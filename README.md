GitHub PR Manager
https://img.shields.io/badge/License-MIT-yellow.svg
https://img.shields.io/badge/Shell_Script-4EAA25?style=flat&logo=gnu-bash&logoColor=white
https://img.shields.io/badge/GitHub_CLI-181717?style=flat&logo=github&logoColor=white

A powerful Bash script to streamline your GitHub pull request workflow with approval and merge capabilities.

Features ✨
One-command PR approval with automatic checks

Flexible merging with multiple merge methods

Interactive mode or fully automated for CI/CD

Safety checks for conflicts and CI status

Color-coded output for easy reading

Works with any repo using GitHub CLI

Installation ⚡
Prerequisites
GitHub CLI (gh) installed and authenticated

Bash 4.0+ (bash --version)

jq for JSON processing

Quick Install
bash
curl -L https://raw.githubusercontent.com/yourusername/pr-script/main/pr_script.sh -o /usr/local/bin/pr_script
chmod +x /usr/local/bin/pr_script
Usage 🛠️
Basic Commands
bash
# Approve PR 123 (with interactive prompts)
pr_script approve 123

# Merge PR 456 using squash method
pr_script merge 456 -m squash

# Full workflow: approve + merge PR 789
pr_script full 789
Advanced Options
Option	Description
-a, --auto	Skip all interactive prompts
-v, --verbose	Show detailed output
-m, --merge-method	Set merge method (merge/squash/rebase)
-h, --help	Show help message
Merge Methods
merge: Create a merge commit (default)

squash: Combine all commits into one

rebase: Rebase onto base branch

auto: Let GitHub decide

Examples 🚀
bash
# Approve PR 123 with verbose logging
pr_script approve 123 -v

# Auto-merge PR 456 using squash (no prompts)
pr_script merge 456 -a -m squash

# Check PR 789 status (no actions taken)
pr_script review 789
Safety Checks 🔒
The script automatically verifies:

PR exists and is open

No merge conflicts

GitHub CLI authentication

Valid PR number format

Git repository context

Contributing 🤝
Pull requests welcome! Please:

Fork the repository

Create a feature branch

Submit a PR with clear description

License 📄
MIT © Mayur Athavale
