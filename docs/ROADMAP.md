# Claude Meter v2.0 - Windows 플랫폼 추가 로드맵

> v1.0 macOS 완료 버전: [docs/archive/ROADMAP_v1.0_macos.md](archive/ROADMAP_v1.0_macos.md)

---

## v1.0 macOS (완료)

| Phase | 상태 |
|-------|------|
| 1. 프로젝트 초기화 | ✅ 완료 |
| 2. 모델 정의 | ✅ 완료 |
| 3. 서비스 구현 | ✅ 완료 |
| 4. UI 위젯 | ✅ 완료 |
| 5. 화면 구현 | ✅ 완료 |
| 6. 앱 통합 | ✅ 완료 |
| 7. 품질 & 보안 | ✅ 완료 (89개 테스트) |

---

## v2.0 Windows 플랫폼 추가

### Phase 0: 문서 정리 ✅
- [x] 기존 ROADMAP/PRD → `docs/archive/` 아카이브
- [x] v2.0 로드맵 생성

### Phase 1: Windows 프로젝트 스캐폴드 ✅
- [x] `flutter create --platforms=windows .` 실행
- [x] `windows/runner/main.cpp`에 중복 실행 방지 Mutex 추가
- [x] `pubspec.yaml` description 변경, 에셋 추가

### Phase 2: Critical Dart 코드 수정 (3개 블로커) ✅
- [x] `oauth_service.dart` — 자격증명 경로 `USERPROFILE` 폴백
- [x] `oauth_service.dart` — chmod FFI 호출 `Platform.isWindows` 가드
- [x] `constants.dart` — User-Agent 플랫폼 분기

### Phase 3: 트레이 아이콘 & 윈도우 관리 ✅
- [x] `tray_service.dart` — 플랫폼별 트레이 아이콘
- [x] `assets/tray_icon_win.png` — Windows 트레이 아이콘 (32x32)
- [x] `lib/utils/platform_window.dart` — Windows 윈도우 설정
- [x] `main.dart` — Windows 윈도우 초기화 호출
- [x] `app.dart` — WindowListener, 윈도우 토글/포지셔닝

### Phase 4: 배경 효과 ✅
- [x] Windows용 반투명 솔리드 배경 적용 (macOS NSVisualEffectView 대응)

### Phase 5: 빌드 & 테스트 ✅
- [x] `scripts/build_release_win.ps1` — Windows 빌드 스크립트
- [x] 기존 89개 테스트 통과 확인
- [x] `CLAUDE.md` Windows 빌드/실행 명령 추가

---

## 수정 파일 요약

| 파일 | 변경 내용 |
|------|----------|
| `lib/services/oauth_service.dart` | 경로 USERPROFILE 폴백, chmod 플랫폼 가드 |
| `lib/utils/constants.dart` | userAgent 플랫폼 분기 |
| `lib/services/tray_service.dart` | 트레이 아이콘 플랫폼 분기 |
| `lib/main.dart` | Windows 윈도우 설정 호출 |
| `lib/app.dart` | WindowListener, 윈도우 토글/포지셔닝 |
| `lib/utils/platform_window.dart` | (신규) Windows 윈도우 설정 유틸 |
| `pubspec.yaml` | description, 에셋 추가 |
| `windows/runner/main.cpp` | 중복 실행 방지 Mutex |
| `assets/tray_icon_win.png` | (신규) Windows 트레이 아이콘 |
| `scripts/build_release_win.ps1` | (신규) Windows 빌드 스크립트 |
| `CLAUDE.md` | Windows 빌드 명령, 플랫폼 차이 문서화 |
