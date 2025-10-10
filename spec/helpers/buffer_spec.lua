---Test helpers for buffer operations
local M = {}

---Create a test buffer with YAML content
---@param content string Multi-line YAML content
---@return number bufnr The created buffer number
function M.create_yaml_buffer(content)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content, '\n', { plain = true }))
  vim.bo[bufnr].filetype = 'yaml'
  return bufnr
end

---Delete a test buffer
---@param bufnr number Buffer number to delete
function M.delete_buffer(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

return M
