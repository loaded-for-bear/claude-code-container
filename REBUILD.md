# コンテナ再ビルド手順

Dockerfile や docker-compose.yml を変更した後の反映手順です。

## 再ビルド方法

### 方法A: VS Code から（推奨）

1. `F1` キーまたは `Ctrl+Shift+P`
2. `Dev Containers: Rebuild Container` を選択
3. ビルド完了まで待つ（変更箇所によって1〜10分）

### 方法B: コマンドライン（ホスト側 PowerShell）

```powershell
cd claude-code-container
docker compose up -d --build
```

キャッシュが効かない場合:

```powershell
docker compose build --no-cache && docker compose up -d
```

## 再ビルド後の確認

コンテナ内のターミナルで実行:

```bash
# 基本ツール
node --version
python --version
rustc --version
flutter --version

# Claude Code
claude --version

# GitHub CLI
gh --version
```

## 再ビルド後に再設定が必要なもの

以下の設定はボリュームに永続化されていないため、再ビルドごとに再設定が必要です。

| 設定 | コマンド | 永続化したい場合 |
|------|---------|-----------------|
| GitHub 認証 | `gh auth login` | `gh-config:/home/developer/.config/gh` をボリュームに追加 |
| Git ローカル設定 | `git config user.name "..."` | `/workspace` 内のリポジトリは維持される |
| pip で追加したパッケージ | `pip install ...` | `pip-cache` ボリュームでキャッシュ済み（再インストールは高速） |
| npm で追加したグローバルパッケージ | `npm install -g ...` | `npm-global` ボリュームで永続化済み |

### ボリューム追加の例（docker-compose.yml）

```yaml
services:
  claude-code:
    volumes:
      - gh-config:/home/developer/.config/gh   # GitHub CLI 認証の永続化

volumes:
  gh-config:
```

### 旧バージョン（root運用）からの移行

非rootユーザー（developer）への移行後は、古い root 向けボリュームが残っている場合があります。
クリーンに再ビルドするには **ボリュームも含めて削除**してください:

```powershell
docker compose down -v   # コンテナ + ボリューム削除
docker compose up -d --build
```

> **注意**: `down -v` を実行すると `claude-config`（Claude Code 認証）など永続化データも消えます。
> `gh auth login` / `claude login` の再実行が必要になります。

### Flutter ありでビルドする（3-A）

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
- 攻撃面: Chromium/Flutter 関連 CVE の影響を受けない

### ネットワーク隔離モードで起動する（2-B）

コンテナ自体のネットワークを遮断して Claude Code を実行する場合:

```powershell
# docker-compose.yml の networks: セクションを一時的にコメントアウトしてから:
docker compose -f docker-compose.yml -f docker-compose.isolated.yml up -d
```

> **注意**: このモードでは `git pull`, `npm install`, `pip install` 等も不可になります。
> 既存コードのレビュー・実行専用として使用してください。

## 注意事項

- `./workspace` はホスト側とマウントされているため、再ビルドで中身は消えません
- `claude-config` ボリュームにより `~/.claude` は永続化済みです（Claude Code の認証・設定）
- 再ビルド中は VS Code のターミナルが切断されます
