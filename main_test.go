package main

import (
	"encoding/xml"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"github.com/schollz/progressbar/v3"
)

// テスト用のヘルパー関数
func createTestGenerator() *ScreenshotGenerator {
	return &ScreenshotGenerator{
		OutputDir:   "test-output",
		WaitTime:    time.Second * 5,
		Devices:     getDefaultDevices(),
		Concurrency: 3,
		progressBar: nil,
		errorCount:  0,
	}
}

func TestGetDefaultDevices(t *testing.T) {
	devices := getDefaultDevices()

	// デバイスの数を確認
	expectedCount := 3
	if len(devices) != expectedCount {
		t.Errorf("Expected %d devices, got %d", expectedCount, len(devices))
	}

	// 各デバイスの設定を確認
	deviceNames := map[string]bool{
		"desktop":    false,
		"tablet":     false,
		"smartphone": false,
	}

	for _, device := range devices {
		if _, exists := deviceNames[device.Name]; !exists {
			t.Errorf("Unexpected device name: %s", device.Name)
		}
		deviceNames[device.Name] = true

		// デバイスの基本設定を確認
		if device.Width <= 0 {
			t.Errorf("Device %s has invalid width: %d", device.Name, device.Width)
		}
		if device.Height <= 0 {
			t.Errorf("Device %s has invalid height: %d", device.Name, device.Height)
		}
		if device.UserAgent == "" {
			t.Errorf("Device %s has empty user agent", device.Name)
		}
	}

	// すべてのデバイスが存在することを確認
	for name, found := range deviceNames {
		if !found {
			t.Errorf("Device %s not found in default devices", name)
		}
	}
}

func TestScreenshotGenerator(t *testing.T) {
	generator := createTestGenerator()

	// 基本的な設定の確認
	if generator.OutputDir == "" {
		t.Error("Output directory is empty")
	}

	if generator.WaitTime <= 0 {
		t.Error("Wait time should be positive")
	}

	if len(generator.Devices) == 0 {
		t.Error("No devices configured")
	}

	if generator.Concurrency <= 0 {
		t.Error("Concurrency should be positive")
	}
}

func TestDeviceProfile(t *testing.T) {
	device := DeviceProfile{
		Name:      "test-device",
		Width:     1024,
		Height:    768,
		Mobile:    false,
		UserAgent: "test-agent",
	}

	// デバイスプロファイルの検証
	if device.Name != "test-device" {
		t.Errorf("Expected device name to be 'test-device', got '%s'", device.Name)
	}

	if device.Width != 1024 {
		t.Errorf("Expected width to be 1024, got %d", device.Width)
	}

	if device.Height != 768 {
		t.Errorf("Expected height to be 768, got %d", device.Height)
	}

	if device.Mobile {
		t.Error("Expected mobile to be false")
	}

	if device.UserAgent != "test-agent" {
		t.Errorf("Expected user agent to be 'test-agent', got '%s'", device.UserAgent)
	}
}

func TestURLSetParsing(t *testing.T) {
	// テスト用のXMLデータ
	xmlData := `<?xml version="1.0" encoding="UTF-8"?>
	<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
		<url>
			<loc>https://example.com/page1</loc>
		</url>
		<url>
			<loc>https://example.com/page2</loc>
		</url>
	</urlset>`

	var urlset URLSet
	err := xml.Unmarshal([]byte(xmlData), &urlset)
	if err != nil {
		t.Fatalf("Failed to parse XML: %v", err)
	}

	if len(urlset.URLs) != 2 {
		t.Errorf("Expected 2 URLs, got %d", len(urlset.URLs))
	}

	expectedURLs := []string{
		"https://example.com/page1",
		"https://example.com/page2",
	}

	for i, url := range urlset.URLs {
		if url.Loc != expectedURLs[i] {
			t.Errorf("Expected URL %s, got %s", expectedURLs[i], url.Loc)
		}
	}
}

func TestExtractURLs(t *testing.T) {
	testServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		sitemap := `<?xml version="1.0" encoding="UTF-8"?>
		<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
			<url><loc>https://example.com/page1</loc></url>
			<url><loc>https://example.com/page2</loc></url>
		</urlset>`
		w.Header().Set("Content-Type", "application/xml")
		w.Write([]byte(sitemap))
	}))
	defer testServer.Close()

	urls, err := extractURLs(testServer.URL)
	if err != nil {
		t.Fatalf("Failed to extract URLs: %v", err)
	}

	expectedCount := 2
	if len(urls) != expectedCount {
		t.Errorf("Expected %d URLs, got %d", expectedCount, len(urls))
	}

	// 無効なURLのテスト
	_, err = extractURLs("invalid-url")
	if err == nil {
		t.Error("Expected error for invalid URL")
	}
}

func TestProcessURLs(t *testing.T) {
	generator := &ScreenshotGenerator{
		OutputDir:   "test_output",
		WaitTime:    time.Second,
		Devices:     getDefaultDevices(),
		Concurrency: 1,
		progressBar: progressbar.NewOptions(1),
	}

	urls := []string{"https://example.com"}
	err := generator.processURLs(urls)

	// プロセスが実行されることを確認
	if err != nil {
		t.Errorf("Process URLs failed: %v", err)
	}

	// クリーンアップ
	os.RemoveAll("test_output")
}
