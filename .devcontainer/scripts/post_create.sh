#!/usr/bin/env bash
set -euxo pipefail

# フォルダの管理者がrootになってしまう問題に対応
sudo chown $(whoami):$(whoami) -R .
