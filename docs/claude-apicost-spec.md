# Claude API 비용 계산 사양

## 데이터 소스

- 경로: `~/.claude/projects/**/*.jsonl`
- 형식: 라인별 JSON (JSONL)
- 서브에이전트 파일 포함 (재귀 탐색)

## JSONL 구조 (assistant 메시지)

```json
{
  "type": "assistant",
  "sessionId": "uuid",
  "timestamp": "2026-02-09T10:00:00.000Z",
  "message": {
    "model": "claude-opus-4-6-20260101",
    "role": "assistant",
    "usage": {
      "input_tokens": 500,
      "cache_creation_input_tokens": 1000,
      "cache_read_input_tokens": 200,
      "output_tokens": 100,
      "cache_creation": {
        "ephemeral_5m_input_tokens": 300,
        "ephemeral_1h_input_tokens": 700
      }
    }
  }
}
```

## 파싱 규칙

1. `type == "assistant"` 라인만 처리
2. `message.usage` 필드 필수
3. `message.model` 필드 필수 (빈 문자열 제외)
4. 타임스탬프: ISO 8601 형식, 일별 집계에 사용

## 토큰 종류

| 필드 | 설명 |
|------|------|
| `input_tokens` | 일반 입력 토큰 |
| `cache_creation_input_tokens` | 캐시 생성 토큰 (레거시 합계) |
| `cache_creation.ephemeral_5m_input_tokens` | 5분 캐시 생성 |
| `cache_creation.ephemeral_1h_input_tokens` | 1시간 캐시 생성 |
| `cache_read_input_tokens` | 캐시 읽기 토큰 |
| `output_tokens` | 출력 토큰 |

## 가격표 (2026-02 기준, USD/MTok)

| 모델 | Input | Cache 5m Write | Cache 1h Write | Cache Read | Output |
|------|-------|----------------|----------------|------------|--------|
| Opus 4.6 / 4.5 | $5 | $6.25 | $10 | $0.50 | $25 |
| Opus 4.1 / 4 | $15 | $18.75 | $30 | $1.50 | $75 |
| Sonnet 4.5 / 4 | $3 | $3.75 | $6 | $0.30 | $15 |
| Haiku 4.5 | $1 | $1.25 | $2 | $0.10 | $5 |
| Haiku 3.5 | $0.80 | $1 | $1.60 | $0.08 | $4 |

## 비용 공식

```
cost = Σ(tokens × rate) / 1,000,000
```

토큰 타입별:
```
cost = (input_tokens × input_rate
      + cache_5m_tokens × cache_5m_write_rate
      + cache_1h_tokens × cache_1h_write_rate
      + cache_read_tokens × cache_read_rate
      + output_tokens × output_rate) / 1,000,000
```

### 캐시 생성 토큰 결정 로직

- `ephemeral_5m_input_tokens` 또는 `ephemeral_1h_input_tokens` > 0 → 해당 값 사용
- 둘 다 0 → `cache_creation_input_tokens` 전체를 5분 캐시로 간주 (보수적 기본값)

## 모델 ID 매칭

JSONL의 모델 문자열에는 날짜 접미사가 포함될 수 있음:
- `claude-opus-4-6-20260101` → `Opus 4.6`
- `claude-sonnet-4-5-20250929` → `Sonnet 4.5`

매칭 순서:
1. 정확 일치
2. 접두어 일치 (날짜 접미사 제거)

## 집계

- **모델별**: 전체 기간 모델별 토큰/비용 누적
- **일별**: 날짜 키(`YYYY-MM-DD`)로 비용, 메시지 수, 전체 토큰 수 누적
- **오늘**: 오늘 날짜 키의 비용
- **전체**: 모든 모델 비용 합산

## 예시

Opus 4.6으로 input 1000, cache_read 500, output 200 토큰 사용:
```
cost = (1000 × 5 + 500 × 0.50 + 200 × 25) / 1,000,000
     = (5000 + 250 + 5000) / 1,000,000
     = $0.01025
```
