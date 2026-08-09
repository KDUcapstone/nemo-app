# NEMO 프로젝트 문서

이 디렉터리는 구현 사실, 검증 결과, 포트폴리오 표현을 같은 근거에서 관리하기 위한 문서 허브입니다.

## 문서 상태

| 상태 | 의미 |
|---|---|
| `Draft` | 설계 또는 구현이 진행 중이며 검증 전 |
| `Verified` | 기록된 명령과 실행 결과로 현재 저장소에서 확인됨 |
| `Historical` | 과거 의사결정 기록이며 현재 구현과 다를 수 있음 |

## 문서 구조

```text
docs/project/
├─ README.md
├─ templates/
│  └─ technical-change-record.md
└─ case-studies/
   └─ 2026-08-02-supabase-postgresql-runtime-hardening.md
```

## 사례 문서

| 날짜 | 상태 | 주제 | 핵심 근거 |
|---|---|---|---|
| 2026-08-02 | Verified | [Supabase PostgreSQL 전환 후 런타임 하드닝](case-studies/2026-08-02-supabase-postgresql-runtime-hardening.md) | 자동 테스트, prod 기동, read-only HTTP smoke |

## 설계·실행 문서

- [런타임 하드닝 설계](../superpowers/specs/2026-08-02-runtime-hardening-and-evidence-documentation-design.md)
- [런타임 하드닝 구현 계획](../superpowers/plans/2026-08-02-runtime-hardening-and-evidence-documentation.md)
- [기존 Supabase PostgreSQL 전환 설계](../superpowers/specs/2026-07-28-supabase-postgresql-migration-design.md) — Historical
- [기존 Supabase PostgreSQL 전환 계획](../superpowers/plans/2026-07-28-supabase-postgresql-migration.md) — Historical

## 작성 원칙

1. 구현 완료, 실행 확인, 추정 또는 계획을 구분한다.
2. 검증 명령과 관찰 결과를 함께 남긴다.
3. 팀 기여와 개인 기여를 분리한다.
4. 비밀값, 개인 데이터, 운영 데이터는 기록하지 않는다.
5. 성능 수치는 실제 측정 조건과 결과가 있을 때만 사용한다.

새 기술 변경은 [기술 변경 기록 템플릿](templates/technical-change-record.md)을 복사해 작성합니다.
