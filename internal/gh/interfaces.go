package gh

// The interfaces below follow the Interface Segregation Principle (ISP):
// each interface is small and focused on one concern.  Commands import only
// the interface(s) they actually need, not a monolithic "GitHub" type.

// EnvironmentChecker verifies that all required tools are available and
// authenticated before any PR operation is attempted.
type EnvironmentChecker interface {
	CheckGHInstalled() error
	CheckGitRepo() error
	CheckAuth() error
}

// PRFetcher retrieves PR metadata from GitHub.
type PRFetcher interface {
	GetPR(prNumber int) (*PRInfo, error)
}

// PRReviewer handles the review/approval side of a PR workflow.
type PRReviewer interface {
	IsAlreadyApproved(prNumber int) (bool, error)
	ApprovePR(prNumber int) error
}

// PRMerger handles the merge side of a PR workflow.
type PRMerger interface {
	MergePR(prNumber int, method string) error
}

// Client composes all the above interfaces into a single dependency that
// commands can receive via constructor injection (Dependency Inversion, DIP).
//
// Liskov Substitution Principle (LSP): any type that fully implements Client
// can substitute GHClient — e.g. a mock for tests or a future REST-API client.
type Client interface {
	EnvironmentChecker
	PRFetcher
	PRReviewer
	PRMerger
}
