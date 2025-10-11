-- luacheck configuration for Neovim plugin
-- https://luacheck.readthedocs.io/en/stable/config.html

-- Only allow globals defined in Neovim
read_globals = {
  "vim",
}

-- Ignore some pedantic warnings
ignore = {
  "212", -- Unused argument
}
