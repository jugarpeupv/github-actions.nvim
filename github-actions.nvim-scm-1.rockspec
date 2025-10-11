rockspec_format = "3.0"
package = "github-actions.nvim"
version = "scm-1"

source = {
  url = "git://github.com/skanehira/github-actions.nvim",
}

description = {
  summary = "GitHub Actions integration for Neovim",
  detailed = [[
    A Neovim plugin for managing GitHub Actions workflows.
    Features:
    - Parse workflow files with treesitter
    - Display action versions with virtual text
    - Manage workflow execution
  ]],
  homepage = "https://github.com/skanehira/github-actions.nvim",
  license = "MIT",
}

dependencies = {
  "lua >= 5.1",
}

build_dependencies = {
  "luacheck >= 0.23.0",
}

test_dependencies = {
  "nlua",
}

test = {
  type = "busted",
  flags = { "--verbose" },
}
