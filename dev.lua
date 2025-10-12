-- Development configuration
-- Load this file to test the plugin during development
--
-- Usage:
--   nvim -u dev.lua .github/workflows/test.yml

-- Add current directory to runtimepath
vim.opt.runtimepath:append('.')

-- Disable swap files for cleaner testing
vim.opt.swapfile = false

-- Setup nvim-treesitter for YAML parsing
local treesitter_path = './deps/nvim-treesitter'
if vim.fn.isdirectory(treesitter_path) == 1 then
  vim.opt.runtimepath:prepend(treesitter_path)

  -- Configure nvim-treesitter to use deps/parsers
  require('nvim-treesitter.configs').setup({
    parser_install_dir = vim.fn.getcwd() .. '/deps/parsers',
    ensure_installed = { 'yaml' },
    sync_install = false,
    ignore_install = {},
    auto_install = false,
    modules = {},
  })

  -- Add parser directory to runtimepath
  vim.opt.runtimepath:prepend('./deps/parsers')
end

-- Setup the plugin (uses default options from virtual_text.lua)
local github_actions = require('github-actions')
github_actions.setup()

-- Or customize if needed:
-- require('github-actions').setup({
--   virtual_text = {
--     icons = {
--       outdated = '⚠',
--       latest = '✓',
--     },
--   },
-- })

-- shoud be called after setup becaude fplugin/yaml.lua check workflow file path
vim.defer_fn(function()
  github_actions.check_versions()
end, 10)

local bufnr = vim.api.nvim_get_current_buf()
vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
  buffer = bufnr,
  callback = github_actions.check_versions,
  desc = 'Check GitHub Actions versions on text change (debounced)',
})
