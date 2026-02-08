# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

macOS system tray application that monitors Claude AI API usage in real-time. Built with Flutter (Dart), it authenticates via OAuth 2.0 with PKCE and displays usage statistics across three tiers (5-hour, 7-day, 7-day Sonnet). UI language is Korean.

## Build & Development Commands

```bash
# Run the app (macOS only)
flutter run -d macos

# Build release
flutter build macos

# Run all tests (91 tests across 6 files)
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
Services are instantiated in `main()` and injected into `ClaudeMonitorApp`:
```
main() → create services → run app → AppDelegate creates NSPanel (280x400)
```

### Data flow
```
OAuthService (credentials via macOS Keychain)
    → UsageService (Bearer token → GET /api/oauth/usage)
    → UsageData model → HomeScreen (UsageBar widgets)

ConfigService (SharedPreferences) ↔ SettingsScreen
TrayService (system tray menu) ↔ AppState (window toggle/refresh)
```

### OAuth PKCE flow
1. `OAuthService.startLogin()` opens browser to `claude.ai/oauth/authorize`
2. User copies displayed authorization code from browser
3. User pastes code into app → `exchangeCodeForTokens()` → tokens saved to Keychain
4. `getAccessToken()` auto-refreshes expired tokens (1-minute expiry buffer)

### Key patterns
- **Immutable models** with `const` constructors, `fromJson()`/`toJson()`, `copyWith()`
- **Defensive JSON parsing** — all `fromJson()` methods handle missing/wrong types with defaults
- **Callback-based communication** — screens receive callbacks, not service references
- **Per-request HttpClient** with `badCertificateCallback` rejection

## Project Structure

```
lib/
├── main.dart              # Entry point, window/tray init, service wiring
├── app.dart               # Root StatefulWidget, global state, auto-refresh timer
├── models/                # Immutable data classes
│   ├── config.dart        # AppConfig (refresh interval, display toggles)
│   ├── credentials.dart   # OAuth tokens (access, refresh, expiry)
│   └── usage_data.dart    # UsageTier + UsageData (utilization, reset time)
├── services/              # Business logic
│   ├── oauth_service.dart # OAuth 2.0 + PKCE, token management, Keychain storage
│   ├── usage_service.dart # API usage data fetching
│   ├── config_service.dart# SharedPreferences persistence
│   └── tray_service.dart  # System tray icon and menu
├── screens/               # Full-page layouts
│   ├── home_screen.dart   # Usage display or login view
│   └── settings_screen.dart # Config UI (display toggles, interval, logout)
├── widgets/               # Reusable components
│   ├── login_view.dart    # Two-phase OAuth login (browser → code paste)
│   └── usage_bar.dart     # Color-coded progress bar with tier icon
└── utils/
    ├── constants.dart     # API endpoints, OAuth client ID, timeouts
    └── pkce.dart          # PKCE verifier/challenge/state generation
```

## UI Theme

macOS 네이티브 팝업 스타일 (라이트 모드):
- **배경**: NSVisualEffectView (.menu material, 95% 불투명, behindWindow blending)
- **윈도우**: Borderless NSPanel, 둥근 모서리 10px, Flutter 배경 transparent
- **사용량 바**: Green `34C759` (<50%) → Yellow `FFCC00` (50-70%) → Orange `FF9500` (70-90%) → Red `FF3B30` (>=90%)
- **티어 아이콘**: timer (5시간), calendar (주간), auto_awesome (Sonnet)

## API Endpoints

- Token exchange: `https://console.anthropic.com/v1/oauth/token`
- Authorization: `https://claude.ai/oauth/authorize`
- Usage data: `https://api.anthropic.com/api/oauth/usage` (header: `anthropic-beta: oauth-2025-04-20`)
- OAuth Client ID: `9d1c250a-e61b-44d9-88ed-5944d1962f5e` (public client, not a secret)

## Platform Details

- **macOS only** — uses system tray, Keychain storage
- Window: Borderless NSPanel 280x400, NSVisualEffectView 배경, 둥근 모서리 10px
- `panel.contentViewController` 사용 금지 — `contentView`를 덮어씀. NSVisualEffectView를 contentView로 설정하고 Flutter view를 subview로 추가
- Flutter 투명 배경: `DispatchQueue.main.async`로 CAMetalLayer `isOpaque = false` 설정 필요
- Legacy credential migration path: `~/.claude/.credentials.json` → Keychain
