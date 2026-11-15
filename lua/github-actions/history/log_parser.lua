---@class LogParser
local M = {}

---Parse gh CLI log output format
---The format is: <job-name>\t<step-name>\t<timestamp> <log-line>
---@param raw_logs string Raw log output from gh CLI
---@param opts? {strip_ansi?: boolean, group_by_step?: boolean} Parse options
---  (default: strip_ansi = true, group_by_step = true)
---@return string formatted Formatted log output with step headers, timestamps, and content
function M.parse(raw_logs, opts)
  if not raw_logs or raw_logs == '' then
    return ''
  end

  opts = opts or {}
  local strip_ansi = opts.strip_ansi == nil and true or opts.strip_ansi
  local group_by_step = opts.group_by_step == nil and true or opts.group_by_step

  local lines = vim.split(raw_logs, '\n', { plain = true })
  local formatted_lines = {}

  local timestamp_pattern = '%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d%.%d+Z'
  local current_step

  for _, line in ipairs(lines) do
    if line ~= '' then
      -- Determine the timestamp+content portion of the line
      -- Supports two formats:
      --   1. Tab-separated (gh run view --log): job-name\tstep-name\ttimestamp content
      --   2. Direct (gh api .../logs): timestamp content
      local fields = vim.split(line, '\t', { plain = true })
      local step_name
      local timestamp_and_content
      if #fields >= 3 then
        step_name = fields[2]
        timestamp_and_content = fields[3]
      else
        timestamp_and_content = line
      end

      -- Insert a section header whenever the step changes. gh labels lines it
      -- cannot associate with a step as "UNKNOWN STEP"; keep those with the
      -- previous section instead of creating a bogus header.
      local is_known_step = step_name and step_name ~= '' and step_name ~= 'UNKNOWN STEP'
      if group_by_step and is_known_step and step_name ~= current_step then
        table.insert(formatted_lines, string.format('── %s ──', step_name))
        current_step = step_name
      end

      local timestamp = timestamp_and_content:match(timestamp_pattern)
      if timestamp then
        local content = timestamp_and_content:gsub(timestamp_pattern .. '%s*', '', 1)
        local time_only = timestamp:match('T(%d%d:%d%d:%d%d)')
        table.insert(formatted_lines, string.format('[%s] %s', time_only, content))
      else
        table.insert(formatted_lines, timestamp_and_content)
      end
    end
  end

  local result = table.concat(formatted_lines, '\n')

  -- Strip ANSI escape sequences if requested
  if strip_ansi then
    -- Match various forms of ANSI escape sequences:
    -- \27[...m (octal), \x1b[...m (hex), or literal escape character
    -- Pattern: ESC [ <parameters> <letter>
    result = result:gsub('\27%[([%d;]*)m', '') -- Standard SGR sequences (color, style)
    result = result:gsub('\27%[([%d;]*)([A-Za-z])', '') -- Other CSI sequences (cursor movement, etc.)
    -- OSC sequences (Operating System Command): \27]...\07 or \27]...\27\
    result = result:gsub('\27%].-\007', '') -- OSC with BEL terminator
    result = result:gsub('\27%].-\27\\', '') -- OSC with ST terminator
  end

  -- Strip BOM (Byte Order Mark) characters
  -- BOM: U+FEFF (UTF-8: EF BB BF = \239\187\191)
  result = result:gsub('\239\187\191', '')

  return result
end

return M
