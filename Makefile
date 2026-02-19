BINARY     := pr-manager
CMD        := ./cmd/pr-manager
BUILD_DIR  := dist
VERSION    ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
LDFLAGS    := -ldflags="-X main.Version=$(VERSION) -s -w" -trimpath

# Default target
.PHONY: all
all: build

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

.PHONY: build
build:                              ## Build the binary for the current platform
	@mkdir -p $(BUILD_DIR)
	go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY) $(CMD)
	@echo "Built: $(BUILD_DIR)/$(BINARY)  (version: $(VERSION))"

.PHONY: install
install: build                      ## Install binary to /usr/local/bin (or ~/.local/bin)
	@if [ "$(shell id -u)" -eq 0 ]; then \
		cp $(BUILD_DIR)/$(BINARY) /usr/local/bin/$(BINARY); \
		echo "Installed system-wide: /usr/local/bin/$(BINARY)"; \
	else \
		mkdir -p ~/.local/bin; \
		cp $(BUILD_DIR)/$(BINARY) ~/.local/bin/$(BINARY); \
		echo "Installed for current user: ~/.local/bin/$(BINARY)"; \
		echo "Make sure ~/.local/bin is in your PATH"; \
	fi

.PHONY: uninstall
uninstall:                          ## Remove installed binary
	@rm -f /usr/local/bin/$(BINARY) ~/.local/bin/$(BINARY)
	@echo "Uninstalled $(BINARY)"

# ---------------------------------------------------------------------------
# Cross-compilation (same targets the CI uses)
# ---------------------------------------------------------------------------

.PHONY: build-all
build-all:                          ## Build for all supported platforms
	@mkdir -p $(BUILD_DIR)
	GOOS=linux   GOARCH=amd64 CGO_ENABLED=0 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY)-linux-amd64   $(CMD)
	GOOS=linux   GOARCH=arm64 CGO_ENABLED=0 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY)-linux-arm64   $(CMD)
	GOOS=darwin  GOARCH=amd64 CGO_ENABLED=0 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY)-darwin-amd64  $(CMD)
	GOOS=darwin  GOARCH=arm64 CGO_ENABLED=0 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY)-darwin-arm64  $(CMD)
	GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY)-windows-amd64.exe $(CMD)
	@echo "Cross-compiled binaries are in $(BUILD_DIR)/"

# ---------------------------------------------------------------------------
# Quality
# ---------------------------------------------------------------------------

.PHONY: test
test:                               ## Run unit tests
	go test -v ./...

.PHONY: lint
lint:                               ## Run go vet (no extra tools needed)
	go vet ./...

.PHONY: fmt
fmt:                                ## Format all Go source files
	gofmt -w .

# ---------------------------------------------------------------------------
# Housekeeping
# ---------------------------------------------------------------------------

.PHONY: clean
clean:                              ## Remove build artefacts
	rm -rf $(BUILD_DIR)
	@echo "Cleaned $(BUILD_DIR)/"

.PHONY: help
help:                               ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
