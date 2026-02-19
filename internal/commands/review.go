// Package commands contains one type per CLI command.
// Each type has a single Execute method — Single Responsibility Principle (SRP).
// Commands receive their dependencies through constructors — Dependency
// Inversion Principle (DIP) — so they can be tested without real gh/git calls.
package commands

import (
	"fmt"

	"github.com/mayurathavale18/pr-manager/internal/config"
	"github.com/mayurathavale18/pr-manager/internal/gh"
	"github.com/mayurathavale18/pr-manager/internal/output"
)

// ReviewCommand approves a GitHub pull request.
// It depends only on the gh.Client and output.Printer interfaces (DIP/ISP),
// making it straightforward to test with mocks.
type ReviewCommand struct {
	client  gh.Client
	printer output.Printer
	opts    *config.Options
}

// NewReviewCommand constructs a ReviewCommand with all its dependencies.
// Constructor injection is the idiomatic Go way of implementing DIP.
func NewReviewCommand(client gh.Client, printer output.Printer, opts *config.Options) *ReviewCommand {
	return &ReviewCommand{client: client, printer: printer, opts: opts}
}

// Execute runs the full review workflow for prNumber:
//  1. Validate environment (gh installed, inside git repo, authenticated)
//  2. Fetch PR info and check it is OPEN
//  3. Skip if already approved; ask for confirmation unless --auto
//  4. Approve the PR
func (r *ReviewCommand) Execute(prNumber int) error {
	r.printer.Header("PR Review")

	// --- Environment pre-flight ---
	// In Go, errors are values.  We check each step with an if-err pattern
	// rather than exceptions, making control flow explicit and readable.
	if err := r.client.CheckGHInstalled(); err != nil {
		return err
	}
	if err := r.client.CheckGitRepo(); err != nil {
		return err
	}
	if err := r.client.CheckAuth(); err != nil {
		return err
	}

	// --- Fetch PR metadata ---
	r.printer.Info("Fetching PR #%d...", prNumber)
	pr, err := r.client.GetPR(prNumber)
	if err != nil {
		return err
	}

	r.printer.Verbose("Title:  %s", pr.Title)
	r.printer.Verbose("State:  %s", string(pr.State))
	r.printer.Verbose("Author: %s", pr.Author)
	r.printer.Verbose("URL:    %s", pr.URL)

	// --- Guard: PR must be open ---
	if pr.State != gh.PRStateOpen {
		return fmt.Errorf("PR #%d is not open (current state: %s)", prNumber, pr.State)
	}

	// --- Skip duplicate approvals ---
	approved, err := r.client.IsAlreadyApproved(prNumber)
	if err != nil {
		// Non-fatal: we warn and continue rather than aborting.
		r.printer.Warning("Could not check existing reviews: %v", err)
	}
	if approved {
		r.printer.Warning("PR #%d is already approved — skipping approval", prNumber)
		return nil
	}

	// --- Interactive confirmation (skipped in --auto mode) ---
	if !r.opts.Auto {
		if !r.printer.Confirm("Approve PR #%d (%q)?", prNumber, pr.Title) {
			r.printer.Info("Review cancelled by user")
			return nil
		}
	}

	// --- Approve ---
	r.printer.Info("Approving PR #%d...", prNumber)
	if err := r.client.ApprovePR(prNumber); err != nil {
		return err
	}

	r.printer.Success("PR #%d approved successfully", prNumber)
	return nil
}
