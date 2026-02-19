// Package config holds the shared configuration options for the application.
// Keeping all options in one place is the Single Responsibility Principle (SRP)
// applied at the package level: this package's one job is "hold config".
package config

// Options holds all runtime flags parsed from the CLI.
// It is passed into commands via dependency injection rather than via globals,
// making each command independently testable.
type Options struct {
	Auto        bool   // -a / --auto  : skip interactive prompts
	Verbose     bool   // -v / --verbose: print extra diagnostic output
	MergeMethod string // -m / --merge-method: merge | squash | rebase | auto
}

// Merge method constants so callers never use raw strings.
const (
	MergeMethodMerge  = "merge"
	MergeMethodSquash = "squash"
	MergeMethodRebase = "rebase"
	MergeMethodAuto   = "auto"

	DefaultMergeMethod = MergeMethodMerge
)

// ValidMergeMethods is the set of accepted values for --merge-method.
// Using a map gives O(1) lookup and makes it easy to add new methods later.
var ValidMergeMethods = map[string]bool{
	MergeMethodMerge:  true,
	MergeMethodSquash: true,
	MergeMethodRebase: true,
	MergeMethodAuto:   true,
}
