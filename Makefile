.PHONY: test test-file lint format check install-deps install-parser install-luarocks

# Setup nvim-treesitter for tests
install-parser:
	@echo "Setting up nvim-treesitter..."
	@if [ ! -d deps/nvim-treesitter ]; then \
		git clone --depth 1 https://github.com/nvim-treesitter/nvim-treesitter deps/nvim-treesitter; \
		echo "✓ nvim-treesitter cloned"; \
	else \
		echo "✓ nvim-treesitter already exists"; \
	fi

# Install test dependencies
install-deps: install-parser
	@echo "✓ Test dependencies ready"

# Run tests
test: install-deps
	eval $$(./luarocks path --no-bin) && ./luarocks test

# Run specific test file
test-file:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=spec/parser_spec.lua"; \
		exit 1; \
	fi
	./luarocks busted $(FILE)

# Check if luarocks is installed
install-luarocks:
	@if ! command -v luarocks >/dev/null 2>&1; then \
		echo "Error: luarocks is not installed."; \
		echo ""; \
		echo "Install luarocks:"; \
		echo "  macOS:  brew install luarocks"; \
		echo "  Linux:  sudo apt install luarocks"; \
		echo ""; \
		exit 1; \
	fi
	@echo "✓ luarocks is installed."

# Run linter (requires selene or luacheck)
lint:
	@if command -v selene >/dev/null 2>&1; then \
		selene lua/; \
	elif command -v luacheck >/dev/null 2>&1; then \
		luacheck lua/; \
	else \
		echo "No linter found. Install selene or luacheck."; \
		exit 1; \
	fi

# Format code (requires stylua)
format:
	@if command -v stylua >/dev/null 2>&1; then \
		stylua lua/ spec/; \
	else \
		echo "stylua not found. Install it with: cargo install stylua"; \
		exit 1; \
	fi

# Check formatting
check:
	@if command -v stylua >/dev/null 2>&1; then \
		stylua --check lua/ spec/; \
	else \
		echo "stylua not found. Install it with: cargo install stylua"; \
		exit 1; \
	fi
