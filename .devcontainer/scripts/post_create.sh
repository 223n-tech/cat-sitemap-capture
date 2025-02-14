#!/usr/bin/env bash

# エラー発生時にスクリプトを終了
set -e

# ログ出力関数
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# メイン処理
main() {
    log "Starting environment setup..."

    # フォルダの所有権を設定
    log "Setting workspace ownership..."
    cd /workspace
    sudo chown $(whoami):$(whoami) -R .
    log "Workspace ownership set to vscode user"

    # 非対話モードの設定
    export DEBIAN_FRONTEND=noninteractive

    # Ansibleのインストール
    if ! command -v ansible &> /dev/null; then
        log "Installing Ansible..."
        sudo apt-get update -qq
        sudo apt-get install -y ansible
    else
        log "Ansible is already installed, skipping..."
    fi

    # Ansible Playbookの実行
    log "Running Ansible playbook..."
    cd /workspace/.devcontainer/ansible
    ansible-playbook playbook.yml -i 'localhost,' -c local

    log "Setup completed successfully"
}

# ログフォルダの生成
mkdir -p /workspace/log

# スクリプトの実行
main "$@" 2>&1 | tee -a "/workspace/log/$(date +'%Y-%m-%d-%H-%M-%S')_devcontainer-setup.log"

echo $?