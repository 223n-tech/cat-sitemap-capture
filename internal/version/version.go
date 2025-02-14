package version

var (
	// Version はアプリケーションのバージョン
	Version = "dev"

	// BuildTime はビルド時刻
	BuildTime = "unknown"

	// GitCommit はGitのコミットハッシュ
	GitCommit = "unknown"

	// GoVersion は使用されたGoのバージョン
	GoVersion = "unknown"
)

// GetVersionInfo はバージョン情報を返します
func GetVersionInfo() map[string]string {
	return map[string]string{
		"version":   Version,
		"buildTime": BuildTime,
		"gitCommit": GitCommit,
		"goVersion": GoVersion,
	}
}
