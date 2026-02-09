# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ClaudeMeter — Desktop system tray application with dual-mode UI for Claude AI monitoring. Built with Flutter (Dart), supports macOS and Windows. UI language is Korean.

**두 가지 모드:**
- **Plan Mode**: OAuth 2.0 + PKCE 인증, 3-tier 사용률 표시 (280x400)
- **API Mode**: 로컬 JSONL 파싱, Current/History 탭 (400x600)

첫 실행 시 모드 선택 → 재시작 시 선택 모드 직접 진입. 모드 변경 버튼으로 전환 가능.

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

# Run all tests (128 tests across 11 files)
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
  macOS: AppDelegate creates NSPanel (280x400 initial)
  Windows: window_manager configures frameless window (280x400 initial)
```

### Dual-mode routing (`app.dart`)
```
_init() → loadConfig()
  appMode == null  → ModeSelectScreen (280x400)
  appMode == plan  → resizeWindow(280x400) → HomeScreen + auto-refresh usage
  appMode == api   → resizeWindow(400x600) → ApiHomeScreen + auto-refresh costs
```

### Data flow
```
[Plan 모드]
OAuthService (AES-256 encrypted file ~/.claude/.credentials.json)
    → UsageService (Bearer token → GET /api/oauth/usage)
    → UsageData model → HomeScreen (UsageBar widgets)

[API 모드]
CostTrackingService (local JSONL parsing from ~/.claude/projects/)
    → PricingTable (model-specific rates) → CostData model
    → ApiHomeScreen (Current tab: 기간별 비용/토큰, 모델별 breakdown)
    → ApiHomeScreen (History tab: 월별 네비게이션, 일별 비용/토큰)

ConfigService (SharedPreferences) ↔ SettingsScreen (Plan 모드 전용)
TrayService (system tray menu) ↔ AppState (모드별 메뉴 구성)
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
├── app.dart               # Root StatefulWidget, dual-mode routing, window resize, WindowListener
├── models/
│   ├── config.dart        # AppMode enum, AppConfig (appMode, refresh interval, display toggles)
│   ├── cost_data.dart     # CostData, ModelCost, DailyCost (with totalTokens)
│   ├── credentials.dart   # OAuth tokens (access, refresh, expiry)
│   └── usage_data.dart    # UsageTier + UsageData (utilization, reset time)
├── services/
│   ├── cost_tracking_service.dart # JSONL parsing, daily token accumulation, cost calculation
│   ├── oauth_service.dart # OAuth 2.0 + PKCE, token management, AES-256 encrypted file storage
│   ├── usage_service.dart # API usage data fetching
│   ├── config_service.dart# SharedPreferences persistence
│   └── tray_service.dart  # System tray icon, mode-aware context menu
├── screens/
│   ├── mode_select_screen.dart # First-launch mode selection (Plan/API)
│   ├── api_home_screen.dart    # API mode: Current tab (period costs) + History tab (monthly)
│   ├── home_screen.dart        # Plan mode: usage display or login view
│   └── settings_screen.dart    # Plan mode: config UI (display toggles, interval, logout)
├── widgets/
│   ├── cost_bar.dart      # Model-colored progress bar with optional percentage
│   ├── login_view.dart    # One-click OAuth login (browser → auto callback)
│   └── usage_bar.dart     # Color-coded progress bar with tier icon
└── utils/
    ├── constants.dart     # API endpoints, OAuth client ID, timeouts, encryption salt
    ├── pkce.dart          # PKCE verifier/challenge/state generation
    ├── pricing.dart       # Model pricing table (USD/MTok), TokenUsage, cost calculation
    └── platform_window.dart # Window sizing (planWindowSize/apiWindowSize), resizeWindow(), MethodChannel
```

## UI Theme

라이트 모드 팝업 스타일:
- **macOS 배경**: NSVisualEffectView (.menu material, 95% 불투명, behindWindow blending)
- **Windows 배경**: 반투명 솔리드 (`Color(0xF0F2F2F7)`), 둥근 모서리 10px
- **Plan 모드 윈도우**: 280x400, borderless, 둥근 모서리 10px
- **API 모드 윈도우**: 400x600, borderless, 둥근 모서리 10px
- **사용량 바**: Green `34C759` (<50%) → Yellow `FFCC00` (50-70%) → Orange `FF9500` (70-90%) → Red `FF3B30` (>=90%)
- **티어 아이콘**: timer (5시간), calendar (주간), auto_awesome (Sonnet)
- **비용 바 색상**: Purple `AF52DE` (Opus) / Blue `007AFF` (Sonnet) / Green `34C759` (Haiku)

## Cost Tracking (JSONL 기반)

- **데이터 소스**: `~/.claude/projects/` 내 `.jsonl` 파일 (서브에이전트 포함)
- **파싱 대상**: `type: "assistant"` 라인의 `message.usage` 필드
- **중복 제거**: `message.id` + `requestId` 복합 키로 중복 엔트리 스킵 (Claude Code가 동일 메시지를 파일당 3~5회 중복 기록)
- **토큰 종류**: input, cache_creation (5m/1h ephemeral), cache_read, output
- **가격표**: `pricing.dart`에 모델별 USD/MTok 하드코딩 (2026-02 기준)
- **비용 공식**: `Σ(tokens × rate) / 1,000,000` (모델별)
- **타임존**: `_dateKey()`에서 UTC 타임스탬프를 `.toLocal()`로 변환 후 일별 집계
- **일별 집계**: 비용, 메시지 수, 전체 토큰 수 (DailyCost.totalTokens)
- **기간별 비용**: `ApiHomeScreen`에서 `dailyCosts`를 날짜 필터링하여 오늘/주/월 계산 (서비스가 아닌 UI 레벨)
- **화면 구성** (API 모드):
  - **현재 탭**: 오늘/이번 주/이번 달 비용+토큰, 모델별 사용 요금
  - **기록 탭**: 월 네비게이터, 월 합계/일 평균/최대, 일별 비용+토큰
- **macOS 접근**: `com.apple.security.temporary-exception.files.absolute-path.read-only` entitlement로 `/Users/` 읽기 허용
- **사양 문서**: `docs/claude-apicost-spec.md` 참조

### ccusage와의 비용 차이

ClaudeMeter는 ccusage(`github.com/ryoppippi/ccusage`) 대비 1h ephemeral 캐시 사용 시 약 15~20% 높은 비용을 표시한다. 이는 버그가 아닌 가격 정책 차이:

| 항목 | ClaudeMeter | ccusage |
|------|-------------|---------|
| 5m cache write | 1.25x input (정확) | 1.25x input (정확) |
| **1h cache write** | **2x input (Anthropic 공식)** | **1.25x input (5m과 동일 적용)** |
| 중복 제거 | `message.id:requestId` | `message.id:requestId` |
| `costUSD` 필드 | 미사용 (현재 JSONL에 null) | auto 모드에서 사용 (null이면 계산) |
| Tiered pricing | 미지원 | Sonnet 200k 초과 시 2x |

- ClaudeMeter가 `cache_creation.ephemeral_1h_input_tokens` 서브필드를 읽어 1h/5m을 구분 적용
- ccusage는 `cache_creation_input_tokens`만 읽고 단일 5m 요율 적용
- Opus 모델의 1h 캐시 비율이 높을수록 차이 확대 (예: Opus 4.6 1h cache $10 vs $6.25/MTok)

## Window Resize

- macOS: `MethodChannel('com.claudemeter/window')` → `setWindowSize` handler in AppDelegate.swift
- Windows: `window_manager.setSize()` + `setMinimumSize()` + `setMaximumSize()`
- 모드 전환 시 `resizeWindow()` (`platform_window.dart`) 호출

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
- AppDelegate.swift: NSPanel + NSVisualEffectView + MethodChannel for window resize
- `panel.contentViewController` 사용 금지 — `contentView`를 덮어씀
- Flutter 투명 배경: `DispatchQueue.main.async`로 CAMetalLayer `isOpaque = false` 설정 필요
- 중복 실행 방지: `NSRunningApplication` 체크

### Windows
- `windows/runner/main.cpp`: Named Mutex로 중복 실행 방지
- `platform_window.dart`: `window_manager`로 frameless 윈도우 설정
- `app.dart`: `WindowListener`로 포커스 해제 시 자동 숨김, 트레이 클릭 토글
- 트레이 아이콘: `assets/tray_icon_win.png` (32x32 표준 PNG)
- User-Agent: Windows용 별도 UA 문자열 (`constants.dart`)
