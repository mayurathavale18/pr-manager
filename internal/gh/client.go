package gh

import (
	"encoding/json"
	"fmt"
	"strconv"
	"strings"

	"github.com/mayurathavale18/pr-manager/internal/executor"
)

// GHClient is the production implementation of Client.
// It shells out to the GitHub CLI (gh) for every operation.
//
// Dependency Inversion Principle (DIP): GHClient depends on the
// executor.Executor *interface*, not on os/exec directly.  Swap in a
// FakeExecutor and every method becomes unit-testable without a real GitHub
// account or network connection.
type GHClient struct {
	exec executor.Executor
}

// NewGHClient constructs a GHClient with the given executor.
// The constructor pattern is idiomatic Go dependency injection.
func NewGHClient(exec executor.Executor) *GHClient {
	return &GHClient{exec: exec}
}

// ---------------------------------------------------------------------------
// EnvironmentChecker implementation
// ---------------------------------------------------------------------------

// CheckGHInstalled confirms that the gh binary is on the PATH.
func (c *GHClient) CheckGHInstalled() error {
	if _, err := c.exec.Execute("gh", "version"); err != nil {
		return fmt.Errorf("GitHub CLI (gh) is not installed or not in PATH\n" +
			"Install from: https://cli.github.com/")
	}
	return nil
}

// CheckGitRepo confirms the working directory is inside a git repository.
func (c *GHClient) CheckGitRepo() error {
	if _, err := c.exec.Execute("git", "rev-parse", "--git-dir"); err != nil {
		return fmt.Errorf("not inside a git repository — please run from your project root")
	}
	return nil
}

// CheckAuth confirms the gh CLI has a valid GitHub authentication token.
func (c *GHClient) CheckAuth() error {
	if _, err := c.exec.Execute("gh", "auth", "status"); err != nil {
		return fmt.Errorf("not authenticated with GitHub CLI\nRun: gh auth login")
	}
	return nil
}

// ---------------------------------------------------------------------------
// PRFetcher implementation
// ---------------------------------------------------------------------------

// prJSON is an unexported struct used only for JSON unmarshalling.
// Keeping it unexported enforces that callers use PRInfo, the domain type.
type prJSON struct {
	Number    int    `json:"number"`
	Title     string `json:"title"`
	State     string `json:"state"`
	URL       string `json:"url"`
	Mergeable string `json:"mergeable"`
	Author    struct {
		Login string `json:"login"`
	} `json:"author"`
}

// GetPR fetches PR metadata from GitHub and maps it to the PRInfo domain type.
func (c *GHClient) GetPR(prNumber int) (*PRInfo, error) {
	out, err := c.exec.Execute("gh", "pr", "view", strconv.Itoa(prNumber),
		"--json", "number,title,state,url,mergeable,author")
	if err != nil {
		return nil, fmt.Errorf("PR #%d not found or inaccessible: %w", prNumber, err)
	}

	var data prJSON
	if err := json.Unmarshal([]byte(out), &data); err != nil {
		return nil, fmt.Errorf("failed to parse PR response: %w", err)
	}

	return &PRInfo{
		Number:    data.Number,
		Title:     data.Title,
		State:     PRState(strings.ToUpper(data.State)),
		URL:       data.URL,
		Author:    data.Author.Login,
		Mergeable: data.Mergeable,
	}, nil
}

// ---------------------------------------------------------------------------
// PRReviewer implementation
// ---------------------------------------------------------------------------

// IsAlreadyApproved returns true when the authenticated user already submitted
// an APPROVED review for the given PR.
func (c *GHClient) IsAlreadyApproved(prNumber int) (bool, error) {
	out, err := c.exec.Execute("gh", "pr", "view", strconv.Itoa(prNumber),
		"--json", "reviews")
	if err != nil {
		return false, fmt.Errorf("failed to fetch reviews for PR #%d: %w", prNumber, err)
	}
	// Simple string check — avoids a second JSON parse for a common fast path.
	return strings.Contains(out, `"state":"APPROVED"`) ||
		strings.Contains(out, `"state": "APPROVED"`), nil
}

// ApprovePR submits an approving review for the PR.
func (c *GHClient) ApprovePR(prNumber int) error {
	if _, err := c.exec.Execute("gh", "pr", "review", strconv.Itoa(prNumber), "--approve"); err != nil {
		return fmt.Errorf("failed to approve PR #%d: %w", prNumber, err)
	}
	return nil
}

// ---------------------------------------------------------------------------
// PRMerger implementation
// ---------------------------------------------------------------------------

// MergePR merges the PR using the specified method.
// Valid methods: merge, squash, rebase, auto.  Any unknown value falls back to
// --merge so the tool never silently does nothing.
func (c *GHClient) MergePR(prNumber int, method string) error {
	args := []string{"pr", "merge", strconv.Itoa(prNumber), "--delete-branch=false"}

	switch method {
	case "squash":
		args = append(args, "--squash")
	case "rebase":
		args = append(args, "--rebase")
	case "auto":
		args = append(args, "--auto")
	default: // "merge" or unrecognised
		args = append(args, "--merge")
	}

	if _, err := c.exec.Execute("gh", args...); err != nil {
		return fmt.Errorf("failed to merge PR #%d: %w", prNumber, err)
	}
	return nil
}
