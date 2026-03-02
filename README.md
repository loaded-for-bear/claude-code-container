# Claude Code Development Environment

Docker Compose と VS Code Dev Containers を使用した Claude Code 開発環境

## 環境構成

| カテゴリ | ツール |
|---------|--------|
| OS | Ubuntu 24.04 |
| Node.js | 22.x (LTS) / npm, yarn, pnpm |
| Python | 3.12 / pip, venv |
| Rust | stable / cargo |
| Flutter | stable (Web) / オプション（デフォルト無効） |
| AI | Claude Code (npm経由でインストール済み) |

## コンテナ構成

```
claude-code-container   ← 開発コンテナ（internal ネットワーク）
claude-code-egress-proxy ← Squid プロキシ（allowlist 以外のドメインをブロック）
```

`claude-code` コンテナはインターネットに直接接続できず、全ての外部通信は `egress-proxy` 経由となります。

## 前提条件

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) がインストール済み
- [VS Code](https://code.visualstudio.com/) がインストール済み
- VS Code 拡張機能 [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) がインストール済み

## セットアップ手順

### 手順1: プロジェクトを開く

1. VS Code でこのフォルダ (`claude-code-container`) を開く
2. 左下に緑色の `><` アイコンが表示されていることを確認

### 手順2: コンテナをビルド・起動

**方法A: コマンドパレット（推奨）**

1. `F1` キーまたは `Ctrl+Shift+P`
2. `Dev Containers: Reopen in Container` と入力して選択
3. 初回はDockerイメージのビルドに **5〜10分** かかります（Flutter なし・デフォルト）
4. 左下が `Dev Container: Claude Code Development Environment` に変わったら完了

**方法B: 左下のアイコン**

1. VS Code 左下の緑色の `><` アイコンをクリック
2. `Reopen in Container` を選択

### 手順3: Claude Code の認証

コンテナ内のターミナル (`` Ctrl+` ``) で実行:

```bash
# バージョン確認（Dockerfile内でインストール済み）
claude --version

# ログイン（ブラウザ認証）
claude

# または環境変数でAPI Keyを設定
export ANTHROPIC_API_KEY="your-api-key-here"
```

> **Warning**
> APIキーや認証情報を `.env` ファイルや環境変数で管理し、**絶対にGitにコミットしないでください。**
> `.gitignore` で `.env` は除外済みですが、コミット前に `git diff --staged` で機密情報が含まれていないか確認することを推奨します。

### 手順4: Git ユーザー設定（プロジェクトごと）

デフォルトでは `Developer / dev@example.com` が設定されています。
プロジェクトごとに変更する場合:

```bash
cd /workspace/your-project
git config user.name "Your Name"
git config user.email "your-email@example.com"
```

### 手順5: GitHub 接続（push する場合）

Public リポジトリの clone は認証不要ですが、push には認証が必要です。
GitHub CLI はインストール済みです。

```bash
# ブラウザ認証
gh auth login
```

## 日常の使い方

### コンテナへの接続

VS Code でプロジェクトフォルダを開き、左下の `><` → `Reopen in Container` を選択。
既にコンテナが起動済みであれば数秒で接続されます。

### ポート一覧

| ポート | 用途 |
|--------|------|
| 3000 | Node.js アプリ |
| 5000 | Flask / Python |
| 5173 | Flutter Web / Vite |
| 8080 | Web サーバー |
| 8888 | Jupyter |

### ファイル構成

```
claude-code-container/
├── .devcontainer/
│   ├── Dockerfile          # コンテナイメージ定義
│   └── devcontainer.json   # VS Code Dev Container 設定
├── egress-proxy/
│   ├── squid.conf          # Squid プロキシ設定（固定 allowlist）
│   └── allowlist.txt       # 動的 allowlist（スクレイピング対象ドメイン等）
├── workspace/              # マウントされる作業ディレクトリ
├── .gitignore
├── docker-compose.yml          # Docker Compose 設定
├── docker-compose.debug.yml    # デバッグモード（SYS_PTRACE 付与）
├── docker-compose.isolated.yml # ネットワーク完全隔離モード
├── LICENSE
├── README.md
└── REBUILD.md                  # 再ビルド手順
```

## Docker 管理コマンド

ホスト側（PowerShell / ターミナル）で実行:

```powershell
# コンテナの起動
docker compose up -d

# コンテナの停止
docker compose down

# コンテナの再構築（Dockerfile変更後）
docker compose up -d --build

# キャッシュなしで再構築
docker compose build --no-cache && docker compose up -d

# ログの確認
docker compose logs -f claude-code

# コンテナ内でコマンド実行
docker compose exec claude-code bash
```

## セキュリティ設定

### ネットワーク制御（Egress Proxy）

全ての外部通信は `egress-proxy`（Squid）を経由します。
allowlist に含まれないドメインへのアクセスは自動的にブロックされます。

**固定 allowlist（`egress-proxy/squid.conf` 内 `fixed_domains`）:**
- `*.anthropic.com`, `*.claude.ai`, `*.claude.com` — Claude Code API
- `*.github.com`, `*.githubusercontent.com` — git / gh CLI
- `registry.npmjs.org`, `*.npmjs.com` — npm
- `pypi.org`, `files.pythonhosted.org` — pip
- `*.crates.io`, `*.rust-lang.org` — cargo
- `*.vo.msecnd.net`, `*.vsassets.io` — VS Code Marketplace

**動的 allowlist（`egress-proxy/allowlist.txt`）:**

スクレイピング対象など、追加したいドメインをここに記述します:

```
# egress-proxy/allowlist.txt
.note.com
.wikipedia.org
```

追記後は再ビルド不要で反映されます:

```powershell
docker compose restart egress-proxy
```

### デバッグモード（VS Code デバッガー使用時）

VS Code の vscode-lldb 拡張（プロセスアタッチ）を使用する場合のみ、`SYS_PTRACE` capability を付与して起動します:

```powershell
docker compose -f docker-compose.yml -f docker-compose.debug.yml up -d
```

デバッグが不要になったら通常起動に戻します:

```powershell
docker compose down
docker compose up -d
```

> **注意**: `SYS_PTRACE` はプロセスアタッチを可能にするため、通常の開発作業では不要です。
> デバッグ用途に限定して使用してください。

### ネットワーク完全隔離モード

全ての外部通信を遮断する場合:

```powershell
docker compose -f docker-compose.yml -f docker-compose.isolated.yml up -d
```

> **注意**: このモードでは `git pull`, `npm install`, `pip install` 等も不可になります。
> 既存コードのレビュー・実行専用として使用してください。

### その他のセキュリティ設定

- **非 root ユーザー**: `developer`（UID 1000）で実行
- **Linux Capabilities**: `cap_drop: ALL` で全権限を剥奪。デバッグ時のみ `SYS_PTRACE` を付与（`docker-compose.debug.yml` 参照）
- **リソース制限**: CPU 4 コア / メモリ 6GB / プロセス数 512
- **npm ignore-scripts**: インストール時の自動スクリプト実行を禁止
- **git hooks 無効化**: グローバルフックを空ディレクトリに向け無効化
- **Dockerfile ビルド時 npm スクリプト**: 公式パッケージのみ対象・HTTPS + npm 署名検証で保護（受容済み）
- **`claude-config` ボリューム**: `~/.claude` に Claude 認証トークンが平文で保存される。ボリュームを削除する場合は `docker compose down -v`（削除後は再認証が必要）。Docker ボリューム（`/var/lib/docker/volumes/`）への物理アクセスを適切に管理すること。

## トラブルシューティング

### ビルドに失敗する場合

```powershell
docker compose build --no-cache
docker compose up -d
```

### ファイルの変更が反映されない場合

```powershell
docker compose restart claude-code
```

### コンテナ内で pip install がエラーになる場合

Ubuntu 24.04 の PEP 668 制限により、システム Python への直接インストールは禁止されています。
このコンテナは `/opt/venv` を使用しており、通常の `pip install` は自動的に venv 内に入ります。
エラーが出る場合は、`which pip` で `/opt/venv/bin/pip` が使われているか確認してください。

```bash
which pip        # → /opt/venv/bin/pip であればOK
which python     # → /opt/venv/bin/python であればOK
```

### スクレイピングが 403 になる場合

`egress-proxy/allowlist.txt` に対象ドメインを追記して再起動:

```powershell
docker compose restart egress-proxy
```

### VS Code 拡張機能が「互換性なし」と表示される場合

ターミナルから強制インストール:

```bash
code --install-extension <extension-id>
```

## Changelog

### 2026-02-27

- **Egress Proxy 強化**: `squid.conf` を再設計
  - `fixed_domains`: `.claude.ai`, `.claude.com`, `.githubcopilot.com`, `.rust-lang.org`, VS Code Marketplace ドメインを追加
  - `scraping_sites`: 動的 allowlist を外部ファイル（`allowlist.txt`）として分離
  - `user: proxy` を明示指定（最小権限での Squid 実行）
  - `pid_filename`, `coredump_dir` を `/tmp` に設定
- **pids_limit**: `deploy.resources.limits.pids` に統合（Compose V2 準拠）

### 2026-02-26 (5)

- **セキュリティ (C-1)**: `sudo` を Dockerfile から完全削除 — `apt-get` フック経由の root 昇格バイパスを根本排除
  - パッケージ追加が必要な場合は Dockerfile を編集して再ビルド
- **セキュリティ (H-5)**: `docker-compose.yml` にリソース制限を追加（DoS・暴走プロセス対策）
  - CPU: 最大 4 コア / メモリ: 最大 6GB / プロセス数: 最大 512 / ファイル記述子: 最大 4096

### 2026-02-26 (4)

- **セキュリティ (3-A 強化)**: `INSTALL_FLUTTER` のデフォルトを `true` → **`false`** に変更（Flutter/Chromium を明示的 opt-in に）
  - `docker-compose.yml` の `build.args` および `Dockerfile` の `ARG` デフォルト値を変更
  - 初回ビルドが高速化（約 20 分 → 約 5 分）、イメージサイズ・攻撃面を大幅縮小
  - Flutter が必要な場合は `INSTALL_FLUTTER: "true"` に変更してリビルド

### 2026-02-26 (3)

- **セキュリティ (2-A)**: `sudo` を `apt-get / apt` のみに制限（全権限昇格リスクを低減）
- **セキュリティ (2-B)**: `docker-compose.isolated.yml` を追加（コンテナレベルのネットワーク完全遮断）
- **セキュリティ (3-A)**: Flutter/Chromium をオプション化（`INSTALL_FLUTTER: "false"` でスキップ可能）
- **セキュリティ (3-B)**: `no-new-privileges:true` を追加（setuid による権限昇格を禁止）

### 2026-02-26 (2)

- **セキュリティ (1-A)**: 非rootユーザー `developer`（UID 1000）を導入 — `remoteUser: root` 廃止
- **セキュリティ (1-B)**: Cargo の `chmod -R a+w` を `chown developer + chmod 755` に修正
- ボリュームマウントパスを `/root/` → `/home/developer/` に統一
- `NPM_CONFIG_PREFIX` を `/home/developer/.npm-global` に変更

### 2026-02-26

- **セキュリティ**: `claude --network=none` オプションの説明を追加
- **バグ修正**: `CHROME_EXECUTABLE` を `chromium-browser` → `chromium` に修正（Ubuntu 24.04 対応漏れ）
- **Node.js**: 20 → **22 (Active LTS)** にアップグレード（Node.js 20 は 2026-04-30 EOL）
- **Ubuntu**: 22.04 → **24.04 LTS** にアップグレード（Python 3.10 は 2026-10 EOL）
- **Python**: 3.10 → **3.12** / PEP 668 対応として `/opt/venv` を導入
- **Claude Code**: インストール方法を `curl install.sh` → `npm install -g @anthropic-ai/claude-code` に変更
- **ツール追加**: `ruff` (Python linter) を追加
- **Docker Compose**: コマンドを V1 (`docker-compose`) → V2 (`docker compose`) 形式に統一

### 2026-02-24

- 初回リリース: Docker Compose + VS Code Dev Containers による Claude Code 開発環境テンプレート

## License

This project is licensed under the [MIT License](LICENSE).
