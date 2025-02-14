#!/usr/bin/env bash

# エラー発生時にスクリプトを終了
set -e

# ログ出力関数
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# メイン処理
main() {
    # rootユーザーチェック
    if [ "$EUID" -ne 0 ]; then
        log "Error: This script must be run as root"
        exit 1
    fi

    log "Starting environment setup..."

    # フォルダの所有権を設定
    log "Setting workspace ownership..."
    cd /workspace
    chown vscode:vscode -R .
    log "Workspace ownership set to vscode user"

    # 非対話モードの設定
    export DEBIAN_FRONTEND=noninteractive

    # Ansibleのインストール
    if ! command -v ansible &> /dev/null; then
        log "Installing Ansible..."
        apt-get update -qq
        apt-get install -y ansible
    else
        log "Ansible is already installed, skipping..."
    fi

    # Ansible Playbookの実行
    log "Running Ansible playbook..."
    cd /workspace/.devcontainer/ansible
    ansible-playbook playbook.yml -i 'localhost,' -c local

    log "Setup completed successfully"
}

# スクリプトの実行
main "$@" 2>&1 | tee -a /var/log/devcontainer-setup.log

echo $?