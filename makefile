.PHONY: all build clean test install-tools docs test-report quality-check coverage-report ci

# デフォルトターゲット
all: test build

# ビルド
build:
	@bash scripts/build.sh

# カスタムビルド（タグ指定）
custom-build:
	@bash scripts/build.sh -t "$(TAGS)"

# カスタムビルド（ビルドマトリックス指定）
matrix-build:
	@bash scripts/build.sh -m "$(MATRIX)"

# リリースビルド
release:
	@bash scripts/build.sh -t "release,production" -m "$(MATRIX)"

# クリーンアップ
clean:
	@rm -rf build/

# 依存関係の更新
deps:
	@go mod tidy

# 必要なツールのインストール
install-tools:
	@go install golang.org/x/tools/cmd/godoc@latest
	@go install github.com/axw/gocov/gocov@latest
	@go install github.com/AlekSi/gocov-xml@latest
	@curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $$(go env GOPATH)/bin

# テストの実行
test:
	@go test -v ./...

# ドキュメント生成
docs: install-tools
	@bash scripts/generate_docs.sh

# テストレポート生成
test-report: install-tools
	@go test -v -race -coverprofile=build/coverage/coverage.txt -covermode=atomic ./...
	@go tool cover -html=build/coverage/coverage.txt -o build/coverage/coverage.html

# コード品質チェック
quality-check: install-tools
	@golangci-lint run --timeout=5m

# カバレッジレポート生成
coverage-report: install-tools
	@mkdir -p build/coverage
	@go test -v -race -coverprofile=build/coverage/coverage.txt -covermode=atomic ./...
	@go tool cover -func=build/coverage/coverage.txt

# CIチェック（ローカル実行用）
ci: install-tools coverage-report quality-check docs
