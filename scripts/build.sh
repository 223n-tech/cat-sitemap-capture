#!/usr/bin/env bash

# エラー発生時にスクリプトを終了
set -e

# ビルド設定
APP_NAME="Cat-Sitemap-Capture"
BUILD_DIR="build"
VERSION=$(git describe --tags --always --dirty)
BUILD_TIME=$(date -u '+%Y-%m-%d_%H:%M:%S')

# ビルドする環境の定義
PLATFORMS=(
    "windows/amd64"
    "windows/386"
    "linux/amd64"
    "linux/386"
    "darwin/amd64"
    "darwin/arm64"
)

# ログ出力関数
function log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# ビルドディレクトリの準備
function prepare_build_dir() {
    log "Preparing build directory..."
    /usr/bin/mkdir -p "${BUILD_DIR}"
    /usr/bin/rm -rf "${BUILD_DIR:?}"/*
}

# 単一ターゲットのビルド
function build_for_platform() {
    local os=$1
    local arch=$2
    
    local binary_name="${APP_NAME}"
    if [ "${os}" = "windows" ]; then
        binary_name="${binary_name}.exe"
    fi

    local output_dir="${BUILD_DIR}/${os}_${arch}"
    local output_path="${output_dir}/${binary_name}"
    
    log "Building for ${os}/${arch}..."
    
    /usr/bin/mkdir -p "${output_dir}"
    
    GOOS=${os} GOARCH=${arch} go build \
        -o "${output_path}" \
        -ldflags "-X main.Version=${VERSION} -X main.BuildTime=${BUILD_TIME}" \
        main.go
        
    log "Built: ${output_path}"
}

# メイン処理
function main() {
    prepare_build_dir
    
    log "Starting multi-platform build..."
    log "Version: ${VERSION}"
    log "Build Time: ${BUILD_TIME}"
    
    for platform in "${PLATFORMS[@]}"; do
        os=${platform%/*}
        arch=${platform#*/}
        build_for_platform "${os}" "${arch}"
    done
    
    log "Build completed successfully"
}

# スクリプトの実行
main "$@"
