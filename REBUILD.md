# コンテナ再ビルド手順

Dockerfile や docker-compose.yml を変更した後の反映手順です。

> **構成**: `claude-code-container`（メイン）+ `claude-code-egress-proxy`（Squid プロキシ）の 2 コンテナ構成

---

## 前提確認

```powershell
# Docker Desktop の割当メモリが 6GB 以上あることを確認
# WSL2 バックエンドの場合: 物理メモリ 12GB 以上なら通常デフォルトで OK
# Settings → Resources には表示されない（.wslconfig で管理）
```

---

## 通常の再ビルド（設定変更後）

```powershell
cd <claude-code-containerのフォルダ>

# ビルド & 起動
docker compose build --no-cache
docker compose up -d
```

---

## クリーン再ビルド（ボリューム含めて全削除）

初回または問題が起きた場合に実施:

```powershell
cd <claude-code-containerのフォルダ>

# コンテナ + ボリューム + ネットワークを全削除
docker compose down -v

# ビルド（ubuntu/squid イメージの pull も含む）
docker compose build --no-cache

# 起動
docker compose up -d
```

> **注意**: `down -v` を実行すると Claude Code 認証（`claude-config` ボリューム）も削除されます。
> 起動後に `claude` の再認証が必要です。

---

## 起動確認

### 2 コンテナが起動しているか確認（PowerShell）

```powershell
docker compose ps
# NAME                       STATUS
# claude-code-container      Up
# claude-code-egress-proxy   Up
```

### コンテナ内の動作確認

```powershell
docker exec -it claude-code-container bash
```

```bash
# 実行ユーザーが developer であることを確認
whoami          # → developer

# バージョン確認
node --version  # → v22.x.x
python3 --version  # → 3.12.x
rustc --version
claude --version
gh --version

# セキュリティ設定確認
git config --global core.hooksPath  # → /home/developer/.githooks-empty
cat ~/.npmrc                        # → ignore-scripts=true

# Egress proxy 動作確認（allowlist 内: 疎通 OK）
curl -sv https://api.anthropic.com 2>&1 | grep -E "Connected|200|403"

# Egress proxy 動作確認（allowlist 外: ブロックされること）
curl -sv https://example.com 2>&1 | grep -E "403|Access Denied|ERR"
```

---

## 再認証

```bash
# Claude Code 認証
claude

# GitHub CLI 認証（必要な場合）
gh auth login
```

---

## トラブルシューティング

```powershell
# egress-proxy のログ確認
docker compose logs egress-proxy

# claude-code のログ確認
docker compose logs claude-code

# 全コンテナのログをリアルタイム確認
docker compose logs -f
```

**よくある問題:**

| 症状 | 原因 | 対処 |
|------|------|------|
| `egress-proxy` が起動しない | `ubuntu/squid` イメージが pull できていない | ネットワーク確認後 `docker compose up -d` |
| VS Code から接続できない | コンテナが起動していない | `docker compose ps` で確認 |
| `curl` が全部ブロックされる | egress-proxy が起動していない | `docker compose logs egress-proxy` |
| メモリ不足エラー | Docker 割当メモリ不足 | `.wslconfig` で `memory=8GB` 以上に設定 |

---

## Egress Proxy の allowlist にドメインを追加する

### 方法A: 動的 allowlist（再起動のみ・推奨）

`egress-proxy/allowlist.txt` に追記:

```
.example.com
.another-site.net
```

変更を反映（再ビルド不要）:

```powershell
docker compose restart egress-proxy
```

### 方法B: 固定 allowlist（常時許可するシステムドメイン）

`egress-proxy/squid.conf` の `fixed_domains` ACL に追記後:

```powershell
docker compose restart egress-proxy
```

---

## Flutter ありでビルドする

デフォルトは `INSTALL_FLUTTER: "false"`（Flutter/Chromium なし）です。
Flutter が必要な場合は `docker-compose.yml` の `build.args` を変更してください:

```yaml
args:
  INSTALL_FLUTTER: "true"   # ← false から true に変更
```

変更後にキャッシュなし再ビルド:

```powershell
docker compose build --no-cache && docker compose up -d
```

Flutter なし（デフォルト）のメリット:
- ビルド時間: 約 5 分（Flutter あり: 約 20 分）
- イメージサイズ: 大幅削減
- Chromium/Flutter 関連 CVE の影響を受けない

---

## ネットワーク完全隔離モード

Claude Code のアウトバウンドを egress-proxy ごと遮断する場合:

```powershell
docker compose -f docker-compose.yml -f docker-compose.isolated.yml up -d
```

> **注意**: このモードでは `git pull`, `npm install`, `pip install` 等も不可になります。
> 既存コードのレビュー・実行専用として使用してください。

---

## 注意事項

- `./workspace` はホスト側とマウントされているため、再ビルドで中身は消えません
- `claude-config` ボリュームにより `~/.claude` は永続化済みです（Claude Code の認証・設定）
- 再ビルド中は VS Code のターミナルが切断されます
- `npm-global` / `cargo-registry` ボリュームも永続化済みのため、グローバルパッケージは再インストール不要
