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
main() → init window (320x420) → create services → init tray → run app
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
│   └── usage_bar.dart     # Color-coded progress bar (green/yellow/orange/red)
└── utils/
    ├── constants.dart     # API endpoints, OAuth client ID, timeouts
    └── pkce.dart          # PKCE verifier/challenge/state generation
```

## UI Theme

Catppuccin Mocha dark theme. Key colors:
- Background: `0xFF1E1E2E` (Base), Surface: `0xFF313244`
- Usage bar: Green `A6E3A1` (<50%) → Yellow `F9E2AF` (50-70%) → Orange `FAB387` (70-90%) → Red `F38BA8` (≥90%)

## API Endpoints

- Token exchange: `https://console.anthropic.com/v1/oauth/token`
- Authorization: `https://claude.ai/oauth/authorize`
- Usage data: `https://api.anthropic.com/api/oauth/usage` (header: `anthropic-beta: oauth-2025-04-20`)
- OAuth Client ID: `9d1c250a-e61b-44d9-88ed-5944d1962f5e` (public client, not a secret)

## Platform Details

- **macOS only** — uses system tray (`tray_manager`), window manager, Keychain storage
- Window: 320x420px default, min 280x350, max 400x500, hidden title bar
- Legacy credential migration path: `~/.claude/.credentials.json` → Keychain
