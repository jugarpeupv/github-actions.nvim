---@class VersionInfo
---@field line number The 0-indexed line number in the buffer
---@field col number The 0-indexed column number in the buffer
---@field current_version? string The current version used (e.g., "v3", "main")
---@field current_hash? string The current commit hash if used
---@field latest_version? string The latest available version
---@field latest_hash? string The latest commit hash
---@field is_latest boolean Whether the current version is the latest
---@field error? string Error message if version check failed

---@class Display
local M = {}

-- Namespace for version virtual text
local namespace_id = nil

---Get or create the namespace for virtual text
---@return number namespace_id
function M.get_namespace()
  if namespace_id == nil then
    namespace_id = vim.api.nvim_create_namespace('github_actions_virtual_text')
  end
  return namespace_id
end

---Build virtual text chunks
---@param version_info VersionInfo Version information
---@param opts table Merged options
---@return table virt_text Array of [text, highlight] tuples
local function build_virt_text(version_info, opts)
  local virt_text = {}

  -- Handle error case
  if version_info.error then
    table.insert(virt_text, { opts.icons.error, opts.highlight_icon_error })
    table.insert(virt_text, { ' ' .. version_info.error, opts.highlight_error })
    return virt_text
  end

  -- Determine icon and highlights based on is_latest
  local icon = version_info.is_latest and opts.icons.latest or opts.icons.outdated
  local icon_hl = version_info.is_latest and opts.highlight_icon_latest or opts.highlight_icon_outdated
  local version_hl = version_info.is_latest and opts.highlight_latest or opts.highlight_outdated

  -- Add icon
  table.insert(virt_text, { icon, icon_hl })

  -- Add version
  if version_info.latest_version then
    table.insert(virt_text, { ' ' .. version_info.latest_version, version_hl })
  end

  return virt_text
end

---Set version text for a single action in a buffer
---@param bufnr number Buffer number
---@param version_info VersionInfo Version information for the action
---@param opts VirtualTextOptions Display options (should be pre-merged with defaults)
function M.set_version_text(bufnr, version_info, opts)
  -- Validate buffer
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local merged_opts = opts
  local ns = M.get_namespace()

  -- Build virtual text
  local virt_text = build_virt_text(version_info, merged_opts)

  -- Set extmark
  vim.api.nvim_buf_set_extmark(bufnr, ns, version_info.line, 0, {
    virt_text = virt_text,
    virt_text_pos = 'eol',
    priority = vim.highlight.priorities.user,
    right_gravity = true,
  })
end

---Set version text for multiple actions in a buffer
---@param bufnr number Buffer number
---@param version_infos VersionInfo[] List of version information
---@param opts VirtualTextOptions Display options (should be pre-merged with defaults)
function M.set_version_texts(bufnr, version_infos, opts)
  -- Validate buffer
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Set version text for each version info
  for _, version_info in ipairs(version_infos) do
    M.set_version_text(bufnr, version_info, opts)
  end
end

---Clear all version text from a buffer
---@param bufnr number Buffer number
function M.clear_version_text(bufnr)
  -- Validate buffer
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local ns = M.get_namespace()
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

---Clear and display version information (high-level UI function)
---@param bufnr number Buffer number
---@param version_infos VersionInfo[]|nil List of version information
---@param opts VirtualTextOptions Display options (should be pre-merged with defaults)
function M.show_versions(bufnr, version_infos, opts)
  -- Validate buffer
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Clear existing version text
  M.clear_version_text(bufnr)

  -- Display new version infos
  if version_infos and #version_infos > 0 then
    M.set_version_texts(bufnr, version_infos, opts)
  end
end

return M
