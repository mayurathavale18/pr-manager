package commands

import (
	"fmt"

	"github.com/mayurathavale18/pr-manager/internal/config"
	"github.com/mayurathavale18/pr-manager/internal/gh"
	"github.com/mayurathavale18/pr-manager/internal/output"
)

// MergeCommand merges a GitHub pull request.
// Like ReviewCommand it depends only on interfaces (DIP), so the merge logic
// can be exercised in tests without a real GitHub connection.
type MergeCommand struct {
	client  gh.Client
	printer output.Printer
	opts    *config.Options
}

// NewMergeCommand constructs a MergeCommand with injected dependencies.
func NewMergeCommand(client gh.Client, printer output.Printer, opts *config.Options) *MergeCommand {
	return &MergeCommand{client: client, printer: printer, opts: opts}
}

// Execute runs the merge workflow for prNumber:
//  1. Validate environment
//  2. Fetch PR info; check it is OPEN and not CONFLICTING
//  3. Ask for confirmation unless --auto
//  4. Merge using the configured merge method
func (m *MergeCommand) Execute(prNumber int) error {
	m.printer.Header("PR Merge")

	if err := m.client.CheckGHInstalled(); err != nil {
		return err
	}
	if err := m.client.CheckGitRepo(); err != nil {
		return err
	}
	if err := m.client.CheckAuth(); err != nil {
		return err
	}

	m.printer.Info("Fetching PR #%d...", prNumber)
	pr, err := m.client.GetPR(prNumber)
	if err != nil {
		return err
	}

	m.printer.Verbose("Title:     %s", pr.Title)
	m.printer.Verbose("State:     %s", string(pr.State))
	m.printer.Verbose("Mergeable: %s", pr.Mergeable)

	if pr.State != gh.PRStateOpen {
		return fmt.Errorf("PR #%d is not open (current state: %s)", prNumber, pr.State)
	}

	if pr.Mergeable == gh.MergeableConflict {
		return fmt.Errorf("PR #%d has merge conflicts — resolve them before merging", prNumber)
	}

	if !m.opts.Auto {
		if !m.printer.Confirm("Merge PR #%d (%q) using %q method?", prNumber, pr.Title, m.opts.MergeMethod) {
			m.printer.Info("Merge cancelled by user")
			return nil
		}
	}

	m.printer.Info("Merging PR #%d using %q method...", prNumber, m.opts.MergeMethod)
	if err := m.client.MergePR(prNumber, m.opts.MergeMethod); err != nil {
		return err
	}

	m.printer.Success("PR #%d merged successfully", prNumber)
	return nil
}
