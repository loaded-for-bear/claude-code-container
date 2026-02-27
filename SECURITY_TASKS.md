# セキュリティリスク対応タスク

claude-code-container のセキュリティリスク洗い出しと対応状況。

最終更新: 2026-02-27（L-1/L-4 解決・cap_drop 最小化、C-3/squid.conf 更新）

---

## 対応状況まとめ

| 優先度 | ID | リスク | 対応状況 |
|--------|-----|--------|---------|
| 🔴 Critical | C-1 | `sudo apt-get` フック経由の root 昇格バイパス | ✅ 完了 |
| 🔴 Critical | C-2 | プロンプトインジェクション（AIエージェント固有） | ⚠️ 構造的問題・運用でカバー |
| 🔴 Critical | C-3 | アウトバウンド通信無制限（認証情報の外部送信） | ✅ 完了 |
| 🟠 High | H-1 | npm/pip/cargo install スクリプトによる任意コード実行 | ✅ 完了（npm のみ） |
| 🟠 High | H-2 | git hooks による任意コード実行 | ✅ 完了 |
| 🟠 High | H-3 | シンボリックリンクによるホスト fs アクセス | 🚫 構造的限界 |
| 🟠 High | H-4 | ポートフォワード × WSL2 のネットワーク公開 | ✅ 完了 |
| 🟠 High | H-5 | リソース制限なし（DoS） | ✅ 完了 |
| 🟡 Medium | M-1 | パッケージバージョン未固定（サプライチェーン） | 🔁 メンテ必要・手動対応 |
| 🟡 Medium | M-2 | Flutter 無効でも libgtk-3-dev 等が残存 | ✅ 完了 |
| 🟡 Medium | M-3 | npm-global/cargo-registry ボリュームの汚染持続 | 🚫 UX トレードオフ |
| 🟡 Medium | M-4 | VS Code 拡張機能のバージョン未固定 | 🚫 形式未サポート |
| 🟡 Medium | M-5 | `curl \| bash` ビルド（再現性・サプライチェーン） | 🔁 HTTPS で低リスク・保留 |
| 🔵 Low | L-1 | Linux Capabilities 未削減 | ✅ 完了（SYS_PTRACE のみ） |
| 🔵 Low | L-2 | seccomp カスタムプロファイルなし | 🚫 メンテコスト過大 |
| 🔵 Low | L-3 | 偵察ツールのプリインストール（net-tools 等） | ✅ 完了 |
| 🟡 Medium | L-4 | DAC_OVERRIDE / SETUID / SETGID 能力の再付与 | ✅ 解決済み（2026-02-27 削除） |

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

## 未対処・要注意リスクの詳細

### ❌ C-2: プロンプトインジェクション（構造的問題）

Claude Code が `/workspace` 内のファイルを読む際、悪意ある指示が含まれていると
それに従う可能性がある。AI エージェントの根本的な制約。

**運用での対処:**
- `/workspace` に信頼できないファイルを置かない
- `git clone` した外部リポジトリを Claude Code に読ませる際は注意
- `docker-compose.isolated.yml` でネットワーク遮断した状態でのみ外部コードを扱う

---

### ✅ C-3: Egress フィルタリングプロキシ（Squid sidecar）— 2026-02-27 更新

**実装内容:**
- `egress-proxy` sidecar コンテナ（ubuntu/squid）を docker-compose に追加
- `claude-code` を `internal: true` ネットワークに移動（インターネット直接アクセス不可）
- `egress-proxy` のみが `claude-network`（インターネット出口）に接続
- `HTTP_PROXY` / `HTTPS_PROXY` 環境変数で全ツールのトラフィックを proxy 経由に
- `user: proxy` を明示指定（Squid が最小権限で動作）

**fixed_domains allowlist（`egress-proxy/squid.conf`）:**
- `*.anthropic.com`, `*.claude.ai`, `*.claude.com` — Claude Code API / 認証
- `*.github.com`, `*.githubusercontent.com`, `*.githubcopilot.com`, `*.exp-tas.com` — git / gh CLI
- `registry.npmjs.org`, `*.npmjs.com` — npm
- `pypi.org`, `files.pythonhosted.org` — pip
- `*.crates.io`, `*.rust-lang.org` — cargo
- `*.vo.msecnd.net`, `*.vsassets.io`, `*.gallery.vsassets.io` — VS Code Marketplace

**scraping_sites allowlist（`egress-proxy/allowlist.txt`）:**
- スクレイピング対象や一時的に追加したいドメインを記述
- fixed_domains と分離することで、ユーザーが管理しやすい設計
- 追記後は `docker compose restart egress-proxy` のみで反映（再ビルド不要）

**⚠️ 注意: allowlist.txt に広域ドメインを追加する際は慎重に**
- `.google.com` のような広域ドメインは多くのサービスへのアクセスを許可する
- 意図しないデータ送信先になる可能性がある

**ドメイン追加の判断基準:**
- 開発作業に直接必要なドメインのみ追加する
- `docker compose logs egress-proxy` でアクセスログを定期確認する

---

### ✅ H-1: npm install スクリプト無効化（npm のみ）

**実装内容:**
- `~/.npmrc` に `ignore-scripts=true` を追加（Dockerfile 末尾、ビルド時 npm install 完了後）
- 実行時の `npm install xxx` で postinstall 等が自動実行されなくなる

**pip / cargo の制限:**
- pip: `--only-binary :all:` は多くのパッケージを壊すため不採用。`pip install` 時は明示的に信頼できるパッケージのみ使用すること
- cargo: グローバルな build.rs 無効化は cargo 標準では未サポート。信頼できる crate のみ使用すること

---

### ✅ H-2: git hooks グローバル無効化

**実装内容:**
- `mkdir -p ~/.githooks-empty`（空のフック格納ディレクトリ）
- `git config --global core.hooksPath /home/developer/.githooks-empty`
- `git clone` した外部リポジトリの post-checkout / post-merge 等が自動実行されなくなる

**個別プロジェクトで有効化する場合:**
```bash
git config --local core.hooksPath .githooks
```

---

### 🚫 H-3: シンボリックリンクによるホスト fs アクセス

Docker の bind mount はシンボリックリンク追跡を制限する標準オプションがない。
`/workspace` を readonly にすると開発用途と相反する。**構造的限界として受容。**

---

### ✅ H-4: ポートバインドを 127.0.0.1 に限定

**実装内容:**
- `ports:` を `"127.0.0.1:<port>:<port>"` 形式に変更（全5ポート）
- LAN 上の他デバイスから直接アクセス不可（ホスト自身のみ）

---

### 🔁 M-1: パッケージバージョン未固定

**対応方針（手動）:**
- pip: 定期的に `pip list --outdated` で確認し、重要パッケージはバージョン固定を推奨
- npm: 定期的に `npm outdated -g` で確認
- cargo: `cargo update` で最新化の際に差分を確認
- 自動化するには `dependabot` 等の CI 連携が必要

---

### ✅ M-2: libgtk-3-dev を Flutter conditional に移動

**実装内容:**
- `libgtk-3-dev` を基本パッケージから削除
- `INSTALL_FLUTTER=true` 時の chromium インストールに統合
- デフォルトビルド（Flutter なし）ではインストールされない

---

### 🚫 M-3: ボリュームの汚染持続

`npm-global` / `cargo-registry` ボリュームを削除するとビルドキャッシュが失われ、毎回の起動が大幅に遅くなる。**UX とのトレードオフとして現状維持。**
疑わしい場合は `docker compose down -v` でボリュームごとクリーンアップすること。

---

### 🚫 M-4: VS Code 拡張機能のバージョン未固定

`devcontainer.json` の `extensions` フィールドはバージョン指定に対応していない（仕様の制約）。
VSIX ファイルでの固定は管理コストが過大。**形式未サポートとして保留。**

---

### 🔁 M-5: curl | bash ビルドパターン

Node.js / Rust の curl インストールは HTTPS + 配布元の証明書で保護されており、リスクは低い。
完全に排除するには deb パッケージ直接ダウンロード + SHA256 検証が必要だが、バージョン追従の手間が大きい。**優先度低として保留。**

---

### ✅ L-1: Linux Capabilities 削減

**現在の実装（docker-compose.yml）:**
```yaml
cap_drop:
  - ALL
cap_add:
  - SYS_PTRACE   # vscode-lldb デバッガー（プロセスアタッチ）に必要
```

**変更経緯:**
- 初期実装: `cap_drop: ALL` + `SYS_PTRACE` のみ
- 中間（互換性問題）: npm install / venv 操作のため `CHOWN`, `SETUID`, `SETGID`, `DAC_OVERRIDE` を一時追加
- 2026-02-27: 以下の Dockerfile 改善により全て削除
  - `groupmod`/`usermod` でのユーザーリネーム（Ubuntu 24.04 既存ユーザーを再利用）
  - `.vscode-server` ディレクトリを root 権限のうちに事前作成・chown
  - `user: "1000:1000"` で直接起動（root entrypoint 廃止）
- `no-new-privileges: true` により setuid バイナリ経由の昇格は引き続き禁止

---

### 🚫 L-2: seccomp カスタムプロファイル

開発用途に必要なシステムコールのセットは広く、カスタム seccomp の作成・維持は高コスト。
Docker デフォルト seccomp（300+ syscall を適切に制限）で十分と判断。**保留。**

---

### ✅ L-3: 偵察ツール削除

**削除したパッケージ:**
- `net-tools`（ifconfig, netstat）
- `iputils-ping`（ping）
- `dnsutils`（dig, nslookup）

開発には不要。コンテナ侵害時の偵察フェーズを困難にする。

---

### ✅ L-4: DAC_OVERRIDE / SETUID / SETGID 能力の再付与（2026-02-27 解決）

L-1 の中間状態で一時的に追加した capabilities。2026-02-27 の Dockerfile 改善（L-1 参照）により全て削除済み。

**解決方法:**
- `groupmod`/`usermod` によるユーザーリネーム → CHOWN/SETUID/SETGID 不要に
- `/opt/venv` を root 権限で作成後に `chown developer` → DAC_OVERRIDE 不要に
- `.vscode-server` ディレクトリ事前作成 → 起動後の権限問題を根本解消
