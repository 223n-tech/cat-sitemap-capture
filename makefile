.PHONY: build clean

# デフォルトターゲット
all: build

# ビルド
build:
	@bash scripts/build.sh

# クリーンアップ
clean:
	@rm -rf build
