# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ClaudeMeter — Desktop system tray application that monitors Claude AI API usage in real-time. Built with Flutter (Dart), it authenticates via OAuth 2.0 with PKCE and displays usage statistics across three tiers (5-hour, 7-day, 7-day Sonnet). Supports macOS and Windows. UI language is Korean.

## Build & Development Commands

```bash
# Run the app
flutter run -d macos      # macOS
flutter run -d windows    # Windows

# Build release
flutter build macos --release
flutter build windows --release

# Build release DMG (macOS 배포용)
./scripts/build_release.sh

# Build release (Windows 배포용)
powershell scripts/build_release_win.ps1

# Run all tests (89 tests across 8 files)
flutter test

# Run a single test file
flutter test test/pkce_test.dart

# Run tests with name filter
flutter test --name "UsageTier"

# Static analysis
flutter analyze

# Get dependencies
flutter pub get
```

## Architecture

**Service-based MVC** with manual `setState()` state management (no Provider/Riverpod/Bloc).

### Initialization flow (`main.dart`)
Services are instantiated in `main()` and injected into `ClaudeMeterApp`:
```
main() → [Windows: configureWindowsWindow()] → create services → run app
  macOS: AppDelegate creates NSPanel (280x400)
  Windows: window_manager configures frameless window (280x400)
```

### Data flow
```
OAuthService (AES-256 encrypted file ~/.claude/.credentials.json)
    → UsageService (Bearer token → GET /api/oauth/usage)
    → UsageData model → HomeScreen (UsageBar widgets)

ConfigService (SharedPreferences) ↔ SettingsScreen
TrayService (system tray menu) ↔ AppState (window toggle/refresh)
```

### OAuth PKCE flow
1. `OAuthService.login()` starts local callback server, opens browser to `claude.ai/oauth/authorize`
2. Browser redirects back to localhost callback with authorization code
3. `_exchangeCode()` → tokens AES-256 encrypted → saved to `~/.claude/.credentials.json` (chmod 600 on POSIX)
4. `getAccessToken()` auto-refreshes expired tokens (1-minute expiry buffer)

### Key patterns
- **Immutable models** with `const` constructors, `fromJson()`/`toJson()`, `copyWith()`
- **Defensive JSON parsing** — all `fromJson()` methods handle missing/wrong types with defaults
- **Callback-based communication** — screens receive callbacks, not service references
- **Per-request HttpClient** with `badCertificateCallback` rejection

## Project Structure

```
scripts/
├── build_release.sh       # macOS 릴리스 빌드 + DMG 패키징
└── build_release_win.ps1  # Windows 릴리스 빌드
lib/
├── main.dart              # Entry point, window/tray init, service wiring
├── app.dart               # Root StatefulWidget, global state, auto-refresh timer, WindowListener (Win)
├── models/                # Immutable data classes
│   ├── config.dart        # AppConfig (refresh interval, display toggles)
│   ├── credentials.dart   # OAuth tokens (access, refresh, expiry)
│   └── usage_data.dart    # UsageTier + UsageData (utilization, reset time)
├── services/              # Business logic
│   ├── oauth_service.dart # OAuth 2.0 + PKCE, token management, AES-256 encrypted file storage
│   ├── usage_service.dart # API usage data fetching
│   ├── config_service.dart# SharedPreferences persistence
│   └── tray_service.dart  # System tray icon and menu (platform-aware)
├── screens/               # Full-page layouts
│   ├── home_screen.dart   # Usage display or login view
│   └── settings_screen.dart # Config UI (display toggles, interval, logout)
├── widgets/               # Reusable components
│   ├── login_view.dart    # One-click OAuth login (browser → auto callback)
│   └── usage_bar.dart     # Color-coded progress bar with tier icon
└── utils/
    ├── constants.dart     # API endpoints, OAuth client ID, timeouts, encryption salt
    ├── pkce.dart          # PKCE verifier/challenge/state generation
    └── platform_window.dart # Windows window configuration (window_manager)
```

## UI Theme

라이트 모드 팝업 스타일:
- **macOS 배경**: NSVisualEffectView (.menu material, 95% 불투명, behindWindow blending)
- **Windows 배경**: 반투명 솔리드 (`Color(0xF0F2F2F7)`), 둥근 모서리 10px
- **윈도우**: Borderless, 280x400, 둥근 모서리 10px, Flutter 배경 transparent
- **사용량 바**: Green `34C759` (<50%) → Yellow `FFCC00` (50-70%) → Orange `FF9500` (70-90%) → Red `FF3B30` (>=90%)
- **티어 아이콘**: timer (5시간), calendar (주간), auto_awesome (Sonnet)

## API Endpoints

- Token exchange: `https://console.anthropic.com/v1/oauth/token`
- Authorization: `https://claude.ai/oauth/authorize`
- Usage data: `https://api.anthropic.com/api/oauth/usage` (header: `anthropic-beta: oauth-2025-04-20`)
- OAuth Client ID: `9d1c250a-e61b-44d9-88ed-5944d1962f5e` (public client, not a secret)

## Credential Storage

- **AES-256-CBC 암호화** 파일 저장: `~/.claude/.credentials.json`
- **macOS (샌드박스)**: 앱 컨테이너 내부 경로 (`~/Library/Containers/<bundle-id>/Data/.claude/.credentials.json`). 앱 샌드박스가 `$HOME`을 컨테이너 경로로 리다이렉트. 파일 권한 600 (POSIX chmod via FFI). Claude CLI의 `~/.claude/`와 별도 경로.
- **Windows**: `%USERPROFILE%\.claude\.credentials.json` (NTFS ACL 보호, 별도 chmod 불필요)
- 경로 해석: `HOME` → `USERPROFILE` 폴백 (Windows 호환)
- 키 생성: `SHA-256(hostname + ":" + username + ":" + salt)` → 32바이트 AES 키 (사용자 입력 불필요)
- 저장 포맷: `{ "claudeAiOauth": { "iv": "base64...", "data": "AES-256-CBC encrypted base64..." } }`
- 레거시 평문 JSON 자동 감지 → 암호화 포맷으로 자동 마이그레이션
- 패키지: `crypto` (SHA-256 키 유도), `encrypt` (AES-256-CBC)

## Platform Details

### macOS
- **앱 샌드박스 활성화** (`com.apple.security.app-sandbox: true`)
  - entitlements: `network.client` (API 통신), `network.server` (OAuth 콜백 서버)
  - `$HOME`이 앱 컨테이너 (`~/Library/Containers/<bundle-id>/Data/`)로 리다이렉트됨
- AppDelegate.swift: NSPanel + NSVisualEffectView
- `panel.contentViewController` 사용 금지 — `contentView`를 덮어씀
- Flutter 투명 배경: `DispatchQueue.main.async`로 CAMetalLayer `isOpaque = false` 설정 필요
- 중복 실행 방지: `NSRunningApplication` 체크

### Windows
- `windows/runner/main.cpp`: Named Mutex로 중복 실행 방지
- `platform_window.dart`: `window_manager`로 frameless 윈도우 설정
- `app.dart`: `WindowListener`로 포커스 해제 시 자동 숨김, 트레이 클릭 토글
- 트레이 아이콘: `assets/tray_icon_win.png` (32x32 표준 PNG)
- User-Agent: Windows용 별도 UA 문자열 (`constants.dart`)
