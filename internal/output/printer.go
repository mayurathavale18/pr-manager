// Package output handles all terminal output for the application.
//
// Single Responsibility Principle (SRP): this is the *only* package that
// knows about ANSI escape codes, color logic, and user prompts.
// Commands never call fmt.Println directly — they call the Printer.
package output

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"strings"
)

// ANSI escape codes for terminal colors.
// These are ignored on terminals that don't support them (Windows CMD, etc.)
// but work on every modern Unix terminal and Windows Terminal.
const (
	colorReset  = "\033[0m"
	colorRed    = "\033[31m"
	colorGreen  = "\033[32m"
	colorYellow = "\033[33m"
	colorBlue   = "\033[34m"
	colorCyan   = "\033[36m"
	colorBold   = "\033[1m"
)

// Printer is the interface that commands depend on for output.
//
// Interface Segregation Principle (ISP): if a future command only needs
// Info/Error (no prompts), it can accept a narrower interface.
// Using an interface also lets tests inject a silent or recording printer.
type Printer interface {
	Info(format string, args ...interface{})
	Success(format string, args ...interface{})
	Warning(format string, args ...interface{})
	Error(format string, args ...interface{})
	Verbose(format string, args ...interface{})
	Header(format string, args ...interface{})
	// Confirm shows a [y/N] prompt and returns true if the user confirmed.
	Confirm(format string, args ...interface{}) bool
}

// ConsolePrinter writes colored output to stdout/stderr.
// It satisfies the Printer interface.
type ConsolePrinter struct {
	verbose bool
	out     io.Writer // normal output (stdout)
	errOut  io.Writer // error output (stderr)
	in      io.Reader // input for prompts (stdin)
}

// New returns a ConsolePrinter ready to use.
// Pass verbose=true to enable Verbose() output.
func New(verbose bool) *ConsolePrinter {
	return &ConsolePrinter{
		verbose: verbose,
		out:     os.Stdout,
		errOut:  os.Stderr,
		in:      os.Stdin,
	}
}

func (p *ConsolePrinter) Info(format string, args ...interface{}) {
	fmt.Fprintf(p.out, colorBlue+"[INFO]"+colorReset+"    %s\n", fmt.Sprintf(format, args...))
}

func (p *ConsolePrinter) Success(format string, args ...interface{}) {
	fmt.Fprintf(p.out, colorGreen+"[SUCCESS]"+colorReset+" %s\n", fmt.Sprintf(format, args...))
}

func (p *ConsolePrinter) Warning(format string, args ...interface{}) {
	fmt.Fprintf(p.out, colorYellow+"[WARNING]"+colorReset+" %s\n", fmt.Sprintf(format, args...))
}

func (p *ConsolePrinter) Error(format string, args ...interface{}) {
	fmt.Fprintf(p.errOut, colorRed+"[ERROR]"+colorReset+"   %s\n", fmt.Sprintf(format, args...))
}

func (p *ConsolePrinter) Verbose(format string, args ...interface{}) {
	if p.verbose {
		fmt.Fprintf(p.out, colorCyan+"[DEBUG]"+colorReset+"   %s\n", fmt.Sprintf(format, args...))
	}
}

func (p *ConsolePrinter) Header(format string, args ...interface{}) {
	msg := fmt.Sprintf(format, args...)
	fmt.Fprintf(p.out, "\n%s%s=== %s ===%s\n\n", colorBold, colorBlue, msg, colorReset)
}

// Confirm prints a [y/N] prompt and reads a line from stdin.
// Returns true only when the user types "y" or "yes" (case-insensitive).
func (p *ConsolePrinter) Confirm(format string, args ...interface{}) bool {
	msg := fmt.Sprintf(format, args...)
	fmt.Fprintf(p.out, colorYellow+"%s"+colorReset+" [y/N]: ", msg)

	scanner := bufio.NewScanner(p.in)
	if scanner.Scan() {
		resp := strings.ToLower(strings.TrimSpace(scanner.Text()))
		return resp == "y" || resp == "yes"
	}
	return false
}
