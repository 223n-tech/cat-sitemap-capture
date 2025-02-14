#!/usr/bin/env bash

set -e

# 設定
DOCS_DIR="build/docs"
COVERAGE_DIR="build/coverage"
REPORT_DIR="build/reports"
MODULE_NAME="github.com/223n-tech/cat-sitemap-capture"

# ログ出力関数
function log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# 必要なツールのインストール確認とインストール
function ensure_tools() {
    log "Checking and installing required tools..."
    
    # golang.org/x/tools/cmd/godocのインストール
    if ! command -v godoc &> /dev/null; then
        log "Installing godoc..."
        go install golang.org/x/tools/cmd/godoc@latest
        export PATH=$PATH:$(go env GOPATH)/bin
    fi
    
    # gocovのインストール
    if ! command -v gocov &> /dev/null; then
        log "Installing gocov..."
        go install github.com/axw/gocov/gocov@latest
    fi
    
    # golangci-lintのインストール
    if ! command -v golangci-lint &> /dev/null; then
        log "Installing golangci-lint..."
        curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin
    fi
    
    log "All required tools are installed"
}

# ディレクトリ準備
function prepare_dirs() {
    mkdir -p "${DOCS_DIR}"/{pkg,src} "${COVERAGE_DIR}" "${REPORT_DIR}"
}

# Godocの生成
function generate_godoc() {
    log "Generating Go documentation..."
    
    # 現在のディレクトリを取得
    local current_dir=$(pwd)
    
    # カスタムCSSの作成
    cat > "${DOCS_DIR}/custom.css" << EOF
body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen-Sans, Ubuntu, Cantarell, "Helvetica Neue", sans-serif;
    line-height: 1.6;
}
pre {
    background-color: #f5f5f5;
    padding: 1em;
    border-radius: 4px;
}
EOF
    
    # ソースコードをdocsディレクトリにコピー
    log "Copying source files..."
    mkdir -p "${DOCS_DIR}/src/${MODULE_NAME}"
    cp -r ./* "${DOCS_DIR}/src/${MODULE_NAME}/"
    
    # GOPATH環境変数を一時的に変更
    export GOPATH="${current_dir}/${DOCS_DIR}"
    
    # モジュールのドキュメントを生成
    cd "${DOCS_DIR}"
    log "Starting godoc server..."
    godoc -http=:6060 -goroot="${DOCS_DIR}" &
    GODOC_PID=$!
    
    # サーバーの起動を待つ
    log "Waiting for godoc server to start..."
    for i in {1..30}; do
        if curl -s http://localhost:6060 > /dev/null; then
            break
        fi
        sleep 1
    done
    
    # ドキュメントの取得
    log "Fetching documentation..."
    mkdir -p "pkg/${MODULE_NAME}"
    wget --recursive --no-parent --no-host-directories --cut-dirs=3 \
        --reject "index.html*" \
        --directory-prefix="pkg/${MODULE_NAME}" \
        http://localhost:6060/pkg/${MODULE_NAME}/
    
    # godocサーバーの停止
    log "Stopping godoc server..."
    kill $GODOC_PID || true
    
    # 元のディレクトリとGOPATHに戻る
    cd "${current_dir}"
    export GOPATH=$(go env GOPATH)
    
    log "Go documentation generated in ${DOCS_DIR}/pkg/${MODULE_NAME}"
}

# テストカバレッジレポートの生成
function generate_coverage() {
    log "Generating test coverage report..."
    
    # テストの実行とカバレッジの収集
    go test -v -race -coverprofile="${COVERAGE_DIR}/coverage.txt" -covermode=atomic ./...
    
    # HTMLレポートの生成
    go tool cover -html="${COVERAGE_DIR}/coverage.txt" -o "${COVERAGE_DIR}/coverage.html"
    
    # XMLレポートの生成（CI/CDツール用）
    if command -v gocov &> /dev/null; then
        gocov convert "${COVERAGE_DIR}/coverage.txt" | gocov-xml > "${COVERAGE_DIR}/coverage.xml"
    fi
    
    log "Coverage reports generated in ${COVERAGE_DIR}"
}

# コード品質レポートの生成
function generate_quality_report() {
    log "Generating code quality report..."
    
    if command -v golangci-lint &> /dev/null; then
        # golangci-lintの実行
        golangci-lint run --out-format=html > "${REPORT_DIR}/lint-report.html"
        golangci-lint run --out-format=json > "${REPORT_DIR}/lint-report.json"
        
        log "Quality reports generated in ${REPORT_DIR}"
    else
        log "Warning: golangci-lint not installed, skipping quality report generation"
    fi
}

# メインの処理
function main() {
    ensure_tools
    prepare_dirs
    generate_godoc
    generate_coverage
    generate_quality_report
    
    log "All documentation and reports generated successfully"
}


# ログフォルダの生成
mkdir -p /workspace/log

# スクリプトの実行
main "$@" 2>&1 | tee -a "/workspace/log/$(date +'%Y-%m-%d-%H-%M-%S')_generate_docs.log"

