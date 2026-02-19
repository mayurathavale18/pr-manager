// Package cli wires all the application's components together and configures
// the cobra command tree.  This is the Composition Root — the single place
// where concrete types are created and injected into the commands that need them.
package cli

import (
	"fmt"
	"strconv"

	"github.com/spf13/cobra"

	"github.com/mayurathavale18/pr-manager/internal/commands"
	"github.com/mayurathavale18/pr-manager/internal/config"
	"github.com/mayurathavale18/pr-manager/internal/executor"
	"github.com/mayurathavale18/pr-manager/internal/gh"
	"github.com/mayurathavale18/pr-manager/internal/output"
)

// App holds the cobra root command and the shared options parsed from flags.
// It is the only place in the codebase that knows about concrete types
// (GHClient, OSExecutor, ConsolePrinter) — everything else depends on
// interfaces (DIP).
type App struct {
	opts    *config.Options
	rootCmd *cobra.Command
}

// New builds the cobra command tree and returns an App ready to run.
// version is injected at build time via -ldflags so releases display the
// correct version string.
func New(version string) *App {
	opts := &config.Options{
		MergeMethod: config.DefaultMergeMethod,
	}
	app := &App{opts: opts}
	app.rootCmd = app.buildRoot(version)
	return app
}

// Run executes the CLI.  cobra handles argument parsing, help text, error
// formatting, and exit codes.
func (a *App) Run() error {
	return a.rootCmd.Execute()
}

// buildRoot constructs the cobra.Command hierarchy.
func (a *App) buildRoot(version string) *cobra.Command {
	root := &cobra.Command{
		Use:     "pr-manager",
		Short:   "Automate GitHub PR review and merge workflows",
		Version: version,
		// SilenceUsage prevents cobra from printing the usage block on every
		// error — we only want it on missing-argument errors.
		SilenceUsage: true,
		// SilenceErrors lets us print errors ourselves in main.go so we can
		// add colour or structure without duplicating cobra's output.
		SilenceErrors: true,
	}

	// Persistent flags are available to every subcommand.
	// pflag (used by cobra) supports both short (-a) and long (--auto) forms.
	root.PersistentFlags().BoolVarP(&a.opts.Auto, "auto", "a", false,
		"skip all interactive prompts (useful for CI)")
	root.PersistentFlags().BoolVarP(&a.opts.Verbose, "verbose", "v", false,
		"print extra diagnostic information")
	root.PersistentFlags().StringVarP(&a.opts.MergeMethod, "merge-method", "m",
		config.DefaultMergeMethod, "merge strategy: merge | squash | rebase | auto")

	root.AddCommand(
		a.reviewCmd(),
		a.mergeCmd(),
		a.fullCmd(),
	)
	return root
}

// newDeps creates a fresh set of concrete dependencies.
// Called once per command invocation, not once per process, so that future
// config sources (env vars, config files) can be read here.
func (a *App) newDeps() (gh.Client, output.Printer) {
	exec := executor.New()
	client := gh.NewGHClient(exec)
	printer := output.New(a.opts.Verbose)
	return client, printer
}

// parsePR extracts and validates a PR number from cobra's positional args.
func parsePR(args []string) (int, error) {
	if len(args) == 0 {
		return 0, fmt.Errorf("PR number is required\nExample: pr-manager review 42")
	}
	n, err := strconv.Atoi(args[0])
	if err != nil || n <= 0 {
		return 0, fmt.Errorf("invalid PR number %q — must be a positive integer", args[0])
	}
	return n, nil
}

// validateMergeMethod returns an error when the --merge-method value is not
// one of the accepted options.  Cobra doesn't have a built-in "enum" flag
// type so we validate manually in PersistentPreRunE.
func validateMergeMethod(method string) error {
	if !config.ValidMergeMethods[method] {
		return fmt.Errorf("unknown merge method %q — choose one of: merge, squash, rebase, auto", method)
	}
	return nil
}

// ---------------------------------------------------------------------------
// Subcommand builders
// ---------------------------------------------------------------------------

func (a *App) reviewCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "review <PR_NUMBER>",
		Short: "Review (approve) a pull request",
		Long: `Approve the given pull request using the GitHub CLI.

The command skips approval silently if the PR is already approved,
preventing duplicate-review errors.`,
		Example: "  pr-manager review 42\n  pr-manager review 42 --auto",
		Args:    cobra.ExactArgs(1),
		RunE: func(cobraCmd *cobra.Command, args []string) error {
			prNum, err := parsePR(args)
			if err != nil {
				return err
			}
			client, printer := a.newDeps()
			return commands.NewReviewCommand(client, printer, a.opts).Execute(prNum)
		},
	}
}

func (a *App) mergeCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "merge <PR_NUMBER>",
		Short: "Merge a pull request",
		Long: `Merge the given pull request using the configured merge method.

Safety checks are performed before merging:
  - The PR must be in OPEN state.
  - The PR must not have unresolved merge conflicts.`,
		Example: "  pr-manager merge 42\n  pr-manager merge 42 --auto --merge-method squash",
		Args:    cobra.ExactArgs(1),
		RunE: func(cobraCmd *cobra.Command, args []string) error {
			if err := validateMergeMethod(a.opts.MergeMethod); err != nil {
				return err
			}
			prNum, err := parsePR(args)
			if err != nil {
				return err
			}
			client, printer := a.newDeps()
			return commands.NewMergeCommand(client, printer, a.opts).Execute(prNum)
		},
	}
}

func (a *App) fullCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "full <PR_NUMBER>",
		Short: "Review and merge a pull request (default workflow)",
		Long: `Approve then merge the given pull request in one step.

This is the recommended command for the typical PR workflow:
  1. Approve the PR (skipped if already approved).
  2. Ask for confirmation (unless --auto).
  3. Merge using the configured merge method.`,
		Example: "  pr-manager full 42\n  pr-manager full 42 --auto --merge-method squash",
		Args:    cobra.ExactArgs(1),
		RunE: func(cobraCmd *cobra.Command, args []string) error {
			if err := validateMergeMethod(a.opts.MergeMethod); err != nil {
				return err
			}
			prNum, err := parsePR(args)
			if err != nil {
				return err
			}
			client, printer := a.newDeps()
			return commands.NewFullCommand(client, printer, a.opts).Execute(prNum)
		},
	}
}
