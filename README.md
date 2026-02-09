# Claude Meter

macOS 시스템 트레이 앱으로 Claude AI API 사용량을 실시간 모니터링합니다.

## 주요 기능

- OAuth 2.0 (PKCE) 인증으로 Claude 계정 연동
- 5시간 / 7일 / 7일 Sonnet 세 가지 티어별 사용량 표시
- 시스템 트레이 상주, 자동 새로고침
- AES-256 암호화 자격증명 저장

## 요구 사항

- macOS 10.15+
- Flutter SDK

## 개발

```bash
flutter pub get
flutter run -d macos
```

## 배포 (사내, 서명 없음)

Apple Developer 계정 없이 배포하는 방법입니다.

### 빌드

```bash
./scripts/build_release.sh
```

`ClaudeMeter-1.0.0.dmg` 파일이 프로젝트 루트에 생성됩니다.

### 배포

DMG 파일을 Slack/Teams/이메일로 공유합니다.

### 설치 안내

서명되지 않은 앱이므로 macOS Gatekeeper가 차단합니다. 사용자에게 아래 안내가 필요합니다.

**방법 A — 터미널 (권장):**

```bash
# DMG에서 앱을 /Applications로 드래그 복사 후:
xattr -cr /Applications/claude_meter.app
```

이후 정상 실행 가능합니다.

**방법 B — GUI:**

1. 앱 실행 시도 → "개발자를 확인할 수 없습니다" 경고
2. 시스템 설정 → 개인정보 및 보안 → 하단 "확인 없이 열기" 클릭
3. 관리자 비밀번호 입력

> macOS Sequoia 15.1+에서는 방법 B가 더 까다로울 수 있으므로 **방법 A(xattr)를 권장**합니다.

## 향후 참고 (Developer ID 전환 시)

나중에 Apple Developer 계정을 등록하면:

1. `DEVELOPMENT_TEAM` 설정 추가
2. `codesign` → `xcrun notarytool submit` → `xcrun stapler staple` 단계 추가
3. Gatekeeper 우회 없이 바로 실행 가능
