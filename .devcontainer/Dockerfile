FROM ubuntu:24.04

# 環境変数
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Tokyo
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# タイムゾーン設定
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 基本パッケージのインストール
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    vim \
    nano \
    sudo \
    build-essential \
    gcc \
    g++ \
    make \
    net-tools \
    iputils-ping \
    dnsutils \
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
    libgtk-3-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Python環境のインストール
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    python-is-python3 \
    && rm -rf /var/lib/apt/lists/*

# pipを最新版にアップグレード
# Ubuntu 24.04 は PEP 668 により --break-system-packages が必要
RUN python3 -m pip install --no-cache-dir --break-system-packages --upgrade pip setuptools wheel

# Pythonパッケージを分割してインストール
RUN python3 -m pip install --no-cache-dir --break-system-packages \
    anthropic \
    requests \
    python-dotenv \
    pyyaml

RUN python3 -m pip install --no-cache-dir --break-system-packages \
    flask \
    fastapi \
    uvicorn

RUN python3 -m pip install --no-cache-dir --break-system-packages \
    pytest \
    pytest-cov

RUN python3 -m pip install --no-cache-dir --break-system-packages \
    black \
    flake8 \
    ruff \
    pylint \
    mypy

RUN python3 -m pip install --no-cache-dir --break-system-packages \
    numpy \
    pandas \
    matplotlib

# Node.js (LTS版) のインストール
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# npmを最新版に更新
RUN npm install -g npm@latest

# npmグローバルディレクトリの設定
ENV NPM_CONFIG_PREFIX=/root/.npm-global
RUN mkdir -p $NPM_CONFIG_PREFIX

# グローバルnpmパッケージのインストール
RUN npm install -g \
    typescript \
    ts-node \
    nodemon \
    yarn \
    pnpm

# Rust環境のインストール
ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
ENV PATH=/usr/local/cargo/bin:$PATH

# Rustupをインストール
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile default && \
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME

# Rustの追加ツール
RUN cargo install cargo-edit cargo-watch

# Flutter環境のインストール
ENV FLUTTER_HOME=/opt/flutter
ENV PUB_CACHE=/root/.pub-cache

# Flutterのダウンロードとインストール（リトライ機能付き）
RUN for i in 1 2 3; do \
        git clone https://github.com/flutter/flutter.git -b stable --depth 1 $FLUTTER_HOME && break || sleep 15; \
    done && \
    $FLUTTER_HOME/bin/flutter config --no-analytics && \
    $FLUTTER_HOME/bin/flutter precache --web && \
    $FLUTTER_HOME/bin/flutter config --enable-web && \
    $FLUTTER_HOME/bin/flutter config --no-enable-android && \
    $FLUTTER_HOME/bin/flutter config --no-enable-ios

# Chrome/Chromium
# Ubuntu 24.04 ではパッケージ名が chromium-browser → chromium に変更
RUN apt-get update && apt-get install -y \
    chromium \
    && rm -rf /var/lib/apt/lists/*
ENV CHROME_EXECUTABLE=/usr/bin/chromium

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

# Gitのデフォルト設定（name/email はプレースホルダー。各プロジェクトで git config --local で上書きすること）
RUN git config --global init.defaultBranch main && \
    git config --global core.editor vim && \
    git config --global user.name "Developer" && \
    git config --global user.email "dev@example.com"

# Claude Codeのインストール（npm 経由。旧 install.sh は廃止予定のため移行）
RUN npm install -g @anthropic-ai/claude-code

# 必要なディレクトリの作成
RUN mkdir -p /root/.cache/pip && \
    mkdir -p /root/.pub-cache

# PATH設定
ENV PATH="/root/.local/bin:$PATH"
ENV PATH="$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$PATH"
ENV PATH="$NPM_CONFIG_PREFIX/bin:$PATH"
ENV PATH="/usr/local/cargo/bin:$PATH"

# .bashrc に設定を追加
RUN echo '' >> ~/.bashrc && \
    echo '# PATH settings' >> ~/.bashrc && \
    echo 'export PATH="/root/.local/bin:$PATH"' >> ~/.bashrc && \
    echo 'export FLUTTER_HOME=/opt/flutter' >> ~/.bashrc && \
    echo 'export PATH="$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$PATH"' >> ~/.bashrc && \
    echo 'export NPM_CONFIG_PREFIX=/root/.npm-global' >> ~/.bashrc && \
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
