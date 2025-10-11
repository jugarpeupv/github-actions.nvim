# Virtual Text UI Module Design

## Overview

This module is responsible for displaying version information as virtual text in GitHub Actions workflow files. It maintains separation of concerns by accepting version data as input rather than fetching it directly from APIs.

## Architecture

### Module Structure

Based on `docs/design.md`:

```
lua/github-actions/
├── parser/
│   └── workflow.lua          # Already implemented
├── ui/
│   ├── virtual_text.lua      # New: Virtual text rendering
│   └── highlights.lua        # New: Highlight groups definition
└── gh/
    └── cli.lua               # Future: gh CLI wrapper
```

### Core Concepts

#### 1. Separation of Concerns

- **Parser**: Extracts action information from workflow files
- **UI**: Renders virtual text based on version data
- **gh CLI wrapper** (future): Fetches latest version information from GitHub API

#### 2. Data Flow

Based on `docs/design.md`:

```
Workflow Buffer (.github/workflows/*.yml)
    ↓
Parser (parser/workflow.lua)
    ↓
Action[] (owner, repo, version/hash, line, col)
    ↓
gh CLI wrapper (gh/cli.lua) - future
    ↓
VersionInfo[] (action metadata + latest version)
    ↓
UI Module (ui/virtual_text.lua)
    ↓
Virtual Text in Buffer
```

## Module Specification: `ui/virtual_text.lua`

### Purpose

Render virtual text annotations for GitHub Actions in workflow files, showing whether actions are up-to-date or have newer versions available.

### Data Types

```lua
---@class VersionInfo
---@field line number The 0-indexed line number in the buffer
---@field col number The 0-indexed column number in the buffer
---@field current_version? string The current version used (e.g., "v3", "main")
---@field current_hash? string The current commit hash if used
---@field latest_version? string The latest available version
---@field latest_hash? string The latest commit hash
---@field is_latest boolean Whether the current version is the latest
---@field error? string Error message if version check failed

---@class VirtualTextOptions
---@field prefix? string Prefix before version text (default: " ")
---@field suffix? string Suffix after version text (default: "")
---@field icons? table Icons for version status
---@field icons.outdated? string Icon for outdated version (default: "")
---@field icons.latest? string Icon for latest version (default: "")
---@field highlight? string Default highlight group (default: "Comment")
---@field highlight_latest? string Highlight for latest (default: "GitHubActionsVersionLatest")
---@field highlight_outdated? string Highlight for outdated (default: "GitHubActionsVersionOutdated")
---@field namespace? number Neovim namespace ID (auto-created if not provided)
```

### Public API

```lua
local M = {}

---Set virtual text for a single action in a buffer
---@param bufnr number Buffer number
---@param version_info VersionInfo Version information for the action
---@param opts? VirtualTextOptions Display options
function M.set_virtual_text(bufnr, version_info, opts)
end

---Set virtual text for multiple actions in a buffer
---@param bufnr number Buffer number
---@param version_infos VersionInfo[] List of version information
---@param opts? VirtualTextOptions Display options
function M.set_virtual_texts(bufnr, version_infos, opts)
end

---Clear all virtual text from a buffer
---@param bufnr number Buffer number
function M.clear_virtual_text(bufnr)
end

---Get the namespace used for virtual text
---@return number namespace_id
function M.get_namespace()
end

return M
```

### Display Logic

#### 1. Latest Version (Up-to-date)

Based on `docs/design.md`:

```yaml
- uses: actions/checkout@v4  #  4.0.0
```

**Conditions**:
- `is_latest == true`
- `current_version` equals `latest_version`

**Virtual Text**: ` {prefix}{latest_version}`
- Icon:  (latest, green)
- Version: with latest highlight

#### 2. Outdated Version

Based on `docs/design.md`:

```yaml
- uses: actions/checkout@v3  #  4.0.0
```

**Conditions**:
- `is_latest == false`
- `latest_version` is different from `current_version`

**Virtual Text**: ` {prefix}{latest_version}`
- Icon:  (outdated, yellow/warning)
- Version: with outdated highlight

#### 3. Hash-based Action

```yaml
- uses: actions/checkout@abc123... # v4  #  4.1.0
```

**Conditions**:
- `current_hash` is set
- `latest_version` is available

**Virtual Text**: `{icon} {prefix}{latest_version}` with appropriate highlight (outdated icon if hash is old)

#### 4. Error State

```yaml
- uses: some/unknown-action@v1  # (error checking version)
```

**Conditions**:
- `error` field is set

**Virtual Text**: Error message or hide virtual text

### Implementation Details

#### Namespace Management

Based on `docs/design.md`:

```lua
-- Create namespace per buffer or use a global one
local namespace_id = vim.api.nvim_create_namespace('github_actions_virtual_text')
```

#### Virtual Text Rendering

Based on `docs/design.md` extmarks strategy:

```lua
-- Using extmarks API
-- Example for outdated version: " 4.0.0"
vim.api.nvim_buf_set_extmark(bufnr, namespace_id, line, 0, {
  virt_text = {
    { icon, icon_highlight },           -- '' with GitHubActionsIconOutdated
    { prefix, 'Comment' },              -- ' ' with Comment
    { version, version_highlight },     -- '4.0.0' with GitHubActionsVersionOutdated
    { suffix, 'Comment' },              -- '' (empty by default)
  },
  virt_text_pos = 'eol',  -- End of line
  priority = vim.highlight.priorities.user,
  right_gravity = true,  -- Default
})
```

#### Clearing Virtual Text

```lua
vim.api.nvim_buf_clear_namespace(bufnr, namespace_id, 0, -1)
```

### Example Usage

```lua
local virtual_text = require('github-actions.ui.virtual_text')

-- Single action
local version_info = {
  line = 10,
  col = 12,
  current_version = 'v3',
  latest_version = '4.0.0',
  is_latest = false,
}

virtual_text.set_virtual_text(bufnr, version_info)
-- Result: Shows " 4.0.0" at line 10 with outdated icon and highlight

-- Multiple actions
local version_infos = {
  {
    line = 10,
    col = 12,
    current_version = 'v4',
    latest_version = '4.0.0',
    is_latest = true,
  },
  {
    line = 15,
    col = 12,
    current_version = 'v3',
    latest_version = '4.0.0',
    is_latest = false,
  },
}

virtual_text.set_virtual_texts(bufnr, version_infos)
-- Result:
--   Line 10: " 4.0.0" (latest icon, green)
--   Line 15: " 4.0.0" (outdated icon, yellow)

-- Clear all
virtual_text.clear_virtual_text(bufnr)
```

## Testing Strategy

### Unit Tests

1. **Text Generation Tests**
   - Up-to-date version → "✓ latest"
   - Outdated version → "→ v4 available"
   - Error state → "✗ check failed"
   - Custom text formats

2. **Buffer Integration Tests**
   - Set virtual text on valid buffer
   - Set virtual text on invalid buffer (should handle gracefully)
   - Clear virtual text
   - Multiple virtual texts in same buffer

3. **Edge Cases**
   - Empty version_infos array
   - Nil values in version_info
   - Invalid line/col numbers
   - Custom highlight groups

### Test Structure

```lua
describe('virtual_text', function()
  local virtual_text
  local test_bufnr

  before_each(function()
    virtual_text = require('github-actions.display.virtual_text')
    test_bufnr = vim.api.nvim_create_buf(false, true)
  end)

  after_each(function()
    vim.api.nvim_buf_delete(test_bufnr, { force = true })
  end)

  describe('set_virtual_text', function()
    it('should display up-to-date text for latest version', function()
      -- Test implementation
    end)

    it('should display outdated text for old version', function()
      -- Test implementation
    end)
  end)
end)
```

## Future Enhancements

1. **Customizable Icons**
   - Allow users to configure icons via setup()
   - Support for nerd fonts

2. **Inline Diagnostics**
   - Integration with Neovim's diagnostic system
   - Show as diagnostics instead of/in addition to virtual text

3. **Hover Information**
   - Show detailed version info on hover
   - Display changelog or release notes

4. **Auto-refresh**
   - Refresh virtual text when buffer changes
   - Periodic background updates

5. **Performance Optimization**
   - Debounce virtual text updates
   - Only update visible lines

## Integration Points

### With Parser

```lua
local parser = require('github-actions.parser.workflow')
local virtual_text = require('github-actions.ui.virtual_text')

local actions = parser.parse_buffer(bufnr)
-- Transform actions to version_infos (will be done by gh CLI wrapper in future)
local version_infos = transform_to_version_infos(actions)
virtual_text.set_virtual_texts(bufnr, version_infos)
```

### With gh CLI Wrapper (Future)

Based on `docs/design.md`:

```lua
local parser = require('github-actions.parser.workflow')
local gh_cli = require('github-actions.gh.cli')
local virtual_text = require('github-actions.ui.virtual_text')

local actions = parser.parse_buffer(bufnr)
-- gh CLI fetches latest version using 'gh api repos/{owner}/{repo}/releases/latest'
local version_infos = gh_cli.check_versions(actions)
virtual_text.set_virtual_texts(bufnr, version_infos)
```

## Dependencies

Based on `docs/design.md`:

- Neovim >= 0.10.0 (for `vim.system` API in future gh CLI integration)
- Extmarks API for virtual text rendering
- No external Lua dependencies for the UI module itself

## Configuration

Based on `docs/design.md` configuration:

```lua
require('github-actions').setup({
  virtual_text = {
    enabled = true,
    prefix = " ",
    suffix = "",
    highlight = "Comment",
    icons = {
      outdated = "",  -- Nerd Font icon for update available
      latest = "",    -- Nerd Font icon for latest version
    },
  },
})
```

### Highlight Groups

Based on `docs/design.md`:

```lua
-- Default highlight groups defined in ui/highlights.lua
vim.api.nvim_set_hl(0, 'GitHubActionsVersion', { link = 'Comment' })
vim.api.nvim_set_hl(0, 'GitHubActionsVersionLatest', { link = 'String' })
vim.api.nvim_set_hl(0, 'GitHubActionsVersionOutdated', { link = 'WarningMsg' })
vim.api.nvim_set_hl(0, 'GitHubActionsIconLatest', { link = 'String' })
vim.api.nvim_set_hl(0, 'GitHubActionsIconOutdated', { link = 'WarningMsg' })
```
