#!/bin/bash
# entrypoint.sh
# コンテナ起動時に root として実行し、/workspace の所有権を developer(1000) に修正してから
# 権限を落として CMD を実行する。

set -e

DEVELOPER_UID=1000
DEVELOPER_GID=1000

# /workspace 内に root 所有ファイルが残っていれば chown
if find /workspace -not -user "$DEVELOPER_UID" -print -quit 2>/dev/null | grep -q .; then
    echo "[entrypoint] /workspace の所有権を developer(${DEVELOPER_UID}:${DEVELOPER_GID}) に修正中..."
    chown -R "${DEVELOPER_UID}:${DEVELOPER_GID}" /workspace
    echo "[entrypoint] 完了"
fi

# developer に権限を落として CMD を実行（capabilities は全て破棄される）
exec setpriv \
    --reuid="$DEVELOPER_UID" \
    --regid="$DEVELOPER_GID" \
    --clear-groups \
    "$@"
