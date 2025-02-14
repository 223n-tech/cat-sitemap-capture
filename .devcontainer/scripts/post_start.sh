#!/usr/bin/env bash
set -euxo pipefail

# メイン処理
main() {
    # フォルダの管理者がrootになってしまう問題に対応
    sudo chown $(whoami):$(whoami) -R .
}

# ログフォルダの生成
mkdir -p /workspace/log

# スクリプトの実行
main "$@" 2>&1 | tee -a "/workspace/log/$(date +'%Y-%m-%d-%H-%M-%S')_devcontainer-start.log"
