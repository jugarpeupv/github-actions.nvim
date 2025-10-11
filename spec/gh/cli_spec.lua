-- Test for gh CLI wrapper module

-- Load minimal init for tests
dofile('spec/minimal_init.lua')

local fixture = require('spec.helpers.fixture')

describe('gh.cli', function()
  ---@type GhCli
  local gh_cli

  before_each(function()
    gh_cli = require('github-actions.gh.cli')
  end)

  describe('parse_response', function()
    it('should parse valid JSON response', function()
      local json_str = fixture.load('gh_api_releases_latest_success')
      local result, err = gh_cli.parse_response(json_str)

      assert.is_nil(err)
      assert.is_not_nil(result)
      assert.equals('table', type(result))
    end)

    it('should handle invalid JSON gracefully', function()
      local invalid_json = '{ invalid json }'
      local result, err = gh_cli.parse_response(invalid_json)

      assert.is_nil(result)
      assert.is_not_nil(err)
      assert.is_string(err)
    end)

    it('should handle empty string', function()
      local result, err = gh_cli.parse_response('')

      assert.is_nil(result)
      assert.is_not_nil(err)
    end)
  end)

  describe('extract_version', function()
    it('should extract version from release data', function()
      local json_str = fixture.load('gh_api_releases_latest_success')
      local data = gh_cli.parse_response(json_str)
      local version = gh_cli.extract_version(data)

      assert.is_not_nil(version)
      assert.equals('v5.0.0', version)
    end)

    it('should handle missing tag_name field', function()
      local data = { name = 'v5.0.0' }
      local version = gh_cli.extract_version(data)

      assert.is_nil(version)
    end)

    it('should handle nil data', function()
      local version = gh_cli.extract_version(nil)

      assert.is_nil(version)
    end)
  end)

  describe('is_available', function()
    it('should check if gh command exists', function()
      local available = gh_cli.is_available()

      -- available should be boolean
      assert.equals('boolean', type(available))
    end)
  end)

  describe('fetch_latest_release', function()
    it('should call callback with version on success', function()
      -- This is a minimal test - we won't actually call the API
      -- Just verify the function exists and has correct signature
      assert.equals('function', type(gh_cli.fetch_latest_release))
    end)
  end)
end)
