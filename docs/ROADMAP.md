# ClaudeMeter v2.0 Roadmap

## v2.0 — 듀얼 모드 UI (현재)

### 완료

- [x] `AppMode` enum (plan / api) 추가
- [x] `AppConfig.appMode` 필드 (null = 미선택, plan, api)
- [x] 모드 선택 화면 (`mode_select_screen.dart`)
- [x] API 모드 메인 화면 (`api_home_screen.dart`) — Current/History 탭
- [x] macOS MethodChannel 윈도우 리사이즈
- [x] Windows window_manager 리사이즈
- [x] 앱 라우팅 모드 분기 (`app.dart`)
- [x] 트레이 메뉴 모드별 구성
- [x] `DailyCost.totalTokens` 추가
- [x] `CostTrackingService` 일별 토큰 누적
- [x] HomeScreen에서 `onCost` 제거, 모드 변경 버튼 추가
- [x] `cost_screen.dart` 삭제 (→ `api_home_screen.dart`)
- [x] 테스트 업데이트 (128 tests passing)
- [x] 문서 아카이브 및 v2.0 PRD/ROADMAP 작성

## v2.1 — 개선 예정

- [ ] API 모드: 가격표 자동 업데이트 (매일 00시 웹에서 최신 요금 반영, 실패 시 1시간 간격 재시도)
- [ ] API 모드: 비용 예산 설정 및 알림
- [ ] Plan 모드: 사용률 기반 알림 (임계치 초과 시)
