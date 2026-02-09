# Claude Meter for macOS - 작업 로드맵

## 작업 단위 설명

각 작업은 독립적으로 진행 가능하며, 의존성이 있는 경우 명시됨.
`[P]` = 병렬 작업 가능, `[S]` = 순차 작업 필요

---

## Phase 1: 프로젝트 초기화 ✅

### 1.1 [x] Flutter 프로젝트 생성
- [x] `flutter create` 실행
- [x] macOS 플랫폼 활성화
- [x] Git 초기화

### 1.2 [x] 의존성 추가
- [x] pubspec.yaml에 패키지 추가
- [x] `flutter pub get` 실행

---

## Phase 2: 모델 정의 ✅

### 2.1 [x] UsageData 모델
- [x] `lib/models/usage_data.dart`
- [x] UsageTier 클래스
- [x] UsageData 클래스
- [x] JSON 직렬화

### 2.2 [x] Credentials 모델
- [x] `lib/models/credentials.dart`
- [x] Credentials 클래스
- [x] JSON 직렬화
- [x] isExpired() 메서드

### 2.3 [x] Config 모델
- [x] `lib/models/config.dart`
- [x] AppConfig 클래스
- [x] 기본값 정의

---

## Phase 3: 서비스 구현 ✅

### 3.1 [x] PKCE 유틸리티
- [x] `lib/utils/pkce.dart`
- [x] generateVerifier()
- [x] generateChallenge()
- [x] generateState()

### 3.2 [x] 상수 정의
- [x] `lib/utils/constants.dart`
- [x] API URL 상수
- [x] OAuth 파라미터
- [x] 암호화 salt

### 3.3 [x] OAuth 서비스
- [x] `lib/services/oauth_service.dart`
- [x] loadCredentials() — AES-256 복호화 + 레거시 평문 마이그레이션
- [x] saveCredentials() — AES-256-CBC 암호화 + chmod 600
- [x] login() — 로컬 콜백 서버 + 브라우저 OAuth
- [x] _exchangeCode()
- [x] _refreshToken()
- [x] logout()
- [x] _deriveKey() — 머신 고유값 기반 AES 키 생성

### 3.4 [x] 사용량 서비스
- [x] `lib/services/usage_service.dart`
- [x] fetchUsage()
- [x] 에러 핸들링

### 3.5 [x] 설정 서비스
- [x] `lib/services/config_service.dart`
- [x] loadConfig()
- [x] saveConfig()

### 3.6 [x] 트레이 서비스
- [x] `lib/services/tray_service.dart`
- [x] initTray()
- [x] 메뉴 설정
- [x] 클릭 핸들러

---

## Phase 4: UI 위젯 ✅

### 4.1 [x] UsageBar 위젯
- [x] `lib/widgets/usage_bar.dart`
- [x] 프로그레스 바 UI
- [x] 퍼센트 표시
- [x] 리셋 시간 표시
- [x] 색상 그라데이션 (Green → Yellow → Orange → Red)
- [x] 티어별 아이콘 (timer, calendar, auto_awesome)

### 4.2 [x] LoginView 위젯
- [x] `lib/widgets/login_view.dart`
- [x] 로그인 버튼
- [x] 로딩 상태
- [x] 에러 표시

---

## Phase 5: 화면 구현 ✅

### 5.1 [x] 홈 화면
- [x] `lib/screens/home_screen.dart`
- [x] 사용량 표시
- [x] 로그인 상태 분기
- [x] 새로고침 버튼
- [x] 설정 버튼

### 5.2 [x] 설정 화면
- [x] `lib/screens/settings_screen.dart`
- [x] 갱신 주기 설정
- [x] 표시 항목 토글
- [x] 로그아웃 버튼

---

## Phase 6: 앱 통합 ✅

### 6.1 [x] 앱 위젯
- [x] `lib/app.dart`
- [x] MaterialApp 설정
- [x] macOS 네이티브 라이트 테마 (NSVisualEffectView)

### 6.2 [x] 메인 엔트리
- [x] `lib/main.dart`
- [x] 윈도우 설정
- [x] 트레이 초기화
- [x] 자동 갱신 타이머

### 6.3 [x] macOS 설정
- [x] `macos/Runner/AppDelegate.swift` — NSPanel + NSVisualEffectView
- [x] 윈도우 스타일 (Borderless, 둥근 모서리 10px, 투명 배경)
- [x] 팝업 동작

---

## Phase 7: 품질 & 보안 ✅

### 7.1 [x] 테스트
- [x] 모델 테스트 (Credentials, Config, UsageData, PKCE)
- [x] 위젯 테스트 (UsageBar, LoginView, HomeScreen)
- [x] 암호화 테스트 (AES-256 라운드트립, 보안 검증)
- [x] 총 89개 테스트 (8 파일)

### 7.2 [x] 보안 강화
- [x] AES-256-CBC 암호화 자격증명 저장
- [x] 파일 권한 600 (owner read/write only)
- [x] 레거시 평문 자동 마이그레이션
- [x] Per-request HttpClient + badCertificateCallback
- [x] 앱 종료 시 리소스 정리 (타이머 해제, 트레이 리스너 제거)
- [x] 미사용 의존성 제거 (flutter_secure_storage)

### 7.3 [ ] 빌드 & 배포
- [ ] `flutter build macos`
- [ ] 앱 아이콘 설정
- [ ] Info.plist 설정
- [ ] LSUIElement (dock 숨김)

---

## 의존성 그래프

```
Phase 1 (초기화)
    ↓
Phase 2 (모델) + Phase 3 (서비스) ←→ Phase 4 (위젯)   [병렬]
         ↓                              ↓
         └──────────┬──────────────────┘
                    ↓
              Phase 5 (화면)
                    ↓
              Phase 6 (통합)
                    ↓
              Phase 7 (품질 & 보안)
```

---

## 진행 상황

| Phase | 상태 |
|-------|------|
| 1. 초기화 | ✅ 완료 |
| 2. 모델 | ✅ 완료 |
| 3. 서비스 | ✅ 완료 |
| 4. 위젯 | ✅ 완료 |
| 5. 화면 | ✅ 완료 |
| 6. 통합 | ✅ 완료 |
| 7. 품질 & 보안 | 🔄 7.3 빌드 & 배포 남음 |
