-- ftplugin for GitHub Actions workflow files
-- This file is loaded when opening YAML files

local bufnr = vim.api.nvim_get_current_buf()
local filepath = vim.api.nvim_buf_get_name(bufnr)

-- Only run for GitHub Actions workflow files
if not filepath:match('%.github/workflows/') then
  return
end

-- Check if plugin is loaded
local ok, github_actions = pcall(require, 'github-actions')
if not ok then
  vim.notify('github-actions plugin not found', vim.log.levels.ERROR)
  return
end

-- Auto-check on buffer enter
vim.defer_fn(function()
  if vim.api.nvim_buf_is_valid(bufnr) then
    github_actions.check_versions()
  end
end, 10)

-- Auto-check on text changes (debounced for performance)
vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
  buffer = bufnr,
  callback = github_actions.check_versions,
  desc = 'Check GitHub Actions versions on text change (debounced)',
})
