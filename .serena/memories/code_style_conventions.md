# Code Style and Conventions

## Language: Lua

## Formatting (StyLua)
Configuration in `stylua.toml`:
- **Column width**: 120 characters
- **Line endings**: Unix
- **Indent type**: Spaces
- **Indent width**: 2 spaces
- **Quote style**: AutoPreferSingle (prefer single quotes)
- **Call parentheses**: Always (always use parentheses for function calls)
- **Sort requires**: Disabled

## Linting (Luacheck)
Configuration in `.luacheckrc`:
- **Read globals**: `vim` (Neovim API)
- **Ignored warnings**:
  - `212` - Unused argument

## Naming Conventions
Based on observed code structure:
- **Module naming**: Use `M` as the module table variable
- **File organization**: 
  - Main module exports via `M` table
  - Helper functions as local module methods
- **Function naming**: snake_case (e.g., `check_versions`, `fetch_latest_tag`)

## Module Structure
Standard Lua module pattern:
```lua
local M = {}

-- Local dependencies
local dep = require('module')

-- Local functions/config
local config = {}

-- Public API functions
function M.public_function()
  -- implementation
end

return M
```

## Code Organization
- Separate concerns into different modules (parser, checker, display, github, cache)
- Use lib/ directory for shared utilities (highlights, semver)
- Keep workflow-specific logic in workflow/ subdirectory
