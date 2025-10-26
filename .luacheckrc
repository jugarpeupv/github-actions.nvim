-- luacheck configuration for Neovim plugin
-- https://luacheck.readthedocs.io/en/stable/config.html

-- Cache results for faster reruns
cache = true

-- Only allow globals defined in Neovim
read_globals = {
  "vim",
}

-- Declare vim metatable accessors as globals to prevent false positives
-- when setting buffer/window options via vim.bo[bufnr] or vim.wo[winid]
globals = {
  "vim.g",
  "vim.b",
  "vim.w",
  "vim.o",
  "vim.bo",
  "vim.wo",
  "vim.go",
  "vim.env",
}

-- Ignore some pedantic warnings
ignore = {
  "212", -- Unused argument
}
