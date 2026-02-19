// Package executor abstracts running external processes.
//
// Dependency Inversion Principle (DIP): higher-level packages (gh, commands)
// depend on the Executor *interface*, not on os/exec directly.  This means
// tests can inject a fake executor that returns canned output without ever
// spawning a real process.
package executor

import (
	"bytes"
	"os/exec"
	"strings"
)

// Executor is the interface that wraps a single shell-command invocation.
//
// Interface Segregation Principle (ISP): the interface is deliberately tiny
// (one method) so that any implementor — real, mock, or recording — only
// needs to satisfy this one contract.
type Executor interface {
	// Execute runs the named program with the given arguments and returns its
	// combined stdout output.  Any non-zero exit code is returned as an error
	// whose message contains the stderr text for easy debugging.
	Execute(name string, args ...string) (string, error)
}

// OSExecutor is the production Executor that delegates to the operating system.
// It satisfies the Executor interface via the Execute method below.
type OSExecutor struct{}

// New returns a ready-to-use OSExecutor.
// Returning the concrete type (not the interface) here is idiomatic Go:
// callers that need the interface accept it; the rest get the concrete value.
func New() *OSExecutor {
	return &OSExecutor{}
}

// Execute implements Executor.  It runs name with args, captures stdout, and
// collects stderr separately so it can be included in the error message.
func (e *OSExecutor) Execute(name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	if err != nil {
		// Prefer stderr for the error message; fall back to stdout if empty.
		msg := strings.TrimSpace(stderr.String())
		if msg == "" {
			msg = strings.TrimSpace(stdout.String())
		}
		return msg, err
	}

	return strings.TrimSpace(stdout.String()), nil
}
