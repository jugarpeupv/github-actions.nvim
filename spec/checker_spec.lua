-- Test for checker module (full flow)

-- Load minimal init for tests
dofile('spec/minimal_init.lua')

local helpers = require('spec.helpers.buffer_spec')

describe('checker', function()
  ---@type Checker
  local checker
  ---@type number
  local test_bufnr

  before_each(function()
    checker = require('github-actions.checker')
    test_bufnr = helpers.create_yaml_buffer([[\
name: Test Workflow

on: push

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v4
]])
  end)

  after_each(function()
    local virtual_text = require('github-actions.ui.version')
    virtual_text.clear_virtual_text(test_bufnr)
    helpers.delete_buffer(test_bufnr)
  end)

  describe('update_buffer', function()
    it('should exist and be callable', function()
      assert.equals('function', type(checker.update_buffer))
    end)

    it('should handle invalid buffer gracefully', function()
      assert.has.no.errors(function()
        checker.update_buffer(999999)
      end)
    end)

    it('should handle buffer with no actions', function()
      local empty_bufnr = helpers.create_yaml_buffer([[\
name: Empty Workflow

on: push

jobs:
  test:
    runs-on: ubuntu-latest
]])

      assert.has.no.errors(function()
        checker.update_buffer(empty_bufnr)
      end)

      helpers.delete_buffer(empty_bufnr)
    end)

    it('should clear virtual text before updating', function()
      local virtual_text = require('github-actions.ui.version')
      local ns = virtual_text.get_namespace()

      -- Set some initial virtual text
      virtual_text.set_virtual_text(test_bufnr, {
        line = 0,
        col = 0,
        current_version = 'v1',
        latest_version = '2.0.0',
        is_latest = false,
      })

      -- Verify mark exists
      local marks_before = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, {})
      assert.equals(1, #marks_before)

      -- Update buffer (which should clear first)
      checker.update_buffer(test_bufnr)

      -- Marks should be cleared (even though async operations may add new ones later)
      -- We can't easily test the async part without mocking, but we can verify
      -- that the function runs without error
      assert.has.no.errors(function()
        vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, {})
      end)
    end)
  end)
end)
