#!/bin/bash

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# # root権限チェック
# if [ "$EUID" -ne 0 ]; then
#     echo -e "${RED}このスクリプトはroot権限で実行する必要があります。${NC}"
#     echo -e "以下のコマンドで実行してください：${YELLOW}sudo $0${NC}"
#     exit 1
# fi

echo -e "${GREEN}インストールプロセスを開始します...${NC}"

# システムの更新
echo -e "${GREEN}システムを更新しています...${NC}"
sudo apt-get update
sudo apt-get upgrade -y

# 基本的な依存パッケージのインストール
echo -e "${GREEN}基本的な依存パッケージをインストールしています...${NC}"
sudo apt-get install -y \
    wget \
    curl \
    git \
    build-essential \
    ca-certificates \
    apt-transport-https \
    software-properties-common

# Goのインストール確認とインストール
echo -e "${GREEN}Golangをインストールします。${NC}"
if [ -z `which go` ]; then
    echo -e "${GREEN}Golangをインストールしています...${NC}"
    sudo add-apt-repository -y ppa:longsleep/golang-backports
    sudo apt-get update
    sudo apt-get install -y golang
else
    echo -e "${YELLOW}Golangは既にインストールされています。${NC}"
fi

# ブラウザのインストール
echo -e "${GREEN}ブラウザをインストールします。${NC}"
echo -e "${GREEN}Google Chromeをインストールします...${NC}"
if [ -z `which google-chrome` ]; then
    wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
    sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'
    sudo apt-get update
    sudo apt-get install -y google-chrome-stable
else
    echo -e "${YELLOW}Google Chromeは既にインストールされています。${NC}"
fi

# 日本語フォントのインストール
echo -e "${GREEN}日本語フォントをインストールしています...${NC}"
sudo apt-get install -y \
    fonts-noto-cjk \
    fonts-noto-cjk-extra \
    fonts-ipafont \
    fonts-ipafont-gothic \
    fonts-ipafont-mincho \
    fonts-ipaexfont \
    fonts-ipaexfont-gothic \
    fonts-ipaexfont-mincho \
    fonts-vlgothic

# ロケールの生成
echo -e "${GREEN}日本語ロケールを生成しています...${NC}"
sudo apt-get install -y locales
sudo locale-gen ja_JP.UTF-8
sudo localedef -f UTF-8 -i ja_JP ja_JP
echo "export LANG=ja_JP.UTF-8" >> ~/.bash_aliases
echo "export LANGUAGE=ja_JP:jp" >> ~/.bash_aliases
echo "export LC_ALL=ja_JP.UTF-8" >> ~/.bash_aliases

# フォントキャッシュの更新
echo -e "${GREEN}フォントキャッシュを更新しています...${NC}"
sudo fc-cache -f -v

# スクリーンショットプログラムの依存パッケージをインストール
echo -e "${GREEN}Go言語の依存パッケージをインストールしています...${NC}"
go mod init screenshot-generator
go get github.com/chromedp/chromedp
go get github.com/schollz/progressbar/v3

# バージョン情報の表示
echo -e "${GREEN}インストールされたコンポーネントのバージョン:${NC}"
echo -e "${YELLOW}Go version:${NC}"
go version
echo -e "${YELLOW}Chrome version:${NC}"
google-chrome --version

echo -e "\n${GREEN}インストールが完了しました。${NC}"
echo -e "${YELLOW}システムを再起動することをお勧めします。${NC}"
echo -e "${GREEN}再起動後、以下のコマンドでスクリーンショット生成プログラムを実行できます：${NC}"
echo -e "${YELLOW}cd ~/screenshot-work${NC}"
echo -e "${YELLOW}go run main.go -sitemap https://haru.223n.tech/sitemap.xml -verbose -wait 8${NC}"

# 再起動の確認
read -p "システムを今すぐ再起動しますか？ (y/N): " reboot_choice
if [[ $reboot_choice =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}システムを再起動します...${NC}"
    reboot
fi
