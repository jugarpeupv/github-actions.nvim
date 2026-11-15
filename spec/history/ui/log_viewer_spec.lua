dofile('spec/minimal_init.lua')

describe('history.ui.log_viewer', function()
  local log_viewer = require('github-actions.history.ui.log_viewer')
  local buffer_helper = require('spec.helpers.buffer_spec')

  after_each(function()
    -- Close all buffers
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        buffer_helper.delete_buffer(bufnr)
      end
    end
  end)

  describe('can_view_logs', function()
    it('should return false when run is in_progress', function()
      local run = {
        status = 'in_progress',
        databaseId = 12345,
      }
      local job = {
        status = 'completed',
        conclusion = 'success',
        name = 'test-job',
      }

      local can_view, message = log_viewer.can_view_logs(run, job)
      assert.is_false(can_view)
      assert.is_not_nil(message)
      assert.is_true(message:find('still running') ~= nil)
    end)

    it('should return false when run is queued', function()
      local run = {
        status = 'queued',
        databaseId = 12345,
      }
      local job = {
        status = 'completed',
        conclusion = 'success',
        name = 'test-job',
      }

      local can_view, message = log_viewer.can_view_logs(run, job)
      assert.is_false(can_view)
      assert.is_not_nil(message)
      assert.is_true(message:find('queued') ~= nil)
    end)

    it('should return false when job is in_progress', function()
      local run = {
        status = 'completed',
        conclusion = 'success',
        databaseId = 12345,
      }
      local job = {
        status = 'in_progress',
        name = 'test-job',
      }

      local can_view, message = log_viewer.can_view_logs(run, job)
      assert.is_false(can_view)
      assert.is_not_nil(message)
      assert.is_true(message:find('still running') ~= nil)
    end)

    it('should return false when job is queued', function()
      local run = {
        status = 'completed',
        conclusion = 'success',
        databaseId = 12345,
      }
      local job = {
        status = 'queued',
        name = 'test-job',
      }

      local can_view, message = log_viewer.can_view_logs(run, job)
      assert.is_false(can_view)
      assert.is_not_nil(message)
      assert.is_true(message:find('queued') ~= nil)
    end)

    it('should return true when both run and job are completed', function()
      local run = {
        status = 'completed',
        conclusion = 'success',
        databaseId = 12345,
      }
      local job = {
        status = 'completed',
        conclusion = 'success',
        name = 'test-job',
      }

      local can_view, message = log_viewer.can_view_logs(run, job)
      assert.is_true(can_view)
      assert.is_nil(message)
    end)
  end)

  describe('view_logs', function()
    -- Note: This function has external dependencies (logs_buffer, history.fetch_logs)
    -- so we only test the validation logic here
    it('should not proceed when run is nil', function()
      local result = log_viewer.view_logs(nil, nil)
      assert.is_nil(result)
    end)

    it('should not proceed when job is nil', function()
      local run = {
        status = 'completed',
        conclusion = 'success',
        databaseId = 12345,
        jobs = {},
      }
      local result = log_viewer.view_logs(run, nil)
      assert.is_nil(result)
    end)
  end)

  describe('view_run_logs', function()
    local api = require('github-actions.history.api')
    local logs_buffer = require('github-actions.history.ui.logs_buffer')
    local stub = require('luassert.stub')

    local function make_run(database_id)
      return {
        databaseId = database_id or 42,
        displayTitle = 'test run',
        headBranch = 'main',
        status = 'completed',
        conclusion = 'success',
        createdAt = '2025-10-19T10:00:00Z',
        updatedAt = '2025-10-19T10:05:00Z',
        jobs = {
          {
            databaseId = 1,
            name = 'Test',
            status = 'completed',
            conclusion = 'success',
            startedAt = '2025-10-19T10:00:00Z',
            completedAt = '2025-10-19T10:01:00Z',
            steps = {},
          },
          {
            databaseId = 2,
            name = 'Build',
            status = 'completed',
            conclusion = 'success',
            startedAt = '2025-10-19T10:00:00Z',
            completedAt = '2025-10-19T10:01:00Z',
            steps = {},
          },
        },
      }
    end

    local function wait_for(bufnr, needle)
      local found = vim.wait(1000, function()
        local content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
        return content:find(needle, 1, true) ~= nil
      end)
      assert.is_true(found, 'timed out waiting for ' .. needle)
    end

    local function find_line(lines, pattern)
      for i, line in ipairs(lines) do
        if line:match(pattern) then
          return i
        end
      end
      return nil
    end

    it('should render combined logs for every job with step sections', function()
      local run = make_run()
      local fetch_logs = stub(api, 'fetch_logs')
      finally(function()
        fetch_logs:revert()
      end)
      fetch_logs.invokes(function(_, job_id, callback)
        local step = job_id == 1 and 'Set up job' or 'Build'
        local logs = string.format(
          'job\t%s\t2025-10-18T04:09:32.1000000Z ##[group]%s group\n'
            .. 'job\t%s\t2025-10-18T04:09:33.1000000Z log from %s\n'
            .. 'job\t%s\t2025-10-18T04:09:34.1000000Z ##[endgroup]',
          step,
          step,
          step,
          step,
          step
        )
        callback(logs, nil)
      end)

      log_viewer.view_run_logs(run)
      local bufnr = vim.api.nvim_get_current_buf()
      wait_for(bufnr, 'Job: Build')

      local content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
      assert.matches('━━ ✓ Job: Test', content)
      assert.matches('━━ ✓ Job: Build', content)
      assert.matches('── Set up job ──', content)
      assert.matches('── Build ──', content)
      assert.matches('log from Set up job', content)
      assert.matches('log from Build', content)

      -- Job folds contain step folds, which contain group folds
      vim.api.nvim_set_current_buf(bufnr)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local job_line = assert(find_line(lines, '^━━ .*Job: Test'))
      local step_line = assert(find_line(lines, '^── Set up job ──$'))
      local group_line = assert(find_line(lines, '##%[group%]Set up job group'))
      local endgroup_line = assert(find_line(lines, '##%[endgroup%]'))

      assert.equals('>1', logs_buffer.foldexpr(job_line))
      assert.equals('>2', logs_buffer.foldexpr(step_line))
      assert.equals('>3', logs_buffer.foldexpr(group_line))
      assert.equals('<3', logs_buffer.foldexpr(endgroup_line))
    end)

    it('should show fetch failures inline for a job', function()
      local run = make_run(43)
      local fetch_logs = stub(api, 'fetch_logs')
      finally(function()
        fetch_logs:revert()
      end)
      fetch_logs.invokes(function(_, job_id, callback)
        if job_id == 2 then
          callback(nil, 'boom')
        else
          callback('job\tSet up job\t2025-10-18T04:09:32.1000000Z ok', nil)
        end
      end)

      log_viewer.view_run_logs(run)
      local bufnr = vim.api.nvim_get_current_buf()
      wait_for(bufnr, 'Failed to fetch logs')

      local content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
      assert.matches('━━ ✓ Job: Build', content)
      assert.matches('Failed to fetch logs: boom', content)
      assert.matches('ok', content)
    end)

    it('should fetch jobs first when the run has no jobs', function()
      local run = make_run(44)
      run.jobs = nil

      local jobs = make_run(44).jobs
      local fetch_jobs = stub(api, 'fetch_jobs')
      local fetch_logs = stub(api, 'fetch_logs')
      finally(function()
        fetch_jobs:revert()
        fetch_logs:revert()
      end)
      fetch_jobs.invokes(function(_, callback)
        callback({ jobs = jobs }, nil)
      end)
      fetch_logs.invokes(function(_, _, callback)
        callback('job\tSet up job\t2025-10-18T04:09:32.1000000Z hello', nil)
      end)

      log_viewer.view_run_logs(run)
      local bufnr = vim.api.nvim_get_current_buf()
      wait_for(bufnr, 'Job: Test')

      assert.equals(1, #fetch_jobs.calls)
      assert.is_not_nil(run.jobs)
      local content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
      assert.matches('Job: Test', content)
      assert.matches('Job: Build', content)
    end)
  end)
end)
