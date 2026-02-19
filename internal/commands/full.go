package commands

import (
	"fmt"

	"github.com/mayurathavale18/pr-manager/internal/config"
	"github.com/mayurathavale18/pr-manager/internal/gh"
	"github.com/mayurathavale18/pr-manager/internal/output"
)

// FullCommand orchestrates the complete review → merge workflow.
//
// Open/Closed Principle (OCP): FullCommand extends the behaviour of
// ReviewCommand and MergeCommand by *composing* them, not by modifying their
// source code.  Adding a new step (e.g. "notify Slack") would mean creating
// another composed struct, not touching ReviewCommand or MergeCommand.
type FullCommand struct {
	client  gh.Client
	printer output.Printer
	opts    *config.Options
}

// NewFullCommand constructs a FullCommand.
func NewFullCommand(client gh.Client, printer output.Printer, opts *config.Options) *FullCommand {
	return &FullCommand{client: client, printer: printer, opts: opts}
}

// Execute runs: env checks → fetch PR → approve (review) → merge.
// The environment is validated once; both sub-operations share that result.
func (f *FullCommand) Execute(prNumber int) error {
	f.printer.Header("Full PR Workflow (review + merge)")

	// --- Environment pre-flight (done once for the whole workflow) ---
	if err := f.client.CheckGHInstalled(); err != nil {
		return err
	}
	if err := f.client.CheckGitRepo(); err != nil {
		return err
	}
	if err := f.client.CheckAuth(); err != nil {
		return err
	}

	// --- Fetch PR info once; pass it to both sub-steps ---
	f.printer.Info("Fetching PR #%d...", prNumber)
	pr, err := f.client.GetPR(prNumber)
	if err != nil {
		return err
	}

	f.printer.Verbose("Title:     %s", pr.Title)
	f.printer.Verbose("State:     %s", string(pr.State))
	f.printer.Verbose("Author:    %s", pr.Author)
	f.printer.Verbose("Mergeable: %s", pr.Mergeable)

	if pr.State != gh.PRStateOpen {
		return fmt.Errorf("PR #%d is not open (current state: %s)", prNumber, pr.State)
	}

	// --- Step 1: Review ---
	if err := f.doReview(pr); err != nil {
		return err
	}

	// --- Intermediate confirmation (unless --auto) ---
	if !f.opts.Auto {
		if !f.printer.Confirm("Proceed with merge for PR #%d?", prNumber) {
			f.printer.Info("Merge cancelled by user")
			return nil
		}
	}

	// --- Step 2: Merge ---
	if err := f.doMerge(pr); err != nil {
		return err
	}

	f.printer.Success("Full workflow complete: PR #%d reviewed and merged", prNumber)
	return nil
}

// doReview handles only the approval logic (no env re-check, no PR re-fetch).
func (f *FullCommand) doReview(pr *gh.PRInfo) error {
	approved, err := f.client.IsAlreadyApproved(pr.Number)
	if err != nil {
		f.printer.Warning("Could not check existing reviews: %v", err)
	}
	if approved {
		f.printer.Warning("PR #%d is already approved — skipping approval", pr.Number)
		return nil
	}

	f.printer.Info("Approving PR #%d...", pr.Number)
	if err := f.client.ApprovePR(pr.Number); err != nil {
		return err
	}
	f.printer.Success("PR #%d approved", pr.Number)
	return nil
}

// doMerge handles only the merge logic (no env re-check, no PR re-fetch).
func (f *FullCommand) doMerge(pr *gh.PRInfo) error {
	if pr.Mergeable == gh.MergeableConflict {
		return fmt.Errorf("PR #%d has merge conflicts — resolve them before merging", pr.Number)
	}

	f.printer.Info("Merging PR #%d using %q method...", pr.Number, f.opts.MergeMethod)
	if err := f.client.MergePR(pr.Number, f.opts.MergeMethod); err != nil {
		return err
	}
	f.printer.Success("PR #%d merged", pr.Number)
	return nil
}
