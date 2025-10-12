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
  return
end

-- Auto-check on buffer enter
vim.defer_fn(function()
  if vim.api.nvim_buf_is_valid(bufnr) then
    github_actions.check_versions()
  end
end, 500)

-- Debounce timer for text changes
local debounce_timer = nil
local debounce_delay = 500 -- milliseconds

-- Auto-check on buffer write (uses cache for fast updates)
vim.api.nvim_create_autocmd('BufWritePost', {
  buffer = bufnr,
  callback = function()
    github_actions.check_versions()
  end,
  desc = 'Check GitHub Actions versions after save',
})

-- Auto-check on text changes (debounced for performance)
vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
  buffer = bufnr,
  callback = function()
    -- Cancel previous timer if exists
    if debounce_timer then
      vim.fn.timer_stop(debounce_timer)
    end

    -- Set new timer
    debounce_timer = vim.fn.timer_start(debounce_delay, function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        github_actions.check_versions()
      end
      debounce_timer = nil
    end)
  end,
  desc = 'Check GitHub Actions versions on text change (debounced)',
})
