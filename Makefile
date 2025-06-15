PACKAGE_NAME = pr-script
VERSION = 1.0.0
BUILD_DIR = packaging/build

.PHONY: all clean deb binary install uninstall test help

all: deb binary

help:
	@echo "Available targets:"
	@echo "  all      - Build both .deb package and binary release"
	@echo "  deb      - Build .deb package"
	@echo "  binary   - Build binary release"
	@echo "  install  - Install from source"
	@echo "  uninstall- Uninstall"
	@echo "  test     - Run tests"
	@echo "  clean    - Clean build artifacts"

deb:
	@echo "Building .deb package..."
	cd packaging && chmod +x build-deb.sh && ./build-deb.sh

binary:
	@echo "Building binary release..."
	cd packaging && chmod +x create-binary-release.sh && ./create-binary-release.sh

install:
	@echo "Installing pr-script..."
	@if [ "$(EUID)" -eq 0 ]; then \
		cp src/pr-script.sh /usr/local/bin/pr-script; \
		chmod +x /usr/local/bin/pr-script; \
		mkdir -p /usr/local/share/doc/pr-script; \
		cp README.md /usr/local/share/doc/pr-script/ 2>/dev/null || true; \
		echo "Installed system-wide to /usr/local/bin/pr-script"; \
	else \
		mkdir -p ~/.local/bin ~/.local/share/doc/pr-script; \
		cp src/pr-script.sh ~/.local/bin/pr-script; \
		chmod +x ~/.local/bin/pr-script; \
		cp README.md ~/.local/share/doc/pr-script/ 2>/dev/null || true; \
		echo "Installed to ~/.local/bin/pr-script"; \
		echo "Make sure ~/.local/bin is in your PATH"; \
	fi

uninstall:
	@echo "Uninstalling pr-script..."
	@if [ -f /usr/local/bin/pr-script ]; then \
		rm -f /usr/local/bin/pr-script; \
		rm -rf /usr/local/share/doc/pr-script; \
		echo "System-wide installation removed"; \
	elif [ -f ~/.local/bin/pr-script ]; then \
		rm -f ~/.local/bin/pr-script; \
		rm -rf ~/.local/share/doc/pr-script; \
		echo "User installation removed"; \
	else \
		echo "pr-script not found"; \
	fi

test:
	@echo "Running tests..."
	@if [ -f src/pr-script.sh ]; then \
		bash -n src/pr-script.sh && echo "✅ Syntax check passed"; \
	else \
		echo "❌ Script not found"; \
		exit 1; \
	fi
	@if [ -f $(BUILD_DIR)/pr-script_$(VERSION)_all.deb ]; then \
		dpkg-deb --info $(BUILD_DIR)/pr-script_$(VERSION)_all.deb > /dev/null && echo "✅ .deb package integrity check passed"; \
	fi

clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	@echo "✅ Clean completed"
