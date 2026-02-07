# Claude Monitor for macOS - 작업 로드맵

## 작업 단위 설명

각 작업은 독립적으로 진행 가능하며, 의존성이 있는 경우 명시됨.
`[P]` = 병렬 작업 가능, `[S]` = 순차 작업 필요

---

## Phase 1: 프로젝트 초기화

### 1.1 [x] Flutter 프로젝트 생성
- [x] `flutter create` 실행
- [x] macOS 플랫폼 활성화
- [x] Git 초기화

### 1.2 [ ] 의존성 추가
- [ ] pubspec.yaml에 패키지 추가
- [ ] `flutter pub get` 실행

---

## Phase 2: 모델 정의 (병렬 작업 가능)

### 2.1 [P] UsageData 모델
- [ ] `lib/models/usage_data.dart`
- [ ] UsageTier 클래스
- [ ] UsageData 클래스
- [ ] JSON 직렬화

### 2.2 [P] Credentials 모델
- [ ] `lib/models/credentials.dart`
- [ ] Credentials 클래스
- [ ] JSON 직렬화
- [ ] isExpired() 메서드

### 2.3 [P] Config 모델
- [ ] `lib/models/config.dart`
- [ ] AppConfig 클래스
- [ ] 기본값 정의

---

## Phase 3: 서비스 구현 (병렬 작업 가능)

### 3.1 [P] PKCE 유틸리티
- [ ] `lib/utils/pkce.dart`
- [ ] generateVerifier()
- [ ] generateChallenge()
- [ ] generateState()

### 3.2 [P] 상수 정의
- [ ] `lib/utils/constants.dart`
- [ ] API URL 상수
- [ ] OAuth 파라미터

### 3.3 [S → 2.2, 3.1] OAuth 서비스
- [ ] `lib/services/oauth_service.dart`
- [ ] loadCredentials()
- [ ] saveCredentials()
- [ ] startLogin() - 브라우저 OAuth
- [ ] exchangeCode()
- [ ] refreshToken()
- [ ] logout()

### 3.4 [S → 3.3] 사용량 서비스
- [ ] `lib/services/usage_service.dart`
- [ ] fetchUsage()
- [ ] 에러 핸들링

### 3.5 [P] 설정 서비스
- [ ] `lib/services/config_service.dart`
- [ ] loadConfig()
- [ ] saveConfig()

### 3.6 [P] 트레이 서비스
- [ ] `lib/services/tray_service.dart`
- [ ] initTray()
- [ ] 메뉴 설정
- [ ] 클릭 핸들러

---

## Phase 4: UI 위젯 (병렬 작업 가능)

### 4.1 [P] UsageBar 위젯
- [ ] `lib/widgets/usage_bar.dart`
- [ ] 프로그레스 바 UI
- [ ] 퍼센트 표시
- [ ] 리셋 시간 표시
- [ ] 색상 그라데이션

### 4.2 [P] LoginView 위젯
- [ ] `lib/widgets/login_view.dart`
- [ ] 로그인 버튼
- [ ] 로딩 상태
- [ ] 에러 표시

---

## Phase 5: 화면 구현

### 5.1 [S → 4.1, 4.2] 홈 화면
- [ ] `lib/screens/home_screen.dart`
- [ ] 사용량 표시
- [ ] 로그인 상태 분기
- [ ] 새로고침 버튼
- [ ] 설정 버튼

### 5.2 [P] 설정 화면
- [ ] `lib/screens/settings_screen.dart`
- [ ] 갱신 주기 설정
- [ ] 표시 항목 토글
- [ ] 로그아웃 버튼

---

## Phase 6: 앱 통합

### 6.1 [S → 5.1, 5.2] 앱 위젯
- [ ] `lib/app.dart`
- [ ] MaterialApp 설정
- [ ] 다크 테마

### 6.2 [S → 6.1, 3.6] 메인 엔트리
- [ ] `lib/main.dart`
- [ ] 윈도우 설정
- [ ] 트레이 초기화
- [ ] 자동 갱신 타이머

### 6.3 [S → 6.2] macOS 설정
- [ ] `macos/Runner/MainFlutterWindow.swift`
- [ ] 윈도우 스타일 (투명, 프레임리스)
- [ ] 팝업 동작

---

## Phase 7: 빌드 & 배포

### 7.1 [S → 6.3] macOS 빌드
- [ ] `flutter build macos`
- [ ] 앱 아이콘 설정
- [ ] Info.plist 설정
- [ ] LSUIElement (dock 숨김)

### 7.2 [P] 문서화
- [ ] README.md 작성
- [ ] 스크린샷 추가
- [ ] 설치 가이드

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
              Phase 7 (빌드)
```

---

## 예상 소요 시간

| Phase | 예상 시간 |
|-------|----------|
| 1. 초기화 | 5분 ✅ |
| 2. 모델 | 15분 |
| 3. 서비스 | 40분 |
| 4. 위젯 | 20분 |
| 5. 화면 | 20분 |
| 6. 통합 | 15분 |
| 7. 빌드 | 10분 |
| **총계** | **~2시간** |

---

## 현재 진행 상황

- [x] Phase 1.1 - Flutter 프로젝트 생성
- [ ] Phase 1.2 - 의존성 추가 ← **현재**
