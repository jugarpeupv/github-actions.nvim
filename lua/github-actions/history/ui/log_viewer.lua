---@class LogViewer
local M = {}

---Check if logs can be viewed for a job
---@param run table Run object with status and databaseId
---@param job table Job object with status and name
---@return boolean can_view Whether logs can be viewed
---@return string|nil message Error message if logs cannot be viewed
function M.can_view_logs(run, job)
  -- Check if workflow run itself is still in progress
  -- Even if individual jobs are completed, logs are only available when the entire run completes
  if run.status == 'in_progress' or run.status == 'queued' then
    local message = string.format(
      'Workflow run #%d is still %s. Logs will be available when the entire workflow completes.',
      run.databaseId,
      run.status == 'in_progress' and 'running' or 'queued'
    )
    return false, message
  end

  -- Check if job is still in progress or queued
  if job.status == 'in_progress' or job.status == 'queued' then
    local message = string.format(
      'Job "%s" is still %s. Logs will be available when it completes.',
      job.name,
      job.status == 'in_progress' and 'running' or 'queued'
    )
    return false, message
  end

  return true, nil
end

---View logs for a job
---@param run table Run object with status, databaseId, and jobs
---@param job table Job object with status, name, and databaseId
function M.view_logs(run, job)
  if not run or not job then
    return
  end

  -- Check if logs can be viewed
  local can_view, message = M.can_view_logs(run, job)
  if not can_view then
    vim.schedule(function()
      vim.notify('[GitHub Actions] ' .. message, vim.log.levels.WARN)
    end)
    return
  end

  -- Create or reuse log buffer
  local logs_buffer = require('github-actions.history.ui.logs_buffer')
  local log_parser = require('github-actions.history.log_parser')
  local history = require('github-actions.history.api')
  local github_actions = require('github-actions')
  local config = github_actions.get_config()

  local title = string.format('Job: %s', job.name)
  local log_bufnr, _ = logs_buffer.create_buffer(title, run.databaseId, config.history)

  -- Check cache first
  local cached_formatted, _ = logs_buffer.get_cached_logs(run.databaseId, job.databaseId)
  if cached_formatted then
    -- Use cached logs
    logs_buffer.render(log_bufnr, cached_formatted)
    return
  end

  -- Show loading indicator only for new fetches
  logs_buffer.render(log_bufnr, 'Loading logs...')

  -- Fetch logs for the entire job
  history.fetch_logs(run.databaseId, job.databaseId, function(logs, err)
    vim.schedule(function()
      if err then
        logs_buffer.render(log_bufnr, 'Failed to fetch logs: ' .. err)
        vim.notify('[GitHub Actions] Failed to fetch logs: ' .. err, vim.log.levels.ERROR)
        return
      end

      -- Parse and format logs, removing ANSI escape sequences
      local formatted_logs = log_parser.parse(logs or '')

      -- Cache both raw and formatted logs
      logs_buffer.cache_logs(run.databaseId, job.databaseId, formatted_logs or 'No logs available', logs or '')

      -- Render the logs
      logs_buffer.render(log_bufnr, formatted_logs or 'No logs available')
    end)
  end)
end

---View the combined logs for every job in a run
---Opens a single buffer with a foldable section per job; each job section contains
---the per-step sections and log groups produced by log_parser.
---@param run table Run object with status, databaseId, and jobs
function M.view_run_logs(run)
  if not run then
    return
  end

  if run.status == 'in_progress' or run.status == 'queued' then
    vim.schedule(function()
      vim.notify(
        string.format(
          '[GitHub Actions] Workflow run #%d is still %s. Logs will be available when it completes.',
          run.databaseId,
          run.status == 'in_progress' and 'running' or 'queued'
        ),
        vim.log.levels.WARN
      )
    end)
    return
  end

  local logs_buffer = require('github-actions.history.ui.logs_buffer')
  local log_parser = require('github-actions.history.log_parser')
  local history = require('github-actions.history.api')
  local config_module = require('github-actions.config')
  local github_actions = require('github-actions')

  local defaults = config_module.get_defaults()
  local user_config = github_actions.get_config() or {}
  local history_cfg = user_config.history or defaults.history
  local icons = config_module.merge_icons(defaults.history.icons, history_cfg.icons)

  local title = string.format('Run #%d', run.databaseId)
  local log_bufnr = logs_buffer.create_buffer(title, run.databaseId, history_cfg)

  ---@param job table
  ---@return string
  local function format_job_header(job)
    local formatter = require('github-actions.history.ui.formatter')
    local label = vim.trim(formatter.format_job(job, icons))
    return string.format('━━ %s ━━', label)
  end

  ---@param jobs table[]
  ---@param results table<number, {formatted?: string, error?: string, note?: string}>
  local function render_jobs(jobs, results)
    local sections = {}
    for _, job in ipairs(jobs) do
      table.insert(sections, format_job_header(job))
      local result = results[job.databaseId]
      if result and result.error then
        table.insert(sections, '  Failed to fetch logs: ' .. result.error)
      elseif result and result.note then
        table.insert(sections, '  ' .. result.note)
      elseif result and result.formatted and result.formatted ~= '' then
        table.insert(sections, result.formatted)
      else
        table.insert(sections, '  (no logs available)')
      end
    end

    logs_buffer.render(log_bufnr, table.concat(sections, '\n'))
  end

  ---@param jobs table[]
  local function fetch_all_job_logs(jobs)
    if #jobs == 0 then
      logs_buffer.render(log_bufnr, 'No jobs found for this run.')
      return
    end

    logs_buffer.render(log_bufnr, string.format('Loading logs for %d jobs...', #jobs))

    local results = {}
    local pending = 0

    local function finish(job_id, result)
      results[job_id] = result
      pending = pending - 1
      if pending == 0 then
        render_jobs(jobs, results)
      end
    end

    for _, job in ipairs(jobs) do
      local cached_formatted = logs_buffer.get_cached_logs(run.databaseId, job.databaseId)
      if cached_formatted then
        results[job.databaseId] = { formatted = cached_formatted }
      elseif job.conclusion == 'skipped' then
        results[job.databaseId] = { note = '(skipped)' }
      elseif job.status == 'in_progress' or job.status == 'queued' then
        results[job.databaseId] = { note = '(still running)' }
      else
        pending = pending + 1
        history.fetch_logs(run.databaseId, job.databaseId, function(logs, err)
          vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(log_bufnr) then
              return
            end

            if err then
              finish(job.databaseId, { error = vim.trim(err) })
              return
            end

            local formatted = log_parser.parse(logs or '')
            logs_buffer.cache_logs(run.databaseId, job.databaseId, formatted, logs or '')
            finish(job.databaseId, { formatted = formatted })
          end)
        end)
      end
    end

    if pending == 0 then
      render_jobs(jobs, results)
    end
  end

  if run.jobs then
    fetch_all_job_logs(run.jobs)
    return
  end

  logs_buffer.render(log_bufnr, 'Loading jobs...')
  history.fetch_jobs(run.databaseId, function(response, err)
    if not vim.api.nvim_buf_is_valid(log_bufnr) then
      return
    end

    if err or not response or not response.jobs then
      local message = err or 'Unexpected jobs response format'
      logs_buffer.render(log_bufnr, 'Failed to fetch jobs: ' .. message)
      vim.notify('[GitHub Actions] Failed to fetch jobs: ' .. message, vim.log.levels.ERROR)
      return
    end

    run.jobs = response.jobs
    fetch_all_job_logs(response.jobs)
  end)
end

return M
