package main

import (
	"context"
	"encoding/xml"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/chromedp/chromedp"
	"github.com/schollz/progressbar/v3"
)

type (
	URLSet struct {
		XMLName xml.Name `xml:"urlset"`
		URLs    []struct {
			Loc string `xml:"loc"`
		} `xml:"url"`
	}
	SitemapIndex struct {
		XMLName  xml.Name `xml:"sitemapindex"`
		Sitemaps []struct {
			Loc string `xml:"loc"`
		} `xml:"sitemap"`
	}
	DeviceProfile struct {
		Name, UserAgent string
		Width, Height   int
		Mobile          bool
	}
)

type ScreenshotGenerator struct {
	OutputDir         string
	WaitTime          time.Duration
	Devices           []DeviceProfile
	Concurrency       int
	executionDateTime string
	progressBar       *progressbar.ProgressBar
	errorCount        int
	mutex             sync.Mutex
}

func getDefaultDevices() []DeviceProfile {
	return []DeviceProfile{
		{
			Name: "desktop", Width: 1920, Height: 1080,
			UserAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36",
		},
		{
			Name: "tablet", Width: 1024, Height: 768, Mobile: true,
			UserAgent: "Mozilla/5.0 (iPad; CPU OS 15_0 like Mac OS X) AppleWebKit/605.1.15",
		},
		{
			Name: "smartphone", Width: 375, Height: 667, Mobile: true,
			UserAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15",
		},
	}
}

func (sg *ScreenshotGenerator) generateOutputDir(deviceName string) string {
	deviceDir := filepath.Join(sg.OutputDir, sg.executionDateTime, deviceName)
	os.MkdirAll(deviceDir, 0755)
	return deviceDir
}

func extractURLs(sitemapURL string) ([]string, error) {
	resp, err := http.Get(sitemapURL)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	// Try sitemapindex first
	var sitemapIndex SitemapIndex
	if err := xml.Unmarshal(body, &sitemapIndex); err == nil && len(sitemapIndex.Sitemaps) > 0 {
		var allURLs []string
		for _, sitemap := range sitemapIndex.Sitemaps {
			urls, err := extractURLs(sitemap.Loc)
			if err != nil {
				continue
			}
			allURLs = append(allURLs, urls...)
		}
		return allURLs, nil
	}

	// Try urlset
	var urlset URLSet
	if err := xml.Unmarshal(body, &urlset); err != nil {
		return nil, err
	}

	urls := make([]string, 0, len(urlset.URLs))
	for _, u := range urlset.URLs {
		if u.Loc != "" {
			urls = append(urls, u.Loc)
		}
	}
	return urls, nil
}

func (sg *ScreenshotGenerator) captureScreenshot(ctx context.Context, targetURL string, device DeviceProfile) error {
	opts := append(chromedp.DefaultExecAllocatorOptions[:],
		chromedp.Flag("headless", true),
		chromedp.Flag("disable-gpu", true),
		chromedp.Flag("no-sandbox", true),
		chromedp.UserAgent(device.UserAgent),
	)

	allocCtx, cancel := chromedp.NewExecAllocator(ctx, opts...)
	defer cancel()

	taskCtx, cancel := chromedp.NewContext(allocCtx)
	defer cancel()

	taskCtx, cancel = context.WithTimeout(taskCtx, time.Minute*2)
	defer cancel()

	deviceDir := sg.generateOutputDir(device.Name)
	filename := fmt.Sprintf("%s.png", strings.ReplaceAll(url.QueryEscape(targetURL), "%", "_"))
	outputPath := filepath.Join(deviceDir, filename)

	var buf []byte
	err := chromedp.Run(taskCtx,
		chromedp.EmulateViewport(int64(device.Width), int64(device.Height)),
		chromedp.Navigate(targetURL),
		chromedp.Sleep(sg.WaitTime),
		chromedp.FullScreenshot(&buf, 100),
	)
	if err != nil {
		return err
	}

	return os.WriteFile(outputPath, buf, 0644)
}

func (sg *ScreenshotGenerator) processURLs(urls []string) error {
	totalTasks := len(urls) * len(sg.Devices)
	sg.progressBar = progressbar.New(totalTasks)

	ctx := context.Background()
	sem := make(chan bool, sg.Concurrency)
	var wg sync.WaitGroup

	for _, targetURL := range urls {
		log.Printf("URL: %s\n", targetURL)
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

	// 実行時のタイムスタンプを生成
	jst := time.FixedZone("Asia/Tokyo", 9*60*60)
	executionDateTime := time.Now().In(jst).Format("20060102_150405")

	urls, err := extractURLs(sitemapURL)
	if err != nil {
		log.Fatalf("URLの抽出に失敗: %v", err)
	}

	generator := &ScreenshotGenerator{
		OutputDir:         outputDir,
		WaitTime:          time.Duration(waitTime) * time.Second,
		Devices:           getDefaultDevices(),
		Concurrency:       concurrency,
		executionDateTime: executionDateTime,
	}

	if err := generator.processURLs(urls); err != nil {
		log.Fatalf("スクリーンショット生成エラー: %v", err)
	}

	log.Printf("出力ディレクトリ: %s/%s\n", outputDir, executionDateTime)
}
