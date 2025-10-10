# github-actions.nvim

A Neovim plugin for GitHub Actions integration.

## Features

- Parse GitHub Actions workflow files
- Display action versions with virtual text
- More features coming soon...

## Requirements

- Neovim 0.9+ with LuaJIT
- `gh` CLI (GitHub's official CLI)
- Treesitter YAML parser

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'skanehira/github-actions.nvim',
  dependencies = {
    'nvim-treesitter/nvim-treesitter',
  },
  config = function()
    require('github-actions').setup()
  end,
}
```

## Development

### Prerequisites

- Neovim 0.9+
- [luarocks](https://luarocks.org/)
- [stylua](https://github.com/JohnnyMorganz/StyLua) (for formatting)

### Setup

1. Clone the repository:
```bash
git clone https://github.com/skanehira/github-actions.nvim.git
cd github-actions.nvim
```

2. Install luarocks (if not already installed):
```bash
# macOS
brew install luarocks

# Ubuntu/Debian
sudo apt install luarocks
```

3. Initialize project-local luarocks:
```bash
luarocks init --lua-version=5.1
```

This creates:
- `./luarocks` - Wrapper script for project-local commands
- `.luarocks/` - Configuration directory
- `lua_modules/` - Local dependency installation directory

4. Install test dependencies:
```bash
luarocks install busted
luarocks install nlua
```

### Running Tests

```bash
# Run all tests
make test

# Run specific test file
make test-file FILE=spec/parser_spec.lua
```

Note: The first time you run tests, `make test` will:
1. Clone nvim-treesitter to `deps/nvim-treesitter/`
2. Install YAML parser to `deps/parsers/`
3. Run the tests

### Code Quality

```bash
# Format code
make format

# Check formatting
make check

# Run linter (requires selene or luacheck)
make lint
```

## Testing Infrastructure

This project uses:
- **luarocks** for dependency management
- **busted** as the test framework
- **nlua** to run tests with Neovim's Lua environment
- Project-local installation (lua_modules/) for test dependencies

The test setup ensures tests have access to Neovim APIs (like `vim.api`) while maintaining isolation from the user's Neovim configuration.

## License

MIT
