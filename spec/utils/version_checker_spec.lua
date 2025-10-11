-- Test for version checker module

-- Load minimal init for tests
dofile('spec/minimal_init.lua')

describe('utils.version_checker', function()
  ---@type VersionChecker
  local version_checker

  before_each(function()
    version_checker = require('github-actions.utils.version_checker')
  end)

  describe('parse_version', function()
    it('should parse major version only', function()
      local parts = version_checker.parse_version('v3')
      assert.are.same({ 3 }, parts)
    end)

    it('should parse major.minor version', function()
      local parts = version_checker.parse_version('v3.5')
      assert.are.same({ 3, 5 }, parts)
    end)

    it('should parse full semantic version', function()
      local parts = version_checker.parse_version('v3.5.1')
      assert.are.same({ 3, 5, 1 }, parts)
    end)

    it('should parse version without v prefix', function()
      local parts = version_checker.parse_version('3.5.1')
      assert.are.same({ 3, 5, 1 }, parts)
    end)

    it('should handle version with text suffix', function()
      local parts = version_checker.parse_version('v3.5.1-beta')
      assert.are.same({ 3, 5, 1 }, parts)
    end)

    it('should handle invalid version string', function()
      local parts = version_checker.parse_version('invalid')
      assert.are.same({}, parts)
    end)

    it('should handle nil version', function()
      local parts = version_checker.parse_version(nil)
      assert.are.same({}, parts)
    end)

    it('should handle empty string', function()
      local parts = version_checker.parse_version('')
      assert.are.same({}, parts)
    end)
  end)

  describe('compare_versions', function()
    describe('major version only', function()
      it('should detect outdated major version', function()
        local is_latest = version_checker.compare_versions('v3', 'v4.1.0')
        assert.is_false(is_latest)
      end)

      it('should detect latest major version', function()
        local is_latest = version_checker.compare_versions('v4', 'v4.1.0')
        assert.is_true(is_latest)
      end)

      it('should detect newer major version', function()
        local is_latest = version_checker.compare_versions('v5', 'v4.1.0')
        assert.is_true(is_latest)
      end)
    end)

    describe('major.minor version', function()
      it('should detect outdated minor version', function()
        local is_latest = version_checker.compare_versions('v4.0', 'v4.1.5')
        assert.is_false(is_latest)
      end)

      it('should detect latest minor version', function()
        local is_latest = version_checker.compare_versions('v4.1', 'v4.1.5')
        assert.is_true(is_latest)
      end)

      it('should detect outdated major in major.minor', function()
        local is_latest = version_checker.compare_versions('v3.9', 'v4.0.0')
        assert.is_false(is_latest)
      end)
    end)

    describe('full semantic version', function()
      it('should detect outdated patch version', function()
        local is_latest = version_checker.compare_versions('v3.5.1', 'v3.5.2')
        assert.is_false(is_latest)
      end)

      it('should detect latest patch version', function()
        local is_latest = version_checker.compare_versions('v3.5.2', 'v3.5.2')
        assert.is_true(is_latest)
      end)

      it('should detect outdated minor in full version', function()
        local is_latest = version_checker.compare_versions('v3.4.5', 'v3.5.0')
        assert.is_false(is_latest)
      end)

      it('should detect outdated major in full version', function()
        local is_latest = version_checker.compare_versions('v2.9.9', 'v3.0.0')
        assert.is_false(is_latest)
      end)
    end)

    describe('edge cases', function()
      it('should handle version without v prefix', function()
        local is_latest = version_checker.compare_versions('3.5.1', '3.5.2')
        assert.is_false(is_latest)
      end)

      it('should handle nil current version', function()
        local is_latest = version_checker.compare_versions(nil, 'v4.0.0')
        assert.is_false(is_latest)
      end)

      it('should handle nil latest version', function()
        local is_latest = version_checker.compare_versions('v4', nil)
        assert.is_false(is_latest)
      end)

      it('should handle invalid versions', function()
        local is_latest = version_checker.compare_versions('invalid', 'also-invalid')
        assert.is_false(is_latest)
      end)
    end)
  end)

  describe('create_version_info', function()
    it('should create version info for outdated version', function()
      ---@type Action
      local action = {
        owner = 'actions',
        repo = 'checkout',
        version = 'v3',
        line = 5,
        col = 12,
      }

      local version_info = version_checker.create_version_info(action, 'v4.0.0')

      assert.equals(5, version_info.line)
      assert.equals(12, version_info.col)
      assert.equals('v3', version_info.current_version)
      assert.equals('v4.0.0', version_info.latest_version)
      assert.is_false(version_info.is_latest)
      assert.is_nil(version_info.error)
    end)

    it('should create version info for latest version', function()
      ---@type Action
      local action = {
        owner = 'actions',
        repo = 'checkout',
        version = 'v4',
        line = 5,
        col = 12,
      }

      local version_info = version_checker.create_version_info(action, 'v4.0.0')

      assert.equals('v4', version_info.current_version)
      assert.equals('v4.0.0', version_info.latest_version)
      assert.is_true(version_info.is_latest)
    end)

    it('should handle error case', function()
      ---@type Action
      local action = {
        owner = 'actions',
        repo = 'checkout',
        version = 'v3',
        line = 5,
        col = 12,
      }

      local version_info = version_checker.create_version_info(action, nil, 'API error')

      assert.equals(5, version_info.line)
      assert.equals('v3', version_info.current_version)
      assert.is_nil(version_info.latest_version)
      assert.equals('API error', version_info.error)
    end)
  end)
end)
