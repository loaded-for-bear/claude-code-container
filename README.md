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
3. 初回はDockerイメージのビルドに **10〜20分** かかります（Flutter・Rust含む）
4. 左下が `Dev Container: Claude Code Development Environment` に変わったら完了

**方法B: 左下のアイコン**

1. VS Code 左下の緑色の `><` アイコンをクリック
2. `Reopen in Container` を選択

### 手順3: Claude Code の認証

コンテナ内のターミナル (`Ctrl+`` `) で実行:

```bash
# バージョン確認（Dockerfile内でインストール済み）
claude --version

# ログイン（ブラウザ認証）
claude login

# または環境変数でAPI Keyを設定
export ANTHROPIC_API_KEY="your-api-key-here"
```

> **Warning**
> APIキーや認証情報を `.env` ファイルや環境変数で管理し、**絶対にGitにコミットしないでください。**
> `.gitignore` で `.env` は除外済みですが、コミット前に `git diff --staged` で機密情報が含まれていないか確認することを推奨します。

### セキュリティオプション: ネットワーク制限モード

Claude Code にファイルシステムへのアクセスのみを許可し、外部ネットワークへのアクセスを制限する場合:

```bash
# ネットワーク制限モードで起動（外部API呼び出しやWebフェッチを禁止）
claude --network=none
```

AIエージェントが意図しない外部通信をしないことを保証したい場合に有効です。
通常の開発用途では不要ですが、コードレビューや機密プロジェクト作業時に推奨します。

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
├── .gitignore              # 機密ファイル除外ルール
├── docker compose.yml      # Docker Compose 設定
├── workspace/              # マウントされる作業ディレクトリ
├── LICENSE                 # MIT License
└── README.md
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

### コンテナ内のツールが古い場合

コンテナを再ビルドしてください。pip / cargo / npm のキャッシュはボリュームに保存されているため、再ビルドでも高速です。

```powershell
docker compose up -d --build
```

### コンテナ内で pip install がエラーになる場合

Ubuntu 24.04 の PEP 668 制限により、システム Python への直接インストールは禁止されています。
このコンテナは `/opt/venv` を使用しており、通常の `pip install` は自動的に venv 内に入ります。
エラーが出る場合は、`which pip` で `/opt/venv/bin/pip` が使われているか確認してください。

```bash
which pip        # → /opt/venv/bin/pip であればOK
which python     # → /opt/venv/bin/python であればOK
```

## Changelog

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
