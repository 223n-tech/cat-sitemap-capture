# Cat Sitemap Capture

## このスクリプトについて

* このスクリプトでは、sitemap.xmlにあるすべてのページのスクリーンショット画像を取得します。

## 開発環境の構築

### 必要なもの

* Go言語と依存パッケージ
  * golang
  * chromedp
  * progressbar
* ブラウザ（いずれかが必要）
  * Google Chrome
  * Chromium
* 日本語フォントなど（日本語サイトへの対応）
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

* `screenshots` : 大元のフォルダーです。
  * `yyyyMMdd_hhmmss` : 実行日時で生成されたフォルダーです。
    * `desktop`, `tablet`, `smartphone` : 端末環境ごとに生成されたフォルダーです。
      * `{url}.png` : エンコードされたURLが使用されたpngファイルです。

```sh
screenshots/
  ├── 20250213_141530/      # 1回目の実行（2025年2月13日 14:15:30）
  │   ├── desktop/
  │   │   └── https_3A_2F_2Fharu.223n.tech_2F.png
  │   ├── tablet/
  │   │   └── https_3A_2F_2Fharu.223n.tech_2F.png
  │   └── smartphone/
  │        └── https_3A_2F_2Fharu.223n.tech_2F.png
  │
  └── 20250213_142045/      # 2回目の実行（2025年2月13日 14:20:45）
        ├── desktop/
        │   └── https_3A_2F_2Fharu.223n.tech_2F.png
        ├── tablet/
        │   └── https_3A_2F_2Fharu.223n.tech_2F.png
        └── smartphone/
             └── https_3A_2F_2Fharu.223n.tech_2F.png
```

## ビルド

* makeコマンドを実行するか、スクリプトを実行してください。

```sh
make
```

```sh
./scripts/build.sh
```
