---@class Checker
local M = {}

local workflow_parser = require('github-actions.parser.workflow')
local gh_cli = require('github-actions.gh.cli')
local version_checker = require('github-actions.utils.version_checker')
local ui = require('github-actions.ui')
local cache = require('github-actions.cache')

---Check and update version information for a buffer
---@param bufnr number Buffer number
---@param opts? VirtualTextOptions Display options
function M.update_buffer(bufnr, opts)
  -- Validate buffer
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Check if gh CLI is available
  if not gh_cli.is_available() then
    vim.notify('gh command not found. Please install GitHub CLI.', vim.log.levels.ERROR)
    return
  end

  -- Clear existing virtual text
  ui.version.clear_virtual_text(bufnr)

  -- Parse workflow file
  local actions = workflow_parser.parse(bufnr)
  if #actions == 0 then
    return
  end

  -- Track pending API calls
  local pending_count = 0
  local version_infos = {}

  -- Process each action
  for _, action in ipairs(actions) do
    local cache_key = cache.make_key(action.owner, action.repo)

    -- Check if version is cached
    if cache.has(cache_key) then
      -- Use cached version
      local cached_version = cache.get(cache_key)
      local version_info = version_checker.create_version_info(action, cached_version, nil)
      table.insert(version_infos, version_info)
    else
      -- Need to fetch from API
      pending_count = pending_count + 1

      gh_cli.fetch_latest_release(action.owner, action.repo, function(latest_version, error_msg)
        -- Cache the version if successful
        if latest_version and not error_msg then
          cache.set(cache_key, latest_version)
        end

        -- Create version info
        local version_info = version_checker.create_version_info(action, latest_version, error_msg)
        table.insert(version_infos, version_info)

        -- Decrement pending count
        pending_count = pending_count - 1

        -- When all API calls complete, update virtual text
        if pending_count == 0 then
          -- Schedule UI update on main thread
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(bufnr) then
              ui.version.set_virtual_texts(bufnr, version_infos, opts)
            end
          end)
        end
      end)
    end
  end

  -- If all versions were cached, update immediately
  if pending_count == 0 and #version_infos > 0 then
    ui.version.set_virtual_texts(bufnr, version_infos, opts)
  end
end

return M
