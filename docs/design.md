# GitHub Actions Neovim Plugin Design Document

## Overview

GitHub ActionsのワークフローをNeovim内で操作・管理するためのLuaプラグイン。
crates.nvimと同様のアプローチで、GitHub Actionsのバージョン情報をvirtual textで表示し、
ワークフローの実行管理機能を提供する。

## Core Features

### Phase 1: Version Display (Initial Implementation)
- GitHub Actionsのバージョン情報をvirtual textで表示
- `.github/workflows/*.yml` ファイルでの動作
- 最新バージョンとの比較表示

### Phase 2: Workflow Operations
- Workflow の watch
- Workflow の dispatch
- Workflow の rerun

## Architecture

### Directory Structure

```
github-actions.nvim/
├── lua/
│   └── github-actions/
│       ├── init.lua              # Main entry point
│       ├── config.lua            # Configuration management
│       ├── gh/
│       │   └── cli.lua           # gh command wrapper
│       ├── ui/
│       │   ├── virtual_text.lua  # Virtual text rendering
│       │   └── highlights.lua    # Highlight groups
│       ├── parser/
│       │   └── workflow.lua      # Workflow file parser (treesitter)
│       └── utils/
│           ├── cache.lua         # Version cache (in-memory only)
│           └── logger.lua        # Logging utilities
├── ftplugin/
│   └── yaml.lua                  # Filetype-specific initialization
├── plugin/
│   └── github-actions.lua        # Autoload initialization
├── doc/
│   └── github-actions.txt        # Vim help documentation
├── test/
│   ├── minimal_init.lua          # Minimal config for testing
│   └── spec/
│       ├── parser_spec.lua
│       ├── gh_cli_spec.lua
│       └── virtual_text_spec.lua
└── scripts/
    └── generate_docs.lua         # Documentation generation
```

### Module Responsibilities

#### `lua/github-actions/init.lua`
- プラグインのメインエントリポイント
- `setup(opts)` 関数の提供
- デフォルト設定の定義
- 遅延ロードのサポート

#### `lua/github-actions/config.lua`
- 設定の管理と検証
- ユーザー設定とデフォルト設定のマージ
- 設定値のバリデーション

#### `lua/github-actions/gh/cli.lua`
- `gh` コマンドのラッパー
- リリース情報の取得 (`gh api repos/{owner}/{repo}/releases/latest`)
- タグ情報の取得 (`gh api repos/{owner}/{repo}/tags`)
- コマンド実行のエラーハンドリング
- 非同期実行サポート

#### `lua/github-actions/ui/virtual_text.lua`
- Extmarks API を使用した virtual text の描画
- バッファごとの namespace 管理
- virtual text の更新・削除

#### `lua/github-actions/ui/highlights.lua`
- ハイライトグループの定義
- カラースキーム対応

#### `lua/github-actions/parser/workflow.lua`
- Treesitter を使用したワークフローファイルのパース
- Actions の uses 句の抽出
- バージョン情報の抽出
- 行番号とカラム位置の取得

#### `lua/github-actions/utils/cache.lua`
- バージョン情報のインメモリキャッシュ
- プラグイン起動中のみ有効
- キャッシュのクリア機能

#### `lua/github-actions/utils/logger.lua`
- デバッグログの出力
- ログレベルの管理

### Data Flow

```
User opens .github/workflows/*.yml
         ↓
ftplugin/yaml.lua detects workflow file
         ↓
parser/workflow.lua extracts actions (via treesitter)
         ↓
Check utils/cache.lua for cached versions
         ↓
gh/cli.lua fetches latest version info via `gh api`
         ↓
utils/cache.lua stores results (in-memory)
         ↓
ui/virtual_text.lua renders version info
```

## Configuration Design

### Default Configuration

```lua
{
  -- Virtual text display settings
  virtual_text = {
    enabled = true,
    prefix = " ",
    suffix = "",
    highlight = "Comment",
    -- Icons for version status
    icons = {
      outdated = "",  -- Nerd Font icon for update available
      latest = "",    -- Nerd Font icon for latest version
    },
  },

  -- gh CLI settings
  gh = {
    -- gh command path (default: "gh")
    cmd = "gh",
  },

  -- Cache settings (in-memory only)
  cache = {
    enabled = true,
  },

  -- Logging
  log = {
    level = "warn", -- "trace", "debug", "info", "warn", "error"
  },

  -- Auto-update settings
  auto_update = {
    -- Automatically check for updates when opening workflow files
    enabled = true,
    -- Debounce time in milliseconds
    debounce = 1000,
  },
}
```

### User Configuration Example

```lua
require('github-actions').setup({
  gh = {
    cmd = "/usr/local/bin/gh",  -- Custom gh path if needed
  },
  virtual_text = {
    prefix = " ",
    icons = {
      outdated = "",
      latest = "",
    },
  },
})
```

## API Design

### Public API

#### Setup Function
```lua
require('github-actions').setup(opts)
```

#### Commands
```vim
:GitHubActions update         " Manually update version info
:GitHubActions clear          " Clear virtual text
:GitHubActions toggle         " Toggle virtual text display
:GitHubActions cache clear    " Clear cache
:GitHubActions cache info     " Show cache info
```

#### Lua API
```lua
local gh_actions = require('github-actions')

-- Manually trigger update for current buffer
gh_actions.update_buffer()

-- Get action info at cursor position
gh_actions.get_action_at_cursor()

-- Clear virtual text in buffer
gh_actions.clear_buffer()
```

## Virtual Text Implementation

### Extmarks Strategy

- **Namespace per buffer**: 各バッファに独立した namespace を作成
- **Priority**: `vim.highlight.priorities.user` を使用
- **Ephemeral**: 一時的な表示には ephemeral option を使用
- **Right gravity**: デフォルトの true を使用

### Version Display Format

アップデート可能な場合は `` アイコン、最新の場合は `` アイコンを表示

```yaml
uses: actions/checkout@v3  #  4.0.0
uses: actions/setup-node@v3  #  3.1.0
```

### Highlight Groups

```lua
-- Default highlight groups
vim.api.nvim_set_hl(0, 'GitHubActionsVersion', { link = 'Comment' })
vim.api.nvim_set_hl(0, 'GitHubActionsVersionLatest', { link = 'String' })
vim.api.nvim_set_hl(0, 'GitHubActionsVersionOutdated', { link = 'WarningMsg' })
vim.api.nvim_set_hl(0, 'GitHubActionsIconLatest', { link = 'String' })
vim.api.nvim_set_hl(0, 'GitHubActionsIconOutdated', { link = 'WarningMsg' })
```

## gh CLI Integration

### gh CLI Commands

`gh` コマンドを使用してGitHub APIを呼び出す:

```bash
# 最新リリース情報を取得
gh api repos/{owner}/{repo}/releases/latest

# タグ一覧を取得
gh api repos/{owner}/{repo}/tags
```

### Prerequisites

- `gh` コマンドがインストールされていること (必須)
- `gh auth login` で認証済みであること (推奨)

### Error Handling

- `gh` コマンドが見つからない場合: エラーメッセージを表示
- 認証されていない場合: `gh auth login` を実行するように促す
- ネットワークエラー: キャッシュを使用、警告を表示
- API エラー: ログに記録、ユーザーに通知
- コマンドタイムアウト: 設定可能なタイムアウト値

### Async Execution

`vim.system` (Neovim 0.10+) または `vim.loop` を使用して非同期実行:

```lua
local function gh_api_async(endpoint, callback)
  vim.system(
    { 'gh', 'api', endpoint },
    { text = true },
    function(result)
      if result.code == 0 then
        local data = vim.json.decode(result.stdout)
        callback(nil, data)
      else
        callback(result.stderr, nil)
      end
    end
  )
end
```

## Parser Implementation

### Treesitter-based Parsing

Neovimのビルトイン treesitter を使用してワークフローファイルをパース:

```lua
local function get_actions_from_treesitter(bufnr)
  -- Check if treesitter parser is available
  local has_parser = pcall(vim.treesitter.get_parser, bufnr, 'yaml')
  if not has_parser then
    vim.notify('yaml treesitter parser not found', vim.log.levels.ERROR)
    return {}
  end

  local parser = vim.treesitter.get_parser(bufnr, 'yaml')
  local tree = parser:parse()[1]
  local root = tree:root()

  -- Query for 'uses:' fields in workflow files
  local query = vim.treesitter.query.parse('yaml', [[
    (block_mapping_pair
      key: (flow_node) @key (#eq? @key "uses")
      value: (flow_node) @value)
  ]])

  local actions = {}
  for id, node in query:iter_captures(root, bufnr, 0, -1) do
    local name = query.captures[id]
    if name == 'value' then
      local text = vim.treesitter.get_node_text(node, bufnr)
      local row, col = node:range()

      -- Parse: owner/repo@version
      local owner, repo, version = text:match("([^/]+)/([^@]+)@(.+)")
      if owner and repo and version then
        table.insert(actions, {
          line = row,
          col = col,
          owner = owner,
          repo = repo,
          version = version,
          text = text,
        })
      end
    end
  end

  return actions
end
```

### Prerequisites

- `nvim-treesitter` の yaml パーサーがインストールされていること
- `:TSInstall yaml` でインストール可能

## Testing Strategy

### Testing Framework

- **plenary.nvim**: Neovimプラグインの標準的なテストフレームワーク
- **minimal_init.lua**: テスト用の最小構成

### Test Categories

#### Unit Tests
- Parser logic
- Version comparison
- Cache management
- Configuration validation

#### Integration Tests
- gh CLI interaction (with mock)
- Virtual text rendering
- Buffer operations

#### E2E Tests
- Full workflow: ファイルを開く → パース → API呼び出し → 表示

### Test Structure Example

```lua
-- test/spec/parser_spec.lua
local parser = require('github-actions.parser.workflow')

describe('workflow parser', function()
  it('should extract actions from workflow', function()
    local lines = {
      '    uses: actions/checkout@v3',
      '    uses: docker/setup-buildx-action@v2',
    }
    local actions = parser.parse_lines(lines)
    assert.equals(2, #actions)
    assert.equals('actions', actions[1].owner)
    assert.equals('checkout', actions[1].repo)
    assert.equals('v3', actions[1].version)
  end)
end)
```

### Mock Strategy

gh CLI のモック:

```lua
-- test/helpers/mock_gh.lua
local mock_gh = {
  api = function(endpoint)
    if endpoint:match('releases/latest') then
      return vim.json.encode({
        tag_name = 'v4.1.0',
        published_at = '2024-01-01T00:00:00Z',
      })
    elseif endpoint:match('tags') then
      return vim.json.encode({
        { name = 'v4.1.0' },
        { name = 'v4.0.0' },
      })
    end
  end,
}
```

## Performance Considerations

### Lazy Loading
- プラグインは `.github/workflows/*.yml` ファイルを開いたときのみ読み込み
- `ftplugin/yaml.lua` でファイルタイプ検出
- 必要なモジュールのみ require

### Debouncing
- ファイル編集時の再パースをデバウンス
- gh CLI 呼び出しの頻度制限

### Caching
- バージョン情報をメモリにキャッシュ (プラグイン起動中のみ)
- 同じリポジトリへの重複リクエストを防止
- キャッシュクリアコマンドで手動リフレッシュ可能

### Async Operations
- gh CLI 呼び出しを非同期化
- `vim.system` (Neovim 0.10+) を使用した非同期処理
- ブロッキングを避ける

```lua
local function fetch_version_async(owner, repo, callback)
  vim.system(
    { 'gh', 'api', string.format('repos/%s/%s/releases/latest', owner, repo) },
    { text = true },
    function(result)
      if result.code == 0 then
        local data = vim.json.decode(result.stdout)
        callback(nil, data)
      else
        callback(result.stderr, nil)
      end
    end
  )
end
```

## Dependencies

### Required
- Neovim >= 0.10.0 (for `vim.system` API)
- `gh` CLI: GitHub API呼び出し (必須)
- `nvim-treesitter` with yaml parser: ワークフローファイルのパース

### Optional
- `plenary.nvim`: テストフレームワーク (開発時のみ)

## Security Considerations

### Authentication
- `gh` CLI の認証機能を使用
- プラグイン側でトークンを管理しない
- ユーザーは `gh auth login` で事前に認証

### Command Execution
- `gh` コマンドの実行パスを検証
- コマンドインジェクション対策
- タイムアウトの設定

## Documentation

### Help Documentation (`:help github-actions`)
- インストール方法
- 設定オプション
- コマンド一覧
- API リファレンス
- トラブルシューティング

### README.md
- プラグインの概要
- スクリーンショット
- クイックスタート
- 設定例
- FAQ

### Type Annotations (LuaCATS)
すべてのパブリックAPIに型アノテーションを追加:

```lua
---@class GitHubActionsConfig
---@field virtual_text table Virtual text settings
---@field gh table gh CLI settings
---@field cache table Cache settings

---Setup the plugin
---@param opts GitHubActionsConfig|nil User configuration
function M.setup(opts)
  -- ...
end
```

## Release Strategy

### Versioning
- Semantic Versioning (SemVer) を使用
- Git tags でバージョン管理
- GitHub Releases で変更履歴を公開

### Distribution
- GitHub repository
- luarocks (optional)
- プラグインマネージャー対応:
  - lazy.nvim
  - packer.nvim
  - vim-plug
  - dein.vim

## Future Enhancements

### Phase 2 Features
- Workflow execution (watch, dispatch, rerun)
- Job status display
- Real-time log streaming
- Interactive workflow selection
- Workflow templates

### Additional Ideas
- Dependabot integration
- Security vulnerability alerts
- Workflow visualization
- Custom action suggestions
- Performance metrics

## References

- [Neovim Lua Guide](https://neovim.io/doc/user/lua-guide.html)
- [nvim-best-practices](https://github.com/nvim-neorocks/nvim-best-practices)
- [crates.nvim](https://github.com/saecki/crates.nvim) - Similar plugin for inspiration
- [GitHub CLI Manual](https://cli.github.com/manual/)
- [Extmarks API](https://neovim.io/doc/user/api.html#api-extmark)
- [Treesitter API](https://neovim.io/doc/user/treesitter.html)
