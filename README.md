# Cat Sitemap Capture

## このスクリプトについて

* このスクリプトでは、sitemap.xmlにあるすべてのページのスクリーンショット画像を取得します。

## インストール

### 必要なもの

* Go言語と依存パッケージ
  * golang
  * chromedp
  * progressbar
* 実行するには、次のうち、いずれかのブラウザが必要です。
  * Google Chrome
  * Chromium
* 日本語サポートのため、フォントが必要です。
  * 各種日本語フォント
  * 言語パック
  * ロケール設定

### debianで実行している場合

* 次のスクリプトを管理者権限で実行することで、必要なパッケージなどを自動的にインストールします。

```bash
sudo bash ./install_debian.sh
```

## 使い方

* 次のコマンドで、実行されます。

```go
# 基本的な使用方法
go run main.go -sitemap https://haru.223n.tech/sitemap.xml

# 詳細なオプションを指定
go run main.go \
  -sitemap https://haru.223n.tech/sitemap.xml \
  -output ./screenshots \
  -wait 10 \
  -concurrency 5
```

## 特徴

* ChromeDP使用によるヘッドレスブラウザ制御
* 非同期処理による高速な実行
* メモリ効率の良い処理
* デバイスエミュレーション
* プログレス表示

## エラーハンドリング

* 非同期処理のエラー管理
* タイムアウト設定
* リソース使用の制御

## 出力ディレクトリ構造

```sh
screenshots/
  ├── 20250213_141530/      # 1回目の実行（2025年2月13日 14:15:30）
  │   ├── desktop/
  │   ├── tablet/
  │   └── smartphone/
  └── 20250213_142045/      # 2回目の実行（2025年2月13日 14:20:45）
      ├── desktop/
      ├── tablet/
      └── smartphone/
```
