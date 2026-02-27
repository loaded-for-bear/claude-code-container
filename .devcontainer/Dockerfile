FROM ubuntu:24.04

# 環境変数
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Tokyo \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# ツールの固定パス（システム領域 / 全ユーザー共有）
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    FLUTTER_HOME=/opt/flutter \
    CHROME_EXECUTABLE=/usr/bin/chromium

# タイムゾーン設定
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 基本パッケージのインストール
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    vim \
    nano \
    build-essential \
    gcc \
    g++ \
    make \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    zip \
    unzip \
    xz-utils \
    file \
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*
# L-3: net-tools / iputils-ping / dnsutils は攻撃偵察に悪用されるため除外
# M-2: libgtk-3-dev は Flutter 専用 → INSTALL_FLUTTER=true 時のみインストール

# Python環境のインストール
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    python-is-python3 \
    && rm -rf /var/lib/apt/lists/*

# venvを作成（Ubuntu 24.04はPEP 668でシステムPythonへの直接インストールを制限しているためvenvを使用）
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# pipを最新版にアップグレード + Pythonパッケージのインストール
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

RUN pip install --no-cache-dir \
    anthropic \
    requests \
    python-dotenv \
    pyyaml

RUN pip install --no-cache-dir \
    flask \
    fastapi \
    uvicorn

RUN pip install --no-cache-dir \
    pytest \
    pytest-cov

RUN pip install --no-cache-dir \
    black \
    flake8 \
    ruff \
    pylint \
    mypy

RUN pip install --no-cache-dir \
    numpy \
    pandas \
    matplotlib

# Node.js (LTS版) のインストール
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# npmを最新版に更新
RUN npm install -g npm@latest

# Rust環境のインストール（システム領域）
ENV PATH="/usr/local/cargo/bin:$PATH"

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    --default-toolchain stable --profile default

# ── セキュリティ 3-A: Flutter/Chromium をオプション化（攻撃面の縮小） ─────────
ARG INSTALL_FLUTTER=false

# Flutter環境のインストール（リトライ機能付き）
RUN if [ "$INSTALL_FLUTTER" = "true" ]; then \
    for i in 1 2 3; do \
        git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_HOME" && break || sleep 15; \
    done && \
    "$FLUTTER_HOME/bin/flutter" config --no-analytics && \
    "$FLUTTER_HOME/bin/flutter" precache --web && \
    "$FLUTTER_HOME/bin/flutter" config --enable-web && \
    "$FLUTTER_HOME/bin/flutter" config --no-enable-android && \
    "$FLUTTER_HOME/bin/flutter" config --no-enable-ios; \
    fi

# Chrome/Chromium + libgtk-3-dev（Flutter Web の実行に必要）
RUN if [ "$INSTALL_FLUTTER" = "true" ]; then \
    apt-get update && apt-get install -y chromium libgtk-3-dev && rm -rf /var/lib/apt/lists/*; \
    fi

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*


# ── セキュリティ 1-A: 非rootユーザー作成 ────────────────────────────────────
ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=1000

# Ubuntu 24.04 には GID/UID 1000 の ubuntu グループ・ユーザーがデフォルトで存在する
# → 既存グループ・ユーザーをリネームして再利用する（groupadd/useradd は使わない）
# sudo は一切付与しない（apt-get フックによる root 昇格バイパスを根本排除）
RUN groupmod --new-name $USERNAME $(getent group $USER_GID | cut -d: -f1) && \
    usermod --login $USERNAME --home /home/$USERNAME --move-home \
        $(getent passwd $USER_UID | cut -d: -f1) && \
    usermod --gid $USER_GID $USERNAME

# ── セキュリティ 1-A + 1-B: ツールディレクトリの所有権を developer に移譲 ──
# 1-B: cargo の world-writable（chmod -R a+w）を解除し developer に chown
# VSCode Server 用ディレクトリを root 権限のうちに作成・chown
# （Named Volume マウント前に作成しておくことで Permission denied を防ぐ）
RUN chown -R $USERNAME:$USERNAME /opt/venv \
    && chown -R $USERNAME:$USERNAME $RUSTUP_HOME $CARGO_HOME \
    && chmod -R 755 $RUSTUP_HOME $CARGO_HOME \
    && if [ -d "$FLUTTER_HOME" ]; then chown -R $USERNAME:$USERNAME "$FLUTTER_HOME"; fi \
    && mkdir -p /home/$USERNAME/.vscode-server/bin \
    && mkdir -p /home/$USERNAME/.vscode-server/extensions \
    && chown -R $USERNAME:$USERNAME /home/$USERNAME/.vscode-server

# ── ここから developer として実行 ─────────────────────────────────────────────
USER $USERNAME

# developer 専用の環境変数（home 配下）
ENV NPM_CONFIG_PREFIX=/home/developer/.npm-global \
    PUB_CACHE=/home/developer/.pub-cache

# PATH設定
ENV PATH="/home/developer/.npm-global/bin:/home/developer/.local/bin:$PATH"
ENV PATH="$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$PATH"

# Rustの追加ツール（developer として実行 → CARGO_HOME 書き込み権限あり）
RUN cargo install cargo-edit cargo-watch

# npmグローバルパッケージ（developer として実行 → NPM_CONFIG_PREFIX 配下）
RUN mkdir -p $NPM_CONFIG_PREFIX && \
    npm install -g \
    typescript \
    ts-node \
    nodemon \
    yarn \
    pnpm

# Claude Codeのインストール（developer として実行）
RUN npm install -g @anthropic-ai/claude-code

# 必要なディレクトリの作成
RUN mkdir -p /home/developer/.cache/pip \
    && mkdir -p $PUB_CACHE \
    && mkdir -p /home/developer/.githooks-empty \
    && mkdir -p /home/developer/.claude/debug
# H-2: 空の hooks ディレクトリを作成 → git config で参照してすべての git hooks を無効化

# H-1: npm install スクリプト（postinstall 等）をデフォルト無効化
RUN echo "ignore-scripts=true" >> ~/.npmrc

# Gitのデフォルト設定
RUN git config --global init.defaultBranch main && \
    git config --global core.editor vim && \
    git config --global user.name "Developer" && \
    git config --global user.email "dev@example.com" && \
    git config --global core.hooksPath /home/developer/.githooks-empty
# H-2: core.hooksPath を空ディレクトリに向けることで全 git hooks を無効化

# .bashrc に設定を追加
RUN echo '' >> ~/.bashrc && \
    echo '# PATH settings' >> ~/.bashrc && \
    echo 'export PATH="/opt/venv/bin:$PATH"' >> ~/.bashrc && \
    echo 'export PATH="/home/developer/.local/bin:$PATH"' >> ~/.bashrc && \
    echo 'export FLUTTER_HOME=/opt/flutter' >> ~/.bashrc && \
    echo 'export PATH="$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$PATH"' >> ~/.bashrc && \
    echo 'export NPM_CONFIG_PREFIX=/home/developer/.npm-global' >> ~/.bashrc && \
    echo 'export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"' >> ~/.bashrc && \
    echo 'export PATH="/usr/local/cargo/bin:$PATH"' >> ~/.bashrc && \
    echo '' >> ~/.bashrc && \
    echo '# Python aliases' >> ~/.bashrc && \
    echo 'alias python=python3' >> ~/.bashrc && \
    echo 'alias pip=pip3' >> ~/.bashrc

# 作業ディレクトリ
WORKDIR /workspace

# デフォルトシェル
CMD ["/bin/bash"]

