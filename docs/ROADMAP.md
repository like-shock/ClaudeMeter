# ClaudeMeter v3.0 Roadmap

## v3.0 — 듀얼 모드 UI (현재)

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
- [x] 문서 아카이브 및 v3.0 PRD/ROADMAP 작성

## v3.1 — 개선 예정

- [ ] API 모드: 프로젝트별 비용 분류
- [ ] API 모드: 비용 예산 설정 및 알림
- [ ] API 모드: CSV/JSON 내보내기
- [ ] Plan 모드: 사용률 기반 알림 (임계치 초과 시)
- [ ] 양쪽 모드 동시 지원 (탭 전환)
- [ ] 다크 모드 지원

## v4.0 — 향후 계획

- [ ] 멀티 계정 지원
- [ ] 클라우드 동기화 (선택적)
- [ ] 차트/그래프 시각화 (일별/주별 추세)
