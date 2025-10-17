# Suggested Commands

## Testing
```bash
# Run all tests (includes dependency installation)
make test

# Run specific test file
make test-file FILE=spec/parser_spec.lua

# Install test dependencies
make install-deps

# Install nvim-treesitter for tests
make install-parser
```

## Linting
```bash
# Run luacheck linter
make lint
```

## Formatting
```bash
# Format code with StyLua
make format

# Check formatting without modifying files
make check
```

## Development
```bash
# Direct luarocks commands
eval $(./luarocks path --no-bin) && ./luarocks test
./luarocks busted spec/some_spec.lua
```

## System Commands (macOS/Darwin)
Standard Unix commands are available:
- `ls`, `cd`, `grep`, `find`, `cat`, `git`, etc.
- macOS-specific: `pbcopy`, `pbpaste`, `open`

## GitHub CLI
The plugin relies on `gh` CLI:
```bash
# Check if gh is available
gh --version

# Authenticate gh
gh auth login
```
