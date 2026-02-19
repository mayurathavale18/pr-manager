// Package gh wraps the GitHub CLI (gh) for PR operations.
// All types and interfaces live here; the concrete client is in client.go.
package gh

// PRState represents the lifecycle state of a pull request as returned by the
// GitHub API.  Using a named string type (not a plain string) gives us type
// safety: a function accepting PRState can't accidentally receive "open".
type PRState string

const (
	PRStateOpen   PRState = "OPEN"
	PRStateClosed PRState = "CLOSED"
	PRStateMerged PRState = "MERGED"
)

// Mergeable mirrors the GitHub API's "mergeable" field.
const (
	MergeableYes        = "MERGEABLE"
	MergeableConflict   = "CONFLICTING"
	MergeableUnknown    = "UNKNOWN"
)

// PRInfo is the domain model for a pull request.
// Commands use this struct instead of parsing raw JSON themselves,
// which keeps the JSON-parsing concern inside the gh package (SRP).
type PRInfo struct {
	Number    int
	Title     string
	State     PRState
	URL       string
	Author    string
	Mergeable string
}
