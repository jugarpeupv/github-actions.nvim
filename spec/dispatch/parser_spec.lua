-- Test for dispatch parser

---@diagnostic disable: need-check-nil

-- Load minimal init for tests
dofile('spec/minimal_init.lua')

local helpers = require('spec.helpers.buffer_spec')

describe('dispatch parser', function()
  local parser = require('github-actions.dispatch.parser')

  describe('parse_workflow_dispatch', function()
    it('should extract workflow_dispatch inputs with defaults', function()
      local content = [[
name: Deploy

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Deployment environment'
        required: true
        default: 'staging'
        type: choice
        options:
          - staging
          - production
      version:
        description: 'Version to deploy'
        required: false
        default: 'latest'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
]]
      local bufnr = helpers.create_yaml_buffer(content)
      local dispatch_info = parser.parse_workflow_dispatch(bufnr)

      assert.is_not_nil(dispatch_info)
      assert.equals(2, #dispatch_info.inputs)

      -- Check first input
      assert.equals('environment', dispatch_info.inputs[1].name)
      assert.equals('Deployment environment', dispatch_info.inputs[1].description)
      assert.is_true(dispatch_info.inputs[1].required)
      assert.equals('staging', dispatch_info.inputs[1].default)
      assert.equals('choice', dispatch_info.inputs[1].type)
      assert.same({ 'staging', 'production' }, dispatch_info.inputs[1].options)

      -- Check second input
      assert.equals('version', dispatch_info.inputs[2].name)
      assert.equals('Version to deploy', dispatch_info.inputs[2].description)
      assert.is_false(dispatch_info.inputs[2].required)
      assert.equals('latest', dispatch_info.inputs[2].default)

      helpers.delete_buffer(bufnr)
    end)

    it('should handle workflow without workflow_dispatch', function()
      local content = [[
name: CI

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
]]
      local bufnr = helpers.create_yaml_buffer(content)
      local dispatch_info = parser.parse_workflow_dispatch(bufnr)

      assert.is_nil(dispatch_info)

      helpers.delete_buffer(bufnr)
    end)

    it('should handle workflow_dispatch without inputs', function()
      local content = [[
name: Manual Workflow

on:
  workflow_dispatch:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
]]
      local bufnr = helpers.create_yaml_buffer(content)
      local dispatch_info = parser.parse_workflow_dispatch(bufnr)

      assert.is_not_nil(dispatch_info)
      assert.equals(0, #dispatch_info.inputs)

      helpers.delete_buffer(bufnr)
    end)

    it('should handle inputs without optional fields', function()
      local content = [[
on:
  workflow_dispatch:
    inputs:
      simple_input:
        description: 'A simple input'
]]
      local bufnr = helpers.create_yaml_buffer(content)
      local dispatch_info = parser.parse_workflow_dispatch(bufnr)

      assert.is_not_nil(dispatch_info)
      assert.equals(1, #dispatch_info.inputs)
      assert.equals('simple_input', dispatch_info.inputs[1].name)
      assert.equals('A simple input', dispatch_info.inputs[1].description)
      assert.is_nil(dispatch_info.inputs[1].required)
      assert.is_nil(dispatch_info.inputs[1].default)

      helpers.delete_buffer(bufnr)
    end)

    it('should handle invalid buffer', function()
      local dispatch_info = parser.parse_workflow_dispatch(999999)

      assert.is_nil(dispatch_info)
    end)
  end)
end)
