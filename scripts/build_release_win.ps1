# Windows release build script for Claude Meter
$ErrorActionPreference = "Stop"

$VERSION = "2.0.0"
$APP_NAME = "claude_meter"

Write-Host "=== Flutter Release Build (Windows) ==="
flutter clean
flutter pub get
flutter build windows --release

$OUTPUT = "build\windows\x64\runner\Release"

if (-Not (Test-Path "$OUTPUT\$APP_NAME.exe")) {
    Write-Host "ERROR: Build failed - exe not found" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Build Complete ==="
Write-Host "Output: $OUTPUT\"
$size = (Get-ChildItem "$OUTPUT" -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host ("Size: {0:N1} MB" -f $size)
