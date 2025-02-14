package version

import (
	"testing"
)

func TestGetVersionInfo(t *testing.T) {
	info := GetVersionInfo()

	// 必要なキーが存在することを確認
	requiredKeys := []string{"version", "buildTime", "gitCommit", "goVersion"}
	for _, key := range requiredKeys {
		if _, exists := info[key]; !exists {
			t.Errorf("Expected key %s not found in version info", key)
		}
	}

	// デフォルト値の確認
	if info["version"] != "dev" {
		t.Errorf("Expected version to be 'dev', got %s", info["version"])
	}

	if info["buildTime"] != "unknown" {
		t.Errorf("Expected buildTime to be 'unknown', got %s", info["buildTime"])
	}

	if info["gitCommit"] != "unknown" {
		t.Errorf("Expected gitCommit to be 'unknown', got %s", info["gitCommit"])
	}

	if info["goVersion"] != "unknown" {
		t.Errorf("Expected goVersion to be 'unknown', got %s", info["goVersion"])
	}
}
