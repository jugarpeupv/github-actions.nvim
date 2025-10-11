# Integration Implementation Plan

## Overview

統合レイヤーの実装: Parser → gh CLI → Virtual Text の完全なフローを実現する。

## Implementation Phases

### Phase 1: gh CLI Wrapper Module (gh/cli.lua)

#### 目的
`gh` コマンドを使用してGitHub APIから最新リリース情報を取得する。

#### モジュール仕様

```lua
---@class GhCli
local M = {}

---Fetch latest release information for a GitHub repository
---@param owner string Repository owner (e.g., "actions")
---@param repo string Repository name (e.g., "checkout")
---@param callback function Callback function(err, data)
function M.fetch_latest_release(owner, repo, callback)
end

---Parse gh API response (testable without API call)
---@param json_str string JSON response from gh api
---@return table|nil data Parsed data or nil on error
---@return string|nil error Error message if parsing failed
function M.parse_response(json_str)
end

---Extract version from release data
---@param release_data table Parsed release data
---@return string|nil version Version string (e.g., "4.1.0")
function M.extract_version(release_data)
end

---Check if gh command is available
---@return boolean available
function M.is_available()
end

---Get gh command path
---@return string|nil gh_path
function M.get_gh_path()
end

return M
```

#### API呼び出し例

```bash
# 最新リリース情報を取得
gh api repos/actions/checkout/releases/latest

# レスポンス例
{
  "tag_name": "v4.1.0",
  "name": "v4.1.0",
  "published_at": "2024-01-15T10:00:00Z",
  ...
}
```

#### エラーハンドリング

1. **ghコマンドが見つからない**
   - `vim.fn.executable('gh') == 0`
   - エラーメッセージ: "gh command not found. Please install GitHub CLI."

2. **認証エラー**
   - `result.code == 1` かつ `stderr` に "authentication" を含む
   - エラーメッセージ: "gh auth login required"

3. **ネットワークエラー**
   - タイムアウトまたは接続エラー
   - エラーメッセージ: "Network error. Please check your connection."

4. **APIエラー（404 Not Found）**
   - リポジトリが存在しない、またはリリースがない
   - エラーメッセージ: "No releases found for {owner}/{repo}"

#### TDD Approach

**Fixture Helper作成:**
```lua
-- spec/helpers/fixture.lua
local M = {}

---Load JSON fixture file
---@param name string Fixture name (e.g., "gh_api_releases_latest_success")
---@return string json_str
function M.load(name)
  local path = string.format('spec/fixtures/%s.json', name)
  local file = io.open(path, 'r')
  if not file then
    error('Fixture not found: ' .. path)
  end
  local content = file:read('*all')
  file:close()
  return content
end

return M
```

**RED Phase - 失敗するテスト:**
```lua
local fixture = require('spec.helpers.fixture')

describe('gh.cli', function()
  describe('parse_response', function()
    it('should parse successful response', function()
      local json_str = fixture.load('gh_api_releases_latest_success')
      local gh_cli = require('github-actions.gh.cli')

      local data, err = gh_cli.parse_response(json_str)

      assert.is_nil(err)
      assert.is_not_nil(data)
      assert.equals('v4.1.0', data.tag_name)
    end)

    it('should handle invalid JSON', function()
      local gh_cli = require('github-actions.gh.cli')
      local data, err = gh_cli.parse_response('invalid json')

      assert.is_nil(data)
      assert.is_not_nil(err)
    end)
  end)

  describe('extract_version', function()
    it('should extract version from release data', function()
      local json_str = fixture.load('gh_api_releases_latest_success')
      local gh_cli = require('github-actions.gh.cli')

      local data = gh_cli.parse_response(json_str)
      local version = gh_cli.extract_version(data)

      assert.equals('4.1.0', version) -- "v4.1.0" -> "4.1.0"
    end)
  end)

  it('should detect gh availability', function()
    local gh_cli = require('github-actions.gh.cli')
    -- Test gh command detection (no API call needed)
    assert.is_boolean(gh_cli.is_available())
  end)
end)
```

**GREEN Phase - 最小実装:**
- `vim.system()` を使用して `gh api` を非同期実行
- JSON レスポンスをパース
- コールバックでエラーまたはデータを返す

**REFACTOR Phase:**
- エラーハンドリングの改善
- タイムアウト設定
- リトライロジック（オプション）

#### Implementation Details

```lua
-- Using vim.system for async execution (Neovim 0.10+)
local function gh_api_async(endpoint, callback)
  -- Check if gh is available
  if vim.fn.executable('gh') == 0 then
    callback('gh command not found', nil)
    return
  end

  -- Execute gh api command
  vim.system(
    { 'gh', 'api', endpoint },
    { text = true },
    function(result)
      if result.code == 0 then
        local ok, data = pcall(vim.json.decode, result.stdout)
        if ok then
          callback(nil, data)
        else
          callback('Failed to parse JSON response', nil)
        end
      else
        callback(result.stderr or 'Unknown error', nil)
      end
    end
  )
end
```

### Phase 2: Version Checker Module (utils/version_checker.lua)

#### 目的
Parserから得たActionデータをgh CLIで取得したリリース情報と照合し、`VersionInfo`を生成する。

#### モジュール仕様

```lua
---@class VersionChecker
local M = {}

---Check versions for multiple actions
---@param actions Action[] List of actions from parser
---@param callback function Callback function(version_infos)
function M.check_versions(actions, callback)
end

---Compare versions to determine if update is available
---@param current_version string Current version (e.g., "v3", "v3.5.0")
---@param latest_version string Latest version (e.g., "v4.1.0")
---@return boolean is_latest
function M.compare_versions(current_version, latest_version)
end

return M
```

#### データ変換フロー

```
Action[] (from parser)
  [{owner="actions", repo="checkout", version="v3", line=10, col=12}, ...]
    ↓
gh CLI fetch (for each action)
    ↓
Release Data
  {tag_name="v4.1.0", published_at="2024-01-15T10:00:00Z"}
    ↓
Version Comparison
    ↓
VersionInfo[]
  [{line=10, col=12, current_version="v3", latest_version="4.1.0", is_latest=false}, ...]
```

#### バージョン比較ロジック

**比較粒度の原則**: 書かれている部分のみを比較

1. **バージョン形式のパース**
   - `v3` → メジャーのみ: `{major: 3}`
   - `v3.5` → メジャー.マイナー: `{major: 3, minor: 5}`
   - `v3.5.1` → メジャー.マイナー.パッチ: `{major: 3, minor: 5, patch: 1}`

2. **比較ルール**

   **ケース1: メジャーのみ指定 (`v3`)**
   ```
   current: v3
   latest:  v5.2.1
   比較: メジャーのみ (3 vs 5) → outdated

   current: v4
   latest:  v4.1.0
   比較: メジャーのみ (4 vs 4) → latest
   ```

   **ケース2: メジャー.マイナー指定 (`v3.5`)**
   ```
   current: v3.5
   latest:  v4.1.0
   比較: メジャー.マイナー (3.5 vs 4.1) → outdated

   current: v4.1
   latest:  v4.1.5
   比較: メジャー.マイナー (4.1 vs 4.1) → latest
   ```

   **ケース3: フルバージョン (`v3.5.1`)**
   ```
   current: v3.5.1
   latest:  v3.5.2
   比較: メジャー.マイナー.パッチ (3.5.1 vs 3.5.2) → outdated

   current: v4.1.0
   latest:  v4.1.0
   比較: メジャー.マイナー.パッチ (4.1.0 vs 4.1.0) → latest
   ```

3. **比較アルゴリズム**
   ```lua
   function compare_versions(current, latest)
     local curr_parts = parse_version(current) -- {major, minor, patch}
     local latest_parts = parse_version(latest)

     -- 書かれている部分のみ比較
     local depth = #curr_parts -- 1, 2, or 3

     for i = 1, depth do
       if curr_parts[i] < latest_parts[i] then
         return false -- outdated
       elseif curr_parts[i] > latest_parts[i] then
         return true -- somehow newer (edge case)
       end
       -- Equal, continue to next part
     end

     return true -- latest (all compared parts are equal)
   end
   ```

4. **特殊ケース**
   - `main`, `master` などのブランチ名 → 常に outdated 扱い
   - ハッシュのみ → コメントのバージョンと比較
   - `v` プレフィックスの有無は無視 (`v3` == `3`)

#### TDD Approach

```lua
describe('utils.version_checker', function()
  describe('parse_version', function()
    it('should parse major only version', function()
      local parts = M.parse_version('v3')
      assert.same({3}, parts)
    end)

    it('should parse major.minor version', function()
      local parts = M.parse_version('v3.5')
      assert.same({3, 5}, parts)
    end)

    it('should parse full semver', function()
      local parts = M.parse_version('v3.5.1')
      assert.same({3, 5, 1}, parts)
    end)

    it('should handle version without v prefix', function()
      local parts = M.parse_version('4.1.0')
      assert.same({4, 1, 0}, parts)
    end)
  end)

  describe('compare_versions', function()
    -- Major only comparison
    it('should compare major versions only', function()
      assert.is_false(M.compare_versions('v3', 'v4.1.0')) -- outdated
      assert.is_true(M.compare_versions('v4', 'v4.1.0'))  -- latest (major matches)
      assert.is_false(M.compare_versions('v3', 'v5.0.0')) -- outdated
    end)

    -- Major.minor comparison
    it('should compare major.minor versions only', function()
      assert.is_false(M.compare_versions('v3.5', 'v4.1.0'))  -- outdated
      assert.is_true(M.compare_versions('v4.1', 'v4.1.5'))   -- latest (4.1 matches)
      assert.is_false(M.compare_versions('v4.0', 'v4.1.0'))  -- outdated
    end)

    -- Full version comparison
    it('should compare full semantic versions', function()
      assert.is_false(M.compare_versions('v3.5.1', 'v3.5.2')) -- outdated
      assert.is_true(M.compare_versions('v4.1.0', 'v4.1.0'))  -- latest
      assert.is_false(M.compare_versions('v4.1.0', 'v4.1.1')) -- outdated
    end)

    -- Edge cases
    it('should handle v prefix inconsistency', function()
      assert.is_true(M.compare_versions('v4', '4.1.0'))  -- v4 == 4
      assert.is_true(M.compare_versions('4', 'v4.1.0'))  -- 4 == v4
    end)
  end)

  describe('check_versions', function()
    it('should check versions for multiple actions', function()
      -- Test version checking with fixture data
    end)
  end)

  describe('special cases', function()
    it('should treat branch names as outdated', function()
      assert.is_false(M.compare_versions('main', 'v4.1.0'))
      assert.is_false(M.compare_versions('master', 'v4.1.0'))
    end)
  end)
end)
```

### Phase 3: Integration Module (init.lua または integrator.lua)

#### 目的
すべてのモジュールを統合し、エンドツーエンドのフローを実現する。

#### モジュール仕様

```lua
---@class Integrator
local M = {}

---Update virtual text for current buffer
---@param bufnr number Buffer number
---@param opts? table Options
function M.update_buffer(bufnr, opts)
end

---Setup auto-update on buffer open
---@param opts table Configuration options
function M.setup_auto_update(opts)
end

return M
```

#### 統合フロー

```lua
function M.update_buffer(bufnr, opts)
  -- Step 1: Parse workflow file
  local parser = require('github-actions.parser.workflow')
  local actions = parser.parse_buffer(bufnr)

  if #actions == 0 then
    return
  end

  -- Step 2: Check versions with gh CLI
  local version_checker = require('github-actions.utils.version_checker')
  version_checker.check_versions(actions, function(version_infos)
    -- Step 3: Render virtual text
    local virtual_text = require('github-actions.ui.virtual_text')
    virtual_text.clear_virtual_text(bufnr)
    virtual_text.set_virtual_texts(bufnr, version_infos, opts)
  end)
end
```

#### エラーハンドリング戦略

1. **Parserエラー**
   - 空配列を返す → virtual text を表示しない
   - ログに記録

2. **gh CLIエラー**
   - 個別のアクションでエラー → スキップして続行
   - すべてのアクションでエラー → ユーザーに通知

3. **Virtual Textエラー**
   - バッファが無効 → 何もしない
   - その他のエラー → ログに記録

### Phase 4: Testing Strategy

#### Unit Tests

1. **gh/cli.lua**
   - gh コマンドの実行
   - JSON パース
   - エラーハンドリング
   - モック gh コマンド

2. **utils/version_checker.lua**
   - バージョン比較ロジック
   - データ変換
   - 複数アクション処理

3. **Integration tests**
   - Parser → Version Checker → Virtual Text
   - エンドツーエンドフロー
   - エラーシナリオ

#### Test Structure

```lua
-- spec/gh/cli_spec.lua
describe('gh.cli', function()
  describe('fetch_latest_release', function()
    it('should fetch release data', function() end)
    it('should handle network errors', function() end)
    it('should handle auth errors', function() end)
  end)
end)

-- spec/utils/version_checker_spec.lua
describe('utils.version_checker', function()
  describe('check_versions', function()
    it('should check multiple actions', function() end)
  end)

  describe('compare_versions', function()
    it('should compare semantic versions', function() end)
  end)
end)

-- spec/checker_spec.lua
describe('checker', function()
  it('should update buffer with version info', function()
    -- Full flow test
  end)
end)
```

#### フィクスチャファイルを使ったテスト

1. **gh API レスポンスのフィクスチャ**
   ```
   spec/fixtures/
   ├── gh_api_releases_latest_success.json
   ├── gh_api_releases_latest_not_found.json
   └── gh_api_releases_latest_no_releases.json
   ```

   **例: spec/fixtures/gh_api_releases_latest_success.json**
   ```json
   {
     "tag_name": "v4.1.0",
     "name": "v4.1.0",
     "published_at": "2024-01-15T10:00:00Z",
     "body": "Release notes..."
   }
   ```

2. **フィクスチャを使ったテスト**
   ```lua
   describe('gh.cli', function()
     it('should parse successful response', function()
       -- Load fixture
       local fixture_path = 'spec/fixtures/gh_api_releases_latest_success.json'
       local file = io.open(fixture_path, 'r')
       local json_str = file:read('*all')
       file:close()

       -- Test parsing
       local gh_cli = require('github-actions.gh.cli')
       local data = gh_cli.parse_response(json_str)

       assert.equals('v4.1.0', data.tag_name)
     end)

     it('should handle error response', function()
       local fixture_path = 'spec/fixtures/gh_api_releases_latest_not_found.json'
       -- Test error handling
     end)
   end)
   ```

3. **フィクスチャの生成方法**
   ```bash
   # 実際のAPIレスポンスを保存
   gh api repos/actions/checkout/releases/latest > spec/fixtures/gh_api_releases_latest_success.json
   gh api repos/actions/setup-node/releases/latest > spec/fixtures/gh_api_setup_node_success.json

   # エラーレスポンス（存在しないリポジトリ）
   gh api repos/nonexistent/repo/releases/latest 2>&1 | jq > spec/fixtures/gh_api_releases_latest_not_found.json
   ```

## Implementation Order

### Week 1: gh CLI Wrapper
1. Day 1-2: TDD - gh/cli.lua
   - ✅ Write failing tests
   - ✅ Implement basic functionality
   - ✅ Error handling

2. Day 3: Testing & Refinement
   - ✅ Edge cases
   - ✅ Timeout handling
   - ✅ Documentation

### Week 2: Version Checker
1. Day 1-2: TDD - utils/version_checker.lua
   - ✅ Version comparison logic
   - ✅ Data transformation
   - ✅ Multiple actions handling

2. Day 3: Integration
   - ✅ Connect parser → version checker
   - ✅ Connect version checker → virtual text

### Week 3: Integration & Polish
1. Day 1-2: Integration module
   - ✅ End-to-end flow
   - ✅ Auto-update setup
   - ✅ Configuration

2. Day 3: Documentation & Examples
   - ✅ Usage examples
   - ✅ Troubleshooting guide
   - ✅ README updates

## Success Criteria

1. ✅ All tests passing (unit + checker)
2. ✅ gh CLI errors handled gracefully
3. ✅ Virtual text displays correctly for:
   - Latest versions (green icon)
   - Outdated versions (yellow icon)
   - Hash-based versions
4. ✅ Performance: < 1s for 10 actions
5. ✅ No blocking on main thread

## Dependencies

- Neovim >= 0.10.0 (`vim.system` API)
- `gh` CLI installed and authenticated
- Existing modules:
  - ✅ parser/workflow.lua
  - ✅ ui/virtual_text.lua

## Risks & Mitigation

1. **Risk**: gh コマンドが遅い
   - **Mitigation**: 非同期実行 + タイムアウト

2. **Risk**: Rate limiting by GitHub API
   - **Mitigation**: キャッシュ機能（後で実装）

3. **Risk**: ネットワークエラー
   - **Mitigation**: エラーメッセージ表示 + リトライオプション

## Next Steps

1. ✅ Review this plan
2. 🚧 Start Phase 1: gh CLI Wrapper (TDD)
3. ⏳ Phase 2: Version Checker
4. ⏳ Phase 3: Integration
5. ⏳ Phase 4: Testing & Documentation
