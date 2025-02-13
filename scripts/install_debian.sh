#!/bin/bash

# エラーが発生した時点でスクリプトを終了
set -e

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# root権限チェック
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}このスクリプトはroot権限で実行する必要があります。${NC}"
    echo -e "以下のコマンドで実行してください：${YELLOW}sudo $0${NC}"
    exit 1
fi

# インストール状態をチェックする関数
check_installed() {
    dpkg -l "$1" &> /dev/null
}

# Goのバージョンチェック
check_go_version() {
    if command -v go &> /dev/null; then
        local current_version=$(go version | awk '{print $3}' | sed 's/go//')
        local required_version="1.21.6"
        if [ "$(printf '%s\n' "$required_version" "$current_version" | sort -V | head -n1)" = "$required_version" ]; then
            return 0
        fi
    fi
    return 1
}

echo -e "${GREEN}Debian環境のセットアップを開始します...${NC}"

# システムの更新
echo -e "${BLUE}システムの更新状態を確認しています...${NC}"
apt-get update

# 基本的な依存パッケージのインストール
echo -e "${BLUE}基本パッケージの確認とインストール...${NC}"
base_packages=(wget curl git build-essential ca-certificates apt-transport-https software-properties-common gnupg2)
for package in "${base_packages[@]}"; do
    if ! check_installed "$package"; then
        echo -e "${GREEN}$packageをインストールしています...${NC}"
        apt-get install -y "$package"
    else
        echo -e "${YELLOW}$packageは既にインストールされています。スキップします。${NC}"
    fi
done

# Go言語のインストール
echo -e "${BLUE}Go言語の確認とインストール...${NC}"
if ! check_go_version; then
    echo -e "${GREEN}Go言語をインストールしています...${NC}"
    GO_VERSION="1.21.6"
    wget "https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz"
    tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
    rm "go${GO_VERSION}.linux-amd64.tar.gz"
    
    # PATHの設定
    if [ ! -f /etc/profile.d/go.sh ]; then
        echo 'export PATH=$PATH:/usr/local/go/bin' > /etc/profile.d/go.sh
    fi
    source /etc/profile.d/go.sh
else
    echo -e "${YELLOW}Go言語は既にインストールされています。スキップします。${NC}"
fi

# Google Chromeのインストール
echo -e "${BLUE}Google Chromeの確認とインストール...${NC}"
if ! check_installed google-chrome-stable; then
    echo -e "${GREEN}Google Chromeをインストールしています...${NC}"
    
    # Chromeのリポジトリキーをダウンロードして/usr/share/keyringsに保存
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
    
    # リポジトリの追加（新しい形式）
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | tee /etc/apt/sources.list.d/google-chrome.list
    
    # パッケージリストの更新とChromeのインストール
    apt-get update
    apt-get install -y google-chrome-stable
else
    echo -e "${YELLOW}Google Chromeは既にインストールされています。スキップします。${NC}"
fi

# 日本語フォントのインストール
echo -e "${BLUE}日本語フォントの確認とインストール...${NC}"
font_packages=(
    fonts-noto-cjk
    fonts-noto-cjk-extra
    fonts-ipafont
    fonts-ipafont-gothic
    fonts-ipafont-mincho
    fonts-ipaexfont
    fonts-ipaexfont-gothic
    fonts-ipaexfont-mincho
    fonts-vlgothic
)

font_updates_needed=false
for package in "${font_packages[@]}"; do
    if ! check_installed "$package"; then
        echo -e "${GREEN}$packageをインストールしています...${NC}"
        apt-get install -y "$package"
        font_updates_needed=true
    else
        echo -e "${YELLOW}$packageは既にインストールされています。スキップします。${NC}"
    fi
done

# 日本語環境のセットアップ
echo -e "${BLUE}日本語環境の確認とセットアップ...${NC}"
locale_packages=(language-pack-ja language-pack-ja-base)
locale_update_needed=false
for package in "${locale_packages[@]}"; do
    if ! check_installed "$package"; then
        echo -e "${GREEN}$packageをインストールしています...${NC}"
        apt-get install -y "$package"
        locale_update_needed=true
    else
        echo -e "${YELLOW}$packageは既にインストールされています。スキップします。${NC}"
    fi
done

# ロケールの生成（必要な場合のみ）
if [ "$locale_update_needed" = true ]; then
    echo -e "${GREEN}日本語ロケールを生成しています...${NC}"
    locale-gen ja_JP.UTF-8
fi

# フォントキャッシュの更新（必要な場合のみ）
if [ "$font_updates_needed" = true ]; then
    echo -e "${GREEN}フォントキャッシュを更新しています...${NC}"
    fc-cache -f -v
fi

# スクリーンショットプログラム用のディレクトリを作成
echo -e "${BLUE}作業ディレクトリの確認と作成...${NC}"
WORK_DIR="/opt/screenshot-generator"
if [ ! -d "$WORK_DIR" ]; then
    echo -e "${GREEN}作業ディレクトリを作成しています...${NC}"
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    # Go モジュールの初期化（ディレクトリが新規の場合のみ）
    if [ ! -f "go.mod" ]; then
        echo -e "${GREEN}Goの依存パッケージをインストールしています...${NC}"
        go mod init screenshot-generator
        go get github.com/chromedp/chromedp
        go get github.com/schollz/progressbar/v3
    fi
else
    echo -e "${YELLOW}作業ディレクトリは既に存在します。スキップします。${NC}"
fi

# インストール情報の表示
echo -e "\n${GREEN}インストールされたコンポーネントの情報:${NC}"
if command -v go &> /dev/null; then
    echo -e "${BLUE}Go version:${NC} $(go version)"
fi
if command -v google-chrome &> /dev/null; then
    echo -e "${BLUE}Chrome version:${NC} $(google-chrome --version)"
fi
echo -e "${BLUE}インストールされた日本語フォント数:${NC} $(fc-list :lang=ja | wc -l)"

echo -e "\n${GREEN}セットアップが完了しました。${NC}"

# 再起動の必要性をチェック
if [ "$locale_update_needed" = true ] || [ "$font_updates_needed" = true ]; then
    echo -e "${YELLOW}システムの再起動をお勧めします。${NC}"
    read -p "システムを今すぐ再起動しますか？ (y/N): " reboot_choice
    if [[ $reboot_choice =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}システムを再起動します...${NC}"
        reboot
    fi
else
    echo -e "${GREEN}再起動は必要ありません。${NC}"
fi
