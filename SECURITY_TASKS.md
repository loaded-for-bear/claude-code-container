# セキュリティリスク対応タスク

claude-code-container のセキュリティリスク洗い出しと対応状況。

最終更新: 2026-02-26（C-3 完了）

---

## 対応状況まとめ

| 優先度 | ID | リスク | 対応状況 |
|--------|-----|--------|---------|
| 🔴 Critical | C-1 | `sudo apt-get` フック経由の root 昇格バイパス | ✅ 完了 |
| 🔴 Critical | C-2 | プロンプトインジェクション（AIエージェント固有） | ⚠️ 構造的問題・運用でカバー |
| 🔴 Critical | C-3 | アウトバウンド通信無制限（認証情報の外部送信） | ✅ 完了 |
| 🟠 High | H-1 | npm/pip/cargo install スクリプトによる任意コード実行 | ❌ 未対処 |
| 🟠 High | H-2 | git hooks による任意コード実行 | ❌ 未対処 |
| 🟠 High | H-3 | シンボリックリンクによるホスト fs アクセス | ❌ 未対処 |
| 🟠 High | H-4 | ポートフォワード × WSL2 のネットワーク公開 | ❌ 未対処 |
| 🟠 High | H-5 | リソース制限なし（DoS） | ✅ 完了 |
| 🟡 Medium | M-1 | パッケージバージョン未固定（サプライチェーン） | ❌ 未対処 |
| 🟡 Medium | M-2 | Flutter 無効でも libgtk-3-dev 等が残存 | ❌ 未対処 |
| 🟡 Medium | M-3 | npm-global/cargo-registry ボリュームの汚染持続 | ❌ 未対処 |
| 🟡 Medium | M-4 | VS Code 拡張機能のバージョン未固定 | ❌ 未対処 |
| 🟡 Medium | M-5 | `curl \| bash` ビルド（再現性・サプライチェーン） | ❌ 未対処 |
| 🔵 Low | L-1 | Linux Capabilities 未削減 | ❌ 未対処 |
| 🔵 Low | L-2 | seccomp カスタムプロファイルなし | ❌ 未対処 |
| 🔵 Low | L-3 | 偵察ツールのプリインストール（net-tools 等） | ❌ 未対処 |

---

## 完了済み対応

### ✅ 1-A: 非rootユーザー `developer`（UID 1000）を導入
- `remoteUser: root` を廃止
- ボリュームマウントパスを `/root/` → `/home/developer/` に統一

### ✅ 1-B: Cargo パーミッション修正
- `chmod -R a+w` → `chown developer + chmod 755`

### ✅ 2-A → C-1: sudo を完全削除
- `sudo` パッケージを Dockerfile から除去
- sudoers エントリも除去
- `apt-get` フックによる root 昇格バイパスを根本排除
- パッケージ追加は Dockerfile 編集 → 再ビルドで対応

### ✅ 2-B: ネットワーク隔離モード
- `docker-compose.isolated.yml` を追加（`network_mode: none`）
- コードレビュー・実行専用として使用可能

### ✅ 3-A: Flutter/Chromium のオプション化
- `INSTALL_FLUTTER=false` をデフォルトに変更（opt-in 方式）
- ビルド時間: 約 20 分 → 約 5 分、イメージサイズ大幅削減

### ✅ 3-B: no-new-privileges
- `security_opt: no-new-privileges:true` を追加
- setuid バイナリによる権限昇格を禁止

### ✅ H-5: リソース制限
- CPU 上限: 4 コア
- メモリ上限: 6GB
- プロセス数上限: 512（fork bomb 対策）
- ファイル記述子上限: soft 1024 / hard 4096

---

## 未対処リスクの詳細

### ❌ C-2: プロンプトインジェクション（構造的問題）

Claude Code が `/workspace` 内のファイルを読む際、悪意ある指示が含まれていると
それに従う可能性がある。AI エージェントの根本的な制約。

**運用での対処:**
- `/workspace` に信頼できないファイルを置かない
- `git clone` した外部リポジトリを Claude Code に読ませる際は注意
- `docker-compose.isolated.yml` でネットワーク遮断した状態でのみ外部コードを扱う

### ✅ C-3: Egress フィルタリングプロキシ（Squid sidecar）

**実装内容:**
- `egress-proxy` sidecar コンテナ（ubuntu/squid）を docker-compose に追加
- `claude-code` を `internal: true` ネットワークに移動（インターネット直接アクセス不可）
- `egress-proxy` のみが `claude-network`（インターネット出口）に接続
- `HTTP_PROXY` / `HTTPS_PROXY` 環境変数で全ツールのトラフィックを proxy 経由に

**allowlist（`egress-proxy/squid.conf`）:**
- `api.anthropic.com` — Claude Code API
- `github.com`, `.github.com`, `.githubusercontent.com` — git / gh CLI
- `registry.npmjs.org`, `.npmjs.com` — npm
- `pypi.org`, `files.pythonhosted.org` — pip
- `crates.io`, `.crates.io` — cargo
- それ以外はすべてブロック（HTTP 403）

**ドメイン追加方法:** `egress-proxy/squid.conf` の `allowed_domains` に追記し `docker compose restart egress-proxy`（再ビルド不要）

### ❌ H-1: npm/pip/cargo install スクリプト

**検討中の対策:**
- npm: `--ignore-scripts` フラグをデフォルト設定（`.npmrc` に `ignore-scripts=true`）
- pip: `--no-deps` + ハッシュ検証（`pip install --require-hashes`）
- cargo: `--no-build-script` は cargo 標準では未サポート（制限困難）

### ❌ H-2: git hooks による任意コード実行

**検討中の対策:**
- `git config --global core.hooksPath /dev/null` でフックを無効化
- `safe.directory` の設定

### ❌ H-3: シンボリックリンクによるホスト fs アクセス

**検討中の対策:**
- `/workspace` を `readonly` マウントにする（ただし開発用途と相反）
- bind mount のシンボリックリンク追跡を制限する設定は Docker 標準では未サポート

### ❌ H-4: ポートフォワード × WSL2 のネットワーク公開

**検討中の対策:**
- `ports` を `127.0.0.1:<port>:<port>` に変更してループバックのみにバインド
- Windows Firewall でポートをブロック

### ❌ M-1: パッケージバージョン未固定

**検討中の対策:**
- `requirements.txt` にバージョン固定 + ハッシュ検証
- `package.json` に固定バージョン
- ただしメンテナンスコストが増大するトレードオフあり

### ❌ M-2: Flutter 無効でも libgtk-3-dev 等が残存

**検討中の対策:**
- `INSTALL_FLUTTER` ARG に連動して `libgtk-3-dev`, `clang`, `cmake`, `ninja-build` 等の
  インストールも条件分岐させる

### ❌ M-3: ボリュームの汚染持続

**検討中の対策:**
- `npm-global`, `cargo-registry` ボリュームをセッション限りにする（named volume → tmpfs）
- ただしビルド高速化のキャッシュ効果が失われるトレードオフあり

### ❌ M-4: VS Code 拡張機能のバージョン未固定

**検討中の対策:**
- `devcontainer.json` の extensions にバージョンを指定（`publisher.extension@x.y.z`）
- ただし VS Code Dev Containers の仕様上サポートが限定的

### ❌ M-5: curl | bash ビルドパターン

**検討中の対策:**
- nodesource: 公式 deb パッケージを直接ダウンロードして SHA256 検証
- rustup: バージョン固定 URL + チェックサム検証
- GitHub CLI: 現状 GPG 署名検証あり（比較的安全）

### ❌ L-1: Linux Capabilities 未削減

**検討中の対策:**
```yaml
cap_drop:
  - ALL
cap_add:
  - CHOWN
  - SETUID
  - SETGID
  - DAC_OVERRIDE
```

### ❌ L-2: seccomp カスタムプロファイル

**検討中の対策:**
- 開発用途に必要なシステムコールのみ許可するカスタムプロファイル JSON を作成
- メンテナンスコストが高いため優先度は低

### ❌ L-3: 偵察ツールのプリインストール

対象パッケージ: `net-tools`, `iputils-ping`, `dnsutils`

**検討中の対策:**
- Dockerfile から削除（開発には不要）
