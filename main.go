package main

import (
	"context"
	"encoding/xml"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/chromedp/chromedp"
	"github.com/schollz/progressbar/v3"
)

// XML構造体の定義
type URLSet struct {
	XMLName xml.Name `xml:"urlset"`
	URLs    []URL    `xml:"url"`
}

type URL struct {
	Loc string `xml:"loc"`
}

type SitemapIndex struct {
	XMLName  xml.Name  `xml:"sitemapindex"`
	Sitemaps []Sitemap `xml:"sitemap"`
}

type Sitemap struct {
	Loc string `xml:"loc"`
}

// DeviceProfile はデバイスの設定を定義
type DeviceProfile struct {
	Name      string
	Width     int
	Height    int
	Mobile    bool
	UserAgent string
}

// ScreenshotGenerator はスクリーンショット生成の設定を保持
type ScreenshotGenerator struct {
	OutputDir   string
	WaitTime    time.Duration
	Devices     []DeviceProfile
	Concurrency int
	progressBar *progressbar.ProgressBar
	errorCount  int
	mutex       sync.Mutex
}

// getDefaultDevices はデフォルトのデバイスプロファイルを返す
func getDefaultDevices() []DeviceProfile {
	return []DeviceProfile{
		{
			Name:      "desktop",
			Width:     1920,
			Height:    1080,
			Mobile:    false,
			UserAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36",
		},
		{
			Name:      "tablet",
			Width:     1024,
			Height:    768,
			Mobile:    true,
			UserAgent: "Mozilla/5.0 (iPad; CPU OS 15_0 like Mac OS X) AppleWebKit/605.1.15",
		},
		{
			Name:      "smartphone",
			Width:     375,
			Height:    667,
			Mobile:    true,
			UserAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15",
		},
	}
}

// extractURLs はサイトマップからURLを抽出
func extractURLs(sitemapURL string) ([]string, error) {
	resp, err := http.Get(sitemapURL)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch sitemap: %v", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response body: %v", err)
	}

	// まずsitemapindexとしてパースを試みる
	var sitemapIndex SitemapIndex
	if err := xml.Unmarshal(body, &sitemapIndex); err == nil && len(sitemapIndex.Sitemaps) > 0 {
		var allURLs []string
		for _, sitemap := range sitemapIndex.Sitemaps {
			urls, err := extractURLs(sitemap.Loc)
			if err != nil {
				log.Printf("Warning: Failed to process sitemap %s: %v", sitemap.Loc, err)
				continue
			}
			allURLs = append(allURLs, urls...)
		}
		return allURLs, nil
	}

	// urlsetとしてパースを試みる
	var urlset URLSet
	if err := xml.Unmarshal(body, &urlset); err != nil {
		return nil, fmt.Errorf("failed to parse XML: %v", err)
	}

	urls := make([]string, 0, len(urlset.URLs))
	for _, u := range urlset.URLs {
		if u.Loc != "" {
			urls = append(urls, u.Loc)
		}
	}

	if len(urls) == 0 {
		return nil, fmt.Errorf("no URLs found in sitemap")
	}

	return urls, nil
}

// captureScreenshot はスクリーンショットを撮影
func (sg *ScreenshotGenerator) captureScreenshot(ctx context.Context, targetURL string, device DeviceProfile) error {
	opts := append(chromedp.DefaultExecAllocatorOptions[:],
		chromedp.Flag("headless", true),
		chromedp.Flag("disable-gpu", true),
		chromedp.Flag("no-sandbox", true),
		chromedp.Flag("disable-web-security", true),
		chromedp.Flag("ignore-certificate-errors", true),
		chromedp.UserAgent(device.UserAgent),
	)

	dateDir := time.Now().Format("20060102_150405")
	deviceDir := filepath.Join(sg.OutputDir, dateDir, device.Name)
	if err := os.MkdirAll(deviceDir, 0755); err != nil {
		return fmt.Errorf("failed to create directory: %v", err)
	}

	allocCtx, cancel := chromedp.NewExecAllocator(ctx, opts...)
	defer cancel()

	taskCtx, cancel := chromedp.NewContext(allocCtx,
		chromedp.WithLogf(log.Printf),
	)
	defer cancel()

	filename := fmt.Sprintf("%s.png", strings.ReplaceAll(targetURL, "/", "_"))
	outputPath := filepath.Join(deviceDir, filename)

	var buf []byte
	if err := chromedp.Run(taskCtx,
		chromedp.EmulateViewport(int64(device.Width), int64(device.Height)),
		chromedp.Navigate(targetURL),
		chromedp.Sleep(sg.WaitTime),
		chromedp.FullScreenshot(&buf, 100),
	); err != nil {
		return fmt.Errorf("failed to capture screenshot: %v", err)
	}

	if err := os.WriteFile(outputPath, buf, 0644); err != nil {
		return fmt.Errorf("failed to save screenshot: %v", err)
	}

	return nil
}

// processURLs は複数のURLを処理
func (sg *ScreenshotGenerator) processURLs(urls []string) error {
	ctx := context.Background()
	sem := make(chan bool, sg.Concurrency)
	var wg sync.WaitGroup

	for _, targetURL := range urls {
		for _, device := range sg.Devices {
			wg.Add(1)
			sem <- true

			go func(url string, dev DeviceProfile) {
				defer wg.Done()
				defer func() { <-sem }()

				if err := sg.captureScreenshot(ctx, url, dev); err != nil {
					sg.mutex.Lock()
					sg.errorCount++
					sg.mutex.Unlock()
					log.Printf("Error: %s (%s): %v", url, dev.Name, err)
				}
				sg.progressBar.Add(1)
			}(targetURL, device)
		}
	}

	wg.Wait()
	return nil
}

func main() {
	var (
		sitemapURL  string
		outputDir   string
		waitTime    int
		concurrency int
		verbose     bool
	)

	flag.StringVar(&sitemapURL, "sitemap", "", "サイトマップのURL")
	flag.StringVar(&outputDir, "output", "screenshots", "出力ディレクトリ")
	flag.IntVar(&waitTime, "wait", 5, "ページ読み込み待機時間（秒）")
	flag.IntVar(&concurrency, "concurrency", 3, "同時実行数")
	flag.BoolVar(&verbose, "verbose", false, "詳細なログを出力")
	flag.Parse()

	if verbose {
		log.SetFlags(log.Ldate | log.Ltime | log.Lmicroseconds)
	} else {
		log.SetFlags(0)
	}

	if sitemapURL == "" {
		log.Fatal("サイトマップのURLを指定してください")
	}

	urls, err := extractURLs(sitemapURL)
	if err != nil {
		log.Fatalf("URLの抽出に失敗: %v", err)
	}

	totalTasks := len(urls) * len(getDefaultDevices())
	generator := &ScreenshotGenerator{
		OutputDir:   outputDir,
		WaitTime:    time.Duration(waitTime) * time.Second,
		Devices:     getDefaultDevices(),
		Concurrency: concurrency,
		progressBar: progressbar.Default(int64(totalTasks)),
	}

	if err := generator.processURLs(urls); err != nil {
		log.Fatalf("スクリーンショット生成エラー: %v", err)
	}
}
