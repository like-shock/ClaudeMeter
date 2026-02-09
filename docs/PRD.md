# ClaudeMeter v3.0 PRD — 듀얼 모드 UI

## 개요

ClaudeMeter v3.0은 두 가지 독립된 모드를 제공합니다:

1. **사용량 모니터** (Plan 모드) — OAuth 기반 구독 사용률 모니터링
2. **비용 추적기** (API 모드) — 로컬 JSONL 파싱 기반 API 비용 추적

## 모드 선택

- 첫 실행 시 모드 선택 화면 표시
- 선택한 모드는 `SharedPreferences`에 저장
- 재시작 시 마지막 선택 모드로 바로 진입
- 양쪽 모드에서 "모드 변경" 버튼으로 전환 가능

## Plan 모드 (사용량 모니터)

| 항목 | 값 |
|------|-----|
| 윈도우 크기 | 280 x 400 |
| 인증 | OAuth 2.0 + PKCE |
| 데이터 | `api.anthropic.com/api/oauth/usage` |
| 자동 갱신 | 설정된 간격 (기본 60초) |
| UI | 3-tier 사용률 바 (5시간, 주간, Sonnet) |

### 화면 구성

- **홈 화면**: 사용률 바, 유저 이메일, 구독 타입
- **설정 화면**: 표시 토글, 갱신 간격, 로그아웃
- **트레이 메뉴**: 사용량 보기, 새로고침, 설정, 모드 변경, 종료

## API 모드 (비용 추적기)

| 항목 | 값 |
|------|-----|
| 윈도우 크기 | 400 x 600 |
| 인증 | 불필요 (로컬 파일 파싱) |
| 데이터 | `~/.claude/projects/**/*.jsonl` |
| 자동 갱신 | 설정된 간격 (기본 60초) |
| UI | Current/History 탭 |

### 현재 탭 (Current)

- 기간 요약: 오늘 / 이번 주 / 이번 달 (비용 + 토큰)
- 모델별 사용 요금: 모델명, 비용, 비율%, 프로그레스 바
- 통계: 세션 수, JSONL 파일 수, 마지막 계산 시간

### 기록 탭 (History)

- 월 네비게이터: `<` `>` 버튼으로 월 이동
- 월 요약: 합계, 일 평균, 최대일
- 일별 목록: 날짜, 비용, 토큰 수

### 트레이 메뉴

- 비용 보기, 새로고침, 모드 변경, 종료

## 윈도우 리사이즈

- macOS: `MethodChannel('com.claudemeter/window')` → `setWindowSize` → NSPanel 리사이즈
- Windows: `window_manager.setSize()` + `setMinimumSize()` + `setMaximumSize()`
- 모드 전환 시 자동 리사이즈

## 플랫폼 지원

- macOS: NSPanel + NSVisualEffectView, 앱 샌드박스
- Windows: window_manager, tray_manager, WindowListener

## 데이터 모델

### AppMode enum
```dart
enum AppMode { plan, api }
```

### AppConfig
```dart
AppConfig.appMode: AppMode? // null = 미선택 (첫 실행)
```

### DailyCost
```dart
DailyCost.totalTokens: int // 일별 전체 토큰 합계
```
