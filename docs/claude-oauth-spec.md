# Claude OAuth 2.0 + PKCE 인증 스펙 분석

> 출처: [ClaudeMonitor/api_client.py](https://github.com/whiterub/ClaudeMonitor/blob/main/api_client.py) 분석 기반
> 분석일: 2026-02-07

---

## 1. 엔드포인트

| 용도 | URL | Method |
|------|-----|--------|
| 인가(Authorization) | `https://claude.ai/oauth/authorize` | GET (브라우저) |
| 토큰 교환/갱신 | `https://console.anthropic.com/v1/oauth/token` | POST |
| 사용량 조회 | `https://api.anthropic.com/api/oauth/usage` | GET |
| 프로필 조회 | `https://api.anthropic.com/api/oauth/profile` | GET |

## 2. OAuth 클라이언트 설정

```
Client ID:  9d1c250a-e61b-44d9-88ed-5944d1962f5e  (public client, secret 없음)
Scopes:     user:profile  (최소 권한 — 프로필 접근만 요청)
User-Agent: claude-code/2.0.32
```

## 3. 인증 플로우 (Authorization Code + PKCE)

### 3.1 PKCE 파라미터 생성

```
code_verifier  = base64url(os.urandom(32))           # 패딩('=') 제거
code_challenge = base64url(SHA256(code_verifier))     # 패딩('=') 제거
state          = secrets.token_urlsafe(32)            # CSRF 방지용
```

- verifier: 32바이트 랜덤 → base64url 인코딩 → 패딩 제거
- challenge: verifier를 SHA256 해시 → base64url 인코딩 → 패딩 제거
- state: 별도의 CSRF 보호 토큰 (verifier와 독립)

### 3.2 로컬 콜백 서버 시작

```
서버: 127.0.0.1 (IPv4 loopback)
포트: 0 (OS가 랜덤 할당)
경로: /callback
redirect_uri = http://localhost:{port}/callback
```

- `/callback` 외 경로(favicon 등)는 204 반환 후 무시
- 서버 로그 출력 억제 (`log_message` 오버라이드)

### 3.3 브라우저 인가 요청

**URL**: `https://claude.ai/oauth/authorize?{params}`

| 파라미터 | 값 |
|----------|-----|
| `client_id` | `9d1c250a-...` |
| `response_type` | `code` |
| `redirect_uri` | `http://localhost:{port}/callback` |
| `scope` | `user:profile` |
| `code_challenge` | PKCE challenge 값 |
| `code_challenge_method` | `S256` |
| `state` | CSRF 토큰 |

### 3.4 콜백 처리

브라우저가 `http://localhost:{port}/callback?code=XXX&state=YYY`로 리다이렉트.

**Python 레퍼런스 동작**:
- `/callback` 경로만 처리
- `code` 파라미터 추출
- **state 검증 없음** (code만 추출)
- 성공 HTML 페이지 반환 (200)
- 타임아웃: 120초 (handle_request 루프)

### 3.5 토큰 교환 (Authorization Code → Access Token)

**POST** `https://console.anthropic.com/v1/oauth/token`

**Headers**:
```
Content-Type: application/json
User-Agent: claude-code/2.0.32
```

**Body** (JSON):
```json
{
  "code": "{authorization_code}",
  "state": "{state}",
  "grant_type": "authorization_code",
  "client_id": "9d1c250a-...",
  "redirect_uri": "http://localhost:{port}/callback",
  "code_verifier": "{verifier}"
}
```

> **주의**: `state`가 토큰 교환 body에도 포함됨 (표준 OAuth 2.0에서는 불필요하나, Anthropic 서버가 요구하는 것으로 보임)

**응답** (JSON):
```json
{
  "access_token": "...",
  "refresh_token": "...",
  "expires_in": 28800
}
```

- `expires_in`: 기본 28800초 (8시간), 없으면 28800 사용
- `refresh_token`: 응답에 없으면 기존 값 유지

### 3.6 토큰 갱신 (Refresh)

**POST** `https://console.anthropic.com/v1/oauth/token`

**Headers**:
```
Content-Type: application/json
User-Agent: claude-code/2.0.32
```

**Body** (JSON):
```json
{
  "grant_type": "refresh_token",
  "client_id": "9d1c250a-...",
  "refresh_token": "{refresh_token}"
}
```

- 만료 1분 전 자동 갱신 (`time.time() >= expires_at - 60`)
- 갱신 시 `refresh_token`이 응답에 있으면 교체, 없으면 기존 유지

## 4. API 호출

### 4.1 사용량 조회

**GET** `https://api.anthropic.com/api/oauth/usage`

**Headers**:
```
Authorization: Bearer {access_token}
anthropic-beta: oauth-2025-04-20
```

**응답 구조**:
```json
{
  "five_hour": {
    "utilization": 0.42,
    "resets_at": "2026-02-07T15:00:00Z"
  },
  "seven_day": {
    "utilization": 0.15,
    "resets_at": "2026-02-10T00:00:00Z"
  },
  "seven_day_sonnet": {
    "utilization": 0.08,
    "resets_at": "2026-02-10T00:00:00Z"
  }
}
```

- `utilization`: 0.0~1.0 (사용률)
- `resets_at`: ISO 8601 형식 (없을 수 있음)
- 401 응답 시: 토큰 갱신 후 1회 재시도

### 4.2 프로필 조회

**GET** `https://api.anthropic.com/api/oauth/profile`

**Headers**:
```
Authorization: Bearer {access_token}
User-Agent: claude-code/2.0.32
anthropic-beta: oauth-2025-04-20
```

## 5. 크리덴셜 저장

**경로**: `~/.claude/.credentials.json`

**구조**:
```json
{
  "claudeAiOauth": {
    "accessToken": "...",
    "refreshToken": "...",
    "expiresAt": 1738900000000,
    "scopes": [],
    "subscriptionType": "",
    "rateLimitTier": ""
  }
}
```

- `expiresAt`: Unix 밀리초 (Python에서는 내부적으로 초 단위 사용, 저장 시 ×1000)
- 기존 파일의 다른 키 보존 (`claudeAiOauth`만 갱신)
- `scopes`, `subscriptionType`, `rateLimitTier`: 기존 값 보존 (없으면 빈 값)

## 6. 에러 처리 패턴

| 상황 | 처리 |
|------|------|
| 콜백 타임아웃 (120초) | `on_complete(False, "인증 시간 초과 또는 취소됨")` |
| 토큰 교환 HTTP 에러 | 응답 body 앞 200자 포함하여 에러 반환 |
| 사용량 조회 401 | 토큰 갱신 → 1회 재시도 |
| 네트워크 에러 | `"network_error"` 반환 |
| 갱신 실패 | `"token_refresh_failed"` 반환 |

---

## 7. Flutter 앱 vs Python 레퍼런스 차이점 비교

### 7.1 동일한 부분 (정상)

| 항목 | 상태 |
|------|------|
| 엔드포인트 URL (4개) | 동일 |
| Client ID | 동일 |
| OAuth Scopes | 동일 |
| PKCE 생성 로직 (verifier/challenge/state) | 동일 |
| 인가 URL 파라미터 | 동일 |
| 토큰 교환 body 파라미터 (state 포함) | 동일 |
| 토큰 갱신 body 파라미터 | 동일 |
| 콜백 서버 (127.0.0.1, 랜덤 포트) | 동일 |
| User-Agent (`claude-code/2.0.32`) | 동일 |
| 만료 버퍼 (1분) | 동일 |
| 기본 expires_in (28800) | 동일 |

### 7.2 차이점 (잠재적 문제)

| 항목 | Python (레퍼런스) | Flutter (현재 앱) | 영향도 |
|------|-------------------|-------------------|--------|
| **콜백 state 검증** | 검증 안함 (code만 추출) | state 불일치 시 에러 | **높음** - state 인코딩 차이로 불일치 가능 |
| **크리덴셜 저장** | 파일 (`~/.claude/.credentials.json`) | 파일 (동일 경로) | 낮음 - 호환 |
| **저장 시 추가 필드** | `scopes`, `subscriptionType`, `rateLimitTier` 보존 | `accessToken`, `refreshToken`, `expiresAt`만 저장 | 낮음 - 인증에 무관 |
| **콜백 서버 루프** | `handle_request()` 루프 (여러 요청 처리) | `server.listen()` 스트림 | 낮음 - 동작 동일 |
| **에러 상세 전파** | HTTP 에러 body 표시 | `login()` → `false` 반환, 상세 에러 손실 | **중간** - 디버깅 어려움 |
| **스레딩** | 별도 thread | async/await | 낮음 - Dart 모델에 적합 |

### 7.3 핵심 의심 포인트

**1. 콜백 state 검증 문제 (가장 유력)**

Flutter 앱 (`oauth_service.dart:219`):
```dart
} else if (returnedState != state) {
    _sendErrorPage(request.response, 'CSRF 검증 실패');
}
```

Python 레퍼런스는 state를 검증하지 않음. 만약 Anthropic 서버가 리다이렉트할 때 state를 URL-인코딩하여 반환하면, Flutter에서 디코딩된 값과 원본이 불일치할 수 있음.

**2. 에러 전파 누락**

`login()` 메서드가 모든 예외를 catch하고 `false`만 반환하므로, 실제 실패 원인(state 불일치, 토큰 교환 HTTP 에러 등)을 사용자가 알 수 없음.

**3. state 생성 방식 차이**

| | Python | Flutter |
|---|--------|---------|
| 생성 | `secrets.token_urlsafe(32)` | `base64UrlEncode(Random.secure 32bytes)` + 패딩 제거 |
| 형식 | URL-safe base64 (43자) | URL-safe base64 (43자) |

두 방식 모두 URL-safe base64를 생성하지만, `secrets.token_urlsafe`는 Python의 `base64.urlsafe_b64encode`를 내부적으로 사용하므로 인코딩 결과는 동일한 형식. 단, Flutter의 `base64UrlEncode`가 `+`/`=` 문자를 URL 파라미터에서 인코딩/디코딩하는 과정에서 변조될 가능성 존재.

---

## 8. 권장 수정사항

### 즉시 적용 (인증 실패 해결)

1. **에러 상세 로깅 강화**: `login()` 실패 시 실제 에러 메시지를 UI까지 전파
2. **콜백 state 검증을 선택적으로 완화**: Python처럼 state 검증 제거하거나, URL 디코딩 후 비교
3. **디버그 모드에서 전체 에러 출력**: 토큰 교환 실패 시 응답 body 확인

### 추가 개선

4. **저장 시 추가 필드 보존**: `scopes`, `subscriptionType`, `rateLimitTier` 유지하여 호환성 확보
5. **401 재시도 로직**: 사용량 조회 시 401 발생하면 토큰 갱신 후 1회 재시도 (Python과 동일)
6. **User-Agent 업데이트 고려**: 현재 claude-code 최신 버전(2.1.34) 반영 여부 검토
