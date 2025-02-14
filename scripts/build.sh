#!/usr/bin/env bash

# エラー発生時にスクリプトを終了
set -e

# ビルド設定
APP_NAME="cat-sitemap-capture"
MODULE_NAME="github.com/223n-tech/cat-sitemap-capture"
BUILD_DIR="/workspace/build"
DIST_DIR="${BUILD_DIR}/dist"
SCRIPTS_DIR="${BUILD_DIR}/scripts"
VERSION=$(git describe --tags --always --dirty)
BUILD_TIME=$(date -u '+%Y-%m-%d_%H:%M:%S')
GIT_COMMIT=$(git rev-parse HEAD)
GO_VERSION=$(go version | cut -d " " -f 3)

# デフォルトのビルドマトリックス
DEFAULT_PLATFORMS=(
    "windows/amd64"
    "windows/386"
    "linux/amd64"
    "linux/386"
    "darwin/amd64"
    "darwin/arm64"
)

# カスタムビルドタグ（デフォルト）
BUILD_TAGS="release"

# ログ出力関数
function log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# ビルドマトリックスの読み込み
function load_build_matrix() {
    if [ -f "build_matrix.txt" ]; then
        mapfile -t PLATFORMS < build_matrix.txt
        log "Loaded custom build matrix with ${#PLATFORMS[@]} targets"
    else
        PLATFORMS=("${DEFAULT_PLATFORMS[@]}")
        log "Using default build matrix with ${#PLATFORMS[@]} targets"
    fi
}

# ビルドディレクトリの準備
function prepare_dirs() {
    log "Preparing build directories..."
    /usr/bin/rm -rf "${BUILD_DIR:?}"/* "${DIST_DIR:?}"/* "${SCRIPTS_DIR:?}"/*
    /usr/bin/mkdir -p "${BUILD_DIR}" "${DIST_DIR}" "${SCRIPTS_DIR}"
}

# アップグレードスクリプトの生成
function generate_upgrade_script() {
    local os=$1
    local arch=$2
    local script_name
    local ext
    
    if [ "${os}" = "windows" ]; then
        script_name="upgrade.bat"
        ext="zip"
    else
        script_name="upgrade.sh"
        ext="tar.gz"
    fi
    
    local script_path="${SCRIPTS_DIR}/upgrade_${os}_${arch}_${script_name}"
    
    {
        if [ "${os}" = "windows" ]; then
            echo "@echo off"
            echo "echo Upgrading ${APP_NAME} for ${os}/${arch}..."
            echo "powershell -Command \"Invoke-WebRequest -Uri '%LATEST_RELEASE_URL%/${APP_NAME}_${os}_${arch}.${ext}' -OutFile 'latest.${ext}'\""
            echo "powershell -Command \"Expand-Archive -Path 'latest.${ext}' -DestinationPath '.' -Force\""
            echo "del latest.${ext}"
        else
            echo "#!/bin/bash"
            echo "echo \"Upgrading ${APP_NAME} for ${os}/${arch}...\""
            echo "curl -L \"\${LATEST_RELEASE_URL}/${APP_NAME}_${os}_${arch}.${ext}\" -o \"latest.${ext}\""
            echo "tar xzf \"latest.${ext}\""
            echo "rm \"latest.${ext}\""
        fi
    } > "${script_path}"
    
    if [ "${os}" != "windows" ]; then
        chmod +x "${script_path}"
    fi
}

# リリースノートの生成
function generate_release_notes() {
    local notes_file="${DIST_DIR}/RELEASE_NOTES.md"
    local prev_tag
    
    prev_tag=$(git describe --abbrev=0 --tags 2>/dev/null || echo "")
    
    {
        echo "# ${APP_NAME} ${VERSION}"
        echo ""
        echo "Build Date: ${BUILD_TIME}"
        echo "Go Version: ${GO_VERSION}"
        echo ""
        echo "## Changes"
        echo ""
        if [ -n "${prev_tag}" ]; then
            git log --pretty=format:"* %s" "${prev_tag}..HEAD"
        else
            git log --pretty=format:"* %s"
        fi
        echo ""
        echo ""
        echo "## Downloads"
        echo ""
        echo "| Platform | Architecture | File | Checksum |"
        echo "|----------|--------------|------|----------|"
    } > "${notes_file}"
    
    log "Generated release notes"
}

# チェックサムの生成と追加
function generate_checksums() {
    log "Generating checksums..."
    cd "${DIST_DIR}" || exit
    
    # チェックサムファイルの生成
    local checksum_file="checksums.sha256"
    find . -type f -not -name "*.sha256" -not -name "RELEASE_NOTES.md" -exec sha256sum {} \; > "${checksum_file}"
    
    # リリースノートにチェックサム情報を追加
    while IFS= read -r line; do
        local sum
        local file
        read -r sum file <<< "${line}"
        file=${file#./}
        if [[ ${file} =~ ^${APP_NAME}_([^_]+)_([^_.]+)\.(tar\.gz|zip)$ ]]; then
            local os="${BASH_REMATCH[1]}"
            local arch="${BASH_REMATCH[2]}"
            echo "| ${os} | ${arch} | ${file} | \`${sum}\` |" >> RELEASE_NOTES.md
        fi
    done < "${checksum_file}"
    
    cd - > /dev/null || exit
}

# アーカイブの作成
function create_archive() {
    local os=$1
    local arch=$2
    local dir_name="${APP_NAME}_${os}_${arch}"
    local source_dir="${BUILD_DIR}/${os}_${arch}"
    
    if [ "${os}" = "windows" ]; then
        log "Creating ZIP archive for ${os}/${arch}..."
        cd "${BUILD_DIR}" || exit
        /usr/bin/zip -q -r "${dir_name}.zip" "${os}_${arch}"
        /usr/bin/mv "${dir_name}.zip" "${DIST_DIR}/"
        cd - > /dev/null || exit
    else
        log "Creating tar.gz archive for ${os}/${arch}..."
        cd "${BUILD_DIR}" || exit
        /usr/bin/tar czf "${dir_name}.tar.gz" "${os}_${arch}"
        /usr/bin/mv "${dir_name}.tar.gz" "${DIST_DIR}/"
        cd - > /dev/null || exit
    fi
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
    
    # デバッグ情報を含むビルドフラグ
    local ldflags=(
        "-X '${MODULE_NAME}/internal/version.Version=${VERSION}'"
        "-X '${MODULE_NAME}/internal/version.BuildTime=${BUILD_TIME}'"
        "-X '${MODULE_NAME}/internal/version.GitCommit=${GIT_COMMIT}'"
        "-X '${MODULE_NAME}/internal/version.GoVersion=${GO_VERSION}'"
    )
    
    GOOS=${os} GOARCH=${arch} go build \
        -o "${output_path}" \
        -ldflags "${ldflags[*]}" \
        -tags "${BUILD_TAGS}" \
        -gcflags "all=-N -l" \
        main.go
        
    log "Built: ${output_path}"
    
    # 付随ファイルのコピー
    for file in README.md LICENSE; do
        if [ -f "${file}" ]; then
            /usr/bin/cp "${file}" "${output_dir}/"
        fi
    done
    
    # アップグレードスクリプトの生成
    generate_upgrade_script "${os}" "${arch}"
    
    create_archive "${os}" "${arch}"
}

# メイン処理
function main() {
    # コマンドラインオプションの処理
    while getopts "t:m:" opt; do
        case ${opt} in
            t)
                BUILD_TAGS="${OPTARG}"
                ;;
            m)
                echo "${OPTARG}" > build_matrix.txt
                ;;
            \?)
                echo "Invalid option: -${OPTARG}" >&2
                exit 1
                ;;
        esac
    done
    
    prepare_dirs
    load_build_matrix
    
    log "Starting multi-platform build..."
    log "Version: ${VERSION}"
    log "Build Time: ${BUILD_TIME}"
    log "Git Commit: ${GIT_COMMIT}"
    log "Build Tags: ${BUILD_TAGS}"
    
    for platform in "${PLATFORMS[@]}"; do
        os=${platform%/*}
        arch=${platform#*/}
        build_for_platform "${os}" "${arch}"
    done
    
    generate_release_notes
    generate_checksums
    
    log "Build completed successfully"
    log "Archives and checksums are available in: ${DIST_DIR}"
    log "Upgrade scripts are available in: ${SCRIPTS_DIR}"
}

# ログフォルダの生成
mkdir -p /workspace/log

# スクリプトの実行
main "$@" 2>&1 | tee -a "/workspace/log/$(date +'%Y-%m-%d-%H-%M-%S')_build.log"
