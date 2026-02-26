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
docker-compose up -d --build
```

キャッシュが効かない場合:

```powershell
docker-compose build --no-cache && docker-compose up -d
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
| GitHub 認証 | `gh auth login` | `gh-config:/root/.config/gh` をボリュームに追加 |
| Git ローカル設定 | `git config user.name "..."` | `/workspace` 内のリポジトリは維持される |
| pip で追加したパッケージ | `pip install ...` | `pip-cache` ボリュームでキャッシュ済み（再インストールは高速） |
| npm で追加したグローバルパッケージ | `npm install -g ...` | `npm-global` ボリュームで永続化済み |

### ボリューム追加の例（docker-compose.yml）

```yaml
services:
  claude-code:
    volumes:
      - gh-config:/root/.config/gh       # GitHub CLI 認証の永続化

volumes:
  gh-config:
```

## 注意事項

- `./workspace` はホスト側とマウントされているため、再ビルドで中身は消えません
- `claude-config` ボリュームにより `~/.claude` は永続化済みです（Claude Code の認証・設定）
- 再ビルド中は VS Code のターミナルが切断されます
