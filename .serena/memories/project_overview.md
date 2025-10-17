# Project Overview

## Purpose
A Neovim plugin that checks GitHub Actions versions and displays them inline using extmarks.

The plugin automatically activates when you open:
- `.github/workflows/*.yml` or `*.yaml` (workflow files)
- `.github/actions/*/action.yml` or `*.yaml` (composite actions)

It displays version information inline at the end of each line, showing whether actions are outdated or up-to-date.

## Tech Stack
- **Language**: Lua (5.1+)
- **Platform**: Neovim 0.9+
- **Dependencies**:
  - nvim-treesitter (with YAML parser)
  - GitHub CLI (`gh`) - required for fetching GitHub API data
- **Testing Framework**: Busted (via nvim-busted-action)
- **Build System**: Makefile + Luarocks

## Project Structure
```
github-actions.nvim/
├── lua/github-actions/          # Main plugin code
│   ├── init.lua                 # Plugin entry point (setup, check_versions)
│   ├── cache.lua                # Caching functionality
│   ├── github.lua               # GitHub API interactions (gh CLI wrapper)
│   ├── display.lua              # Display logic (extmarks)
│   ├── workflow/                # Workflow-specific modules
│   │   ├── parser.lua           # Parse workflow files with treesitter
│   │   └── checker.lua          # Version checking logic
│   └── lib/                     # Shared libraries
│       ├── highlights.lua       # Highlight group definitions
│       └── semver.lua           # Semantic version comparison
├── ftplugin/                    # Filetype plugins for auto-activation
├── spec/                        # Test files (using Busted)
├── .github/workflows/ci.yml     # CI configuration
├── Makefile                     # Build and test commands
├── stylua.toml                  # Code formatter configuration
├── .luacheckrc                  # Linter configuration
└── .busted                      # Test configuration
```

## Key Features
- Automatically checks GitHub Actions versions in workflow files
- Displays inline version information with icons
- Highlights outdated vs latest versions
- Configurable icons and highlight groups
- Built-in caching to reduce API calls
