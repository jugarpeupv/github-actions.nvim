# github-actions.nvim

A Neovim plugin for GitHub Actions integration.

## Features

- Parse GitHub Actions workflow files using Treesitter
- Check action versions against latest releases using GitHub CLI
- Display version information with virtual text
- Configurable icons and highlights
- Asynchronous version checking
- Smart caching: First check fetches from API, subsequent checks use cache
- Auto-check on buffer save (instant updates with cache)

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
    require('github-actions').setup({
      virtual_text = {
        prefix = ' ',
        suffix = '',
        icons = {
          outdated = ' ',
          latest = ' ',
        },
      },
    })
  end,
}
```

## Usage

### Manual Version Check

```lua
-- Check versions for current buffer (uses cache for fast results)
:lua require('github-actions').check_versions()

-- Clear version cache (forces fresh API calls on next check)
:lua require('github-actions').clear_cache()
```

### Automatic Version Check

You can set up an autocommand to check versions automatically:

```lua
vim.api.nvim_create_autocmd('BufEnter', {
  pattern = '*.yml',
  callback = function()
    local bufnr = vim.api.nvim_get_current_buf()
    local filepath = vim.api.nvim_buf_get_name(bufnr)
    if filepath:match('%.github/workflows/') then
      require('github-actions').check_versions()
    end
  end,
})
```

### Configuration

The plugin supports the following configuration options:

```lua
require('github-actions').setup({
  virtual_text = {
    prefix = ' ',           -- Prefix before version text
    suffix = '',            -- Suffix after version text
    icons = {
      outdated = ' ',      -- Icon for outdated versions
      latest = ' ',        -- Icon for latest versions
    },
    highlight = 'Comment',                        -- Default highlight group
    highlight_latest = 'GitHubActionsVersionLatest',      -- Highlight for latest
    highlight_outdated = 'GitHubActionsVersionOutdated',  -- Highlight for outdated
    highlight_icon_latest = 'GitHubActionsIconLatest',
    highlight_icon_outdated = 'GitHubActionsIconOutdated',
  },
})
```

### Highlight Groups

The plugin defines custom highlight groups that you can customize:

```lua
-- Example: customize colors (default colors shown)
vim.api.nvim_set_hl(0, 'GitHubActionsVersionLatest', { fg = '#10d981' })   -- Green
vim.api.nvim_set_hl(0, 'GitHubActionsVersionOutdated', { fg = '#a855f7' }) -- Purple
vim.api.nvim_set_hl(0, 'GitHubActionsIconLatest', { fg = '#10d981' })
vim.api.nvim_set_hl(0, 'GitHubActionsIconOutdated', { fg = '#a855f7' })
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

### Manual Testing

To test the plugin during development:

```bash
# 1. Make sure gh CLI is installed
gh --version

# 2. Open a workflow file with the dev config
nvim -u dev.lua .github/workflows/test.yml

# 3. In Neovim, use the keymaps:
#    <leader>gc - Check versions (shows virtual text)
#    <leader>gC - Clear virtual text

# Or run directly:
:lua require('github-actions').check_versions()
```

The plugin will:
1. Parse the workflow file using treesitter
2. Fetch latest versions from GitHub API using `gh` CLI
3. Display version info as virtual text at the end of each line
4. Show 📌 icon for latest versions
5. Show 📦 icon for outdated versions

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
