// Command pr-manager is the entry point for the pr-manager CLI tool.
//
// Version is injected at link time using:
//
//	go build -ldflags="-X main.Version=v1.2.3" ./cmd/pr-manager/
//
// The default value "dev" is used for local builds without a version tag.
package main

import (
	"fmt"
	"os"

	"github.com/mayurathavale18/pr-manager/internal/cli"
)

// Version is set by the build pipeline via -ldflags.
// Keeping it in main (not in a library package) is idiomatic Go: libraries
// should not embed their own version; only the binary knows its version.
var Version = "dev"

func main() {
	app := cli.New(Version)
	if err := app.Run(); err != nil {
		// cobra already prints usage for user errors; we just need the
		// message for application-level errors.
		fmt.Fprintf(os.Stderr, "\n\033[31m[ERROR]\033[0m   %v\n", err)
		os.Exit(1)
	}
}
