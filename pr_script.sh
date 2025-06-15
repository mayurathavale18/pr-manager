
#!/usr/bin/env bash

# A bash script to review and merge PRs from github repo.
# You just need to have github cli installed.
# This one is specific to my repo but it can be reused for any repository just by changing the github url.
# One more thing : Make sure, you are authenticating using ssh-key and have storign the key in your system to avoid
# redundent auth promps from github cli

# PR Review and Merge Script
# Usage: ./pr_script.sh <COMMAND> <PR_NUMBER> [OPTIONS]
# Commands: review, merge, full (default)

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <COMMAND> <PR_NUMBER> [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  review <PR_NUMBER>      Review PR (show info and diff)"
    echo "  merge <PR_NUMBER>       Merge PR (with checks)"
    echo "  full <PR_NUMBER>        Review and merge PR (default behavior)"
    echo "  <PR_NUMBER>             Same as 'full' (backward compatibility)"
    echo ""
    echo "Options:"
    echo "  --auto, -a              Enable auto mode (skip interactive prompts)"
    echo "  --verbose, -v           Enable verbose output with detailed logs"
    echo "  --quiet, -q             Enable detailed output (same as verbose)"
    echo "  --merge-method, -m      Set merge method (auto, merge, squash, rebase)"
    echo "  --help, -h              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 review 123           # Review PR #123"
    echo "  $0 merge 123            # Merge PR #123"
    echo "  $0 full 123             # Review and merge PR #123"
    echo "  $0 123                  # Same as 'full 123' (backward compatibility)"
    echo "  $0 review 123 --verbose # Review with detailed logs"
    echo "  $0 merge 123 --auto     # Auto merge without prompts"
    echo "  $0 merge 123 -a -v -m squash  # Auto squash merge with logs"
}

# Function to check if PR number is provided
check_pr_number() {
    if [ -z "$1" ]; then
        print_status $RED "Error: PR number is required"
        show_usage
        exit 1
    fi
    
    # Check if PR number is numeric
    if ! [[ "$1" =~ ^[0-9]+$ ]]; then
        print_status $RED "Error: PR number must be numeric"
        exit 1
    fi
}

# Function to check if we're in a git repository
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_status $RED "Error: Not in a git repository"
        exit 1
    fi
}

# Function to check if GitHub CLI is installed
check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        print_status $RED "Error: GitHub CLI (gh) is not installed"
        echo "Please install it from: https://cli.github.com/"
        exit 1
    fi
    
    # Check if user is authenticated
    if ! gh auth status &> /dev/null; then
        print_status $RED "Error: Not authenticated with GitHub CLI"
        echo "Please run: gh auth login"
        exit 1
    fi
}

# Function to review PR
approve_pr() {
    local pr_number=$1
    local skip_interactive=${2:-false}
    local verbose=${3:-false}
    
    if [ "$verbose" = true ]; then
        print_status $BLUE "Starting PR review for #${pr_number}..."
    fi
    
    # Check if PR exists
    if ! gh pr view "$pr_number" &> /dev/null; then
        print_status $RED "Error: PR #${pr_number} not found"
        return 1
    fi
    
    # Check if PR already approved :
    if gh pr view "${pr_number}" --json latestReviews --jq '.latestReviews[] | select(.state == "APPROVED")' | grep -q .; then
	    print_status $RED "PR already approved, can proceed to merge..."
    else 
	    gh pr review -a "${pr_number}"
    fi
    
    # Interactive review prompt (unless in auto mode)
    if [ "$skip_interactive" = false ]; then
        echo
        print_status $YELLOW "Review completed. Press Enter to continue..."
        read -r
    fi
    
    if [ "$verbose" = true ]; then
        print_status $GREEN "PR review completed for #${pr_number}"
    fi
    
    return 0
}

# Function to merge PR
merge_pr() {
    local pr_number=$1
    local merge_method=${2:-"auto"}  # Default to auto merge
    local skip_interactive=${3:-false}
    local verbose=${4:-false}
    
    if [ "$verbose" = true ]; then
        print_status $BLUE "Starting merge process for PR #${pr_number}..."
    fi
    
    # Check PR status before merging
    local pr_state=$(gh pr view "$pr_number" --json state --jq '.state')
    if [ "$pr_state" != "OPEN" ]; then
        print_status $RED "Error: PR #${pr_number} is not open (current state: ${pr_state})"
        return 1
    fi
    
    # Check if PR has any merge conflicts
    local mergeable=$(gh pr view "$pr_number" --json mergeable --jq '.mergeable')
    if [ "$mergeable" = "CONFLICTING" ]; then
        print_status $RED "Error: PR #${pr_number} has merge conflicts"
        return 1
    fi
    
    # Confirmation prompt for merge (unless in auto mode)
    if [ "$skip_interactive" = false ]; then
        print_status $YELLOW "Are you sure you want to merge PR #${pr_number}? (y/N)"
        read -r response
        case "$response" in
            [yY]|[yY][eE][sS])
                ;;
            *)
                print_status $YELLOW "Merge cancelled by user"
                return 1
                ;;
        esac
    fi
    
    # Perform the merge
    if [ "$verbose" = true ]; then
        print_status $BLUE "Merging PR #${pr_number} using ${merge_method} method..."
    fi
    
    case "$merge_method" in
        "merge")
            merge_flag="--merge"
            ;;
        "rebase")
            merge_flag="--rebase"
            ;;
        "squash")
            merge_flag="--squash"
            ;;
        "auto")
            merge_flag="--auto"
            ;;
        *)
            merge_flag="--auto"
            merge_method="auto"
            ;;
    esac
    
    if gh pr merge "$pr_number" $merge_flag; then
	    print_status $GREEN "Successfully merged PR #${pr_number} using ${merge_method} method"
	    if [ "$verbose" = true ]; then
		    print_status $GREEN "Branch has been deleted"
		    print_status $BLUE "Updating local main branch..."
	    fi
	    return 0
    else
        print_status $RED "Error: Failed to merge PR #${pr_number}"
        return 1
    fi
}

# Function to do full review and merge
full_workflow() {
    local pr_number=$1
    local merge_method=${2:-"auto"}
    local skip_interactive=${3:-false}
    local verbose=${4:-false}
    
    # Approve the PR first
    if approve_pr "$pr_number" "$skip_interactive" "$verbose"; then
        # Ask if user wants to proceed with merge (unless in auto mode)
        if ! [ "$skip_interactive" = false ]; then
            echo
            print_status $YELLOW "Do you want to proceed with merge? (y/N)"
            read -r response
            case "$response" in
                [yY]|[yY][eE][sS])
                    ;;
                *)
                    print_status $YELLOW "Merge cancelled by user"
                    return 0
                    ;;
            esac
        fi
        
        # Proceed with merge
        if merge_pr "$pr_number" "$merge_method" "$skip_interactive" "$verbose"; then
            print_status $GREEN "PR #${pr_number} has been successfully reviewed and merged!"
        else
            print_status $RED "Failed to merge PR #${pr_number}"
            return 1
        fi
    else
        if [ "$verbose" = true ]; then
            print_status $YELLOW "PR review process stopped"
        else
            print_status $YELLOW "PR review cancelled"
        fi
        return 1
    fi
}

# Main function
main() {
    local command=""
    local pr_number=""
    local merge_method="auto"
    local skip_interactive=false
    local verbose=false
    
    # Parse arguments
    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi
    
    # Check if first argument is a command or PR number
    case "$1" in
	    approve|merge|full)
		    command="$1"
		    shift
		    ;;
	    [0-9]*)
		    # Backward compatibility: if first arg is a number, treat as PR number with 'full' command
		    command="full"
		    ;;
	    --help|-h)
		    show_usage
		    exit 0
		    ;;
	    *)
		    print_status $RED "Unknown command: $1"
		    show_usage
		    exit 1
		    ;;
    esac

    # Parse remaining flags
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto|-a)
                skip_interactive=true
                shift
                ;;
            --verbose|-v)
                verbose=true
                shift
                ;;
            --quiet|-q)
                verbose=true
                shift
                ;;
            --merge-method|-m)
                merge_method="$2"
                shift 2
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            -*)
                print_status $RED "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
            *)
                if [ -z "$pr_number" ]; then
                    pr_number=$1
                fi
                shift
                ;;
        esac
    done
    
    # Perform initial checks
    check_pr_number "$pr_number"
    check_git_repo
    check_gh_cli
    
    if [ "$verbose" = true ]; then
        print_status $GREEN "Running '$command' command for PR #${pr_number}"
        if [ "$skip_interactive" = true ]; then
            print_status $GREEN "Mode: Auto (non-interactive) with verbose output"
        else
            print_status $GREEN "Mode: Interactive with verbose output"
        fi
    fi
    
    # Execute the appropriate command
    case "$command" in
        approve)
            if approve_pr "$pr_number" "$skip_interactive" "$verbose"; then
                print_status $GREEN "PR #${pr_number} review completed!"
            else
                print_status $RED "PR review failed"
                exit 1
            fi
            ;;
        merge)
            if merge_pr "$pr_number" "$merge_method" "$skip_interactive" "$verbose"; then
                print_status $GREEN "PR #${pr_number} merged successfully!"
            else
                print_status $RED "PR merge failed"
                exit 1
            fi
            ;;
        full)
            full_workflow "$pr_number" "$merge_method" "$skip_interactive" "$verbose"
            ;;
    esac
}

# Script execution starts here
main "$@"
