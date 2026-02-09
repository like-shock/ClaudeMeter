# Claude Monitor for macOS - PRD (Product Requirements Document)

## 1. 개요

### 1.1 프로젝트명
**Claude Monitor for macOS** (Flutter Edition)

### 1.2 목표
Claude AI 사용량을 macOS 메뉴바에서 실시간으로 모니터링할 수 있는 네이티브 경험 제공
([ClaudeMonitor](https://github.com/whiterub/ClaudeMonitor))

### 1.3 기술 스택
- **Framework**: Flutter 3.x (macOS)
- **Language**: Dart
- **System Tray**: `tray_manager` 패키지
- **Window Management**: `window_manager` 패키지
- **HTTP**: `dart:io` HttpClient (per-request, badCertificateCallback 적용)
- **암호화**: `crypto` (SHA-256) + `encrypt` (AES-256-CBC)

---

## 2. 기능 요구사항

### 2.1 핵심 기능

#### 2.1.1 메뉴바 아이콘
- macOS 상단 메뉴바에 아이콘 표시
- 아이콘 클릭 시 팝업 윈도우로 사용량 표시
- 우클릭 시 컨텍스트 메뉴

#### 2.1.2 사용량 표시
- **5시간 세션 사용량** (five_hour)
- **주간 전체 사용량** (seven_day)
- **Sonnet 주간 사용량** (seven_day_sonnet)
- 프로그레스 바 + 퍼센트 수치
- 리셋 시간 표시

#### 2.1.3 OAuth 인증
- Claude OAuth 2.0 + PKCE 로그인
- 로컬 콜백 서버 (localhost:random_port/callback)
- 토큰 자동 갱신 (refresh_token)
- 자격 증명 파일: `~/.claude/.credentials.json`

#### 2.1.4 설정
- 갱신 주기 (5~300초, 기본 30초)
- 표시 항목 선택 (5시간/주간/Sonnet)
- 로그아웃

### 2.2 UI/UX

#### 2.2.1 팝업 윈도우
- 메뉴바 아이콘 클릭 시 아이콘 아래에 팝업 표시
- macOS 네이티브 라이트 테마 (NSVisualEffectView, .menu material)
- Borderless NSPanel (280x400), 둥근 모서리 10px
- 각 사용량 항목별 색상 프로그레스 바 + 티어별 아이콘
- 새로고침 버튼
- 설정 버튼 (기어 아이콘)
- 닫기: 팝업 외부 클릭 시 자동 숨기기

#### 2.2.2 메뉴바 컨텍스트 메뉴 (우클릭)
- 새로고침
- 설정
- 로그아웃
- 종료

---

## 3. 기술 사양

### 3.1 API 엔드포인트

| 용도 | URL |
|------|-----|
| 토큰 발급/갱신 | `https://console.anthropic.com/v1/oauth/token` |
| 사용량 조회 | `https://api.anthropic.com/api/oauth/usage` |
| 인증 시작 | `https://claude.ai/oauth/authorize` |
| 프로필 조회 | `https://api.anthropic.com/api/oauth/profile` |

### 3.2 OAuth 파라미터
- **Client ID**: `9d1c250a-e61b-44d9-88ed-5944d1962f5e`
- **Scopes**: `org:create_api_key user:profile user:inference`
- **Grant Type**: `authorization_code`, `refresh_token`
- **PKCE**: S256 code_challenge

### 3.3 사용량 응답 형식
```json
{
  "five_hour": {
    "utilization": 0.45,
    "resets_at": "2026-02-07T10:00:00Z"
  },
  "seven_day": {
    "utilization": 0.32,
    "resets_at": "2026-02-10T00:00:00Z"
  },
  "seven_day_sonnet": {
    "utilization": 0.15,
    "resets_at": "2026-02-10T00:00:00Z"
  }
}
```

### 3.4 자격 증명 저장
- 경로: `~/.claude/.credentials.json` (권한 600)
- 키: `claudeAiOauth`
- **암호화**: AES-256-CBC (매 저장 시 랜덤 IV)
- **키 유도**: `SHA-256(hostname + ":" + username + ":" + salt)` → 32바이트 AES 키
- 저장 포맷: `{ "claudeAiOauth": { "iv": "base64...", "data": "AES-256-CBC encrypted base64..." } }`
- 레거시 평문 포맷(`accessToken`, `refreshToken`, `expiresAt`) 자동 감지 → 암호화 마이그레이션

---

## 4. 프로젝트 구조

```
claude_monitor_flutter/
├── lib/
│   ├── main.dart               # 앱 엔트리포인트
│   ├── app.dart                # 앱 위젯
│   ├── models/
│   │   ├── usage_data.dart     # 사용량 데이터 모델
│   │   ├── credentials.dart    # 자격 증명 모델
│   │   └── config.dart         # 설정 모델
│   ├── services/
│   │   ├── oauth_service.dart  # OAuth 인증, AES-256 암호화 저장
│   │   ├── usage_service.dart  # 사용량 API
│   │   ├── config_service.dart # 설정 관리
│   │   └── tray_service.dart   # 시스템 트레이
│   ├── screens/
│   │   ├── home_screen.dart    # 메인 화면
│   │   └── settings_screen.dart# 설정 화면
│   ├── widgets/
│   │   ├── usage_bar.dart      # 프로그레스 바
│   │   └── login_view.dart     # 로그인 화면
│   └── utils/
│       ├── pkce.dart           # PKCE 헬퍼
│       └── constants.dart      # 상수, 암호화 salt
├── macos/
│   └── Runner/
│       └── MainFlutterWindow.swift
├── pubspec.yaml
└── docs/
    ├── PRD.md
    └── ROADMAP.md
```

---

## 5. 의존성 패키지

```yaml
dependencies:
  flutter:
    sdk: flutter
  tray_manager: ^0.2.3          # 메뉴바 아이콘
  window_manager: ^0.4.3        # 윈도우 제어
  url_launcher: ^6.3.1          # OAuth 브라우저 열기
  shared_preferences: ^2.3.3    # 설정 저장
  path_provider: ^2.1.5         # 파일 경로
  crypto: ^3.0.6                # PKCE SHA256 + 암호화 키 유도
  encrypt: ^5.0.3               # AES-256-CBC 자격증명 암호화
```

---

## 6. 비기능 요구사항

### 6.1 성능
- 앱 시작 시간: < 1초
- 메모리 사용량: < 100MB
- API 호출 타임아웃: 15초

### 6.2 호환성
- macOS 11+ (Big Sur 이상)
- Apple Silicon (ARM64) + Intel (x86_64)

### 6.3 보안
- OAuth 토큰은 AES-256-CBC 암호화 후 로컬 파일에 저장 (권한 600)
- 머신 고유값(hostname + username) 기반 키 유도 (사용자 입력 불필요)
- PKCE로 인증 코드 보호
- HTTPS 통신만 사용
- Per-request HttpClient + badCertificateCallback 거부
- 레거시 평문 자격증명 자동 암호화 마이그레이션

---

## 7. 향후 확장 (Phase 2)

- 알림: 사용량 임계치 도달 시 macOS 알림
- 히스토리: 사용량 추이 그래프
- 다크/라이트 테마 자동 전환
