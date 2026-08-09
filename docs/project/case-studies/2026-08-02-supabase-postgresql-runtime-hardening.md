---
title: Supabase PostgreSQL 전환 후 런타임 하드닝
status: Verified
date: 2026-08-02
owner: PM + 백엔드 공동 담당
related_issues: []
---

# Supabase PostgreSQL 전환 후 런타임 하드닝

## 1. 요약

Supabase PostgreSQL로 DB 연결을 바꾼 뒤 애플리케이션이 단순히 기동되는 수준을 넘어, 프로필별 설정·공개 엔드포인트·Flutter 실제 API 연결 기본값을 정리하고 자동 테스트와 운영 프로필 smoke test로 검증했다.

- 변경 전 핵심 위험: 기본 프로필이 `prod`, 공통 설정에 H2와 고정 비밀값 존재, DB health가 MariaDB 문자열 응답, Flutter가 Mock API를 기본 사용
- 변경 후 핵심 상태: 기본 `dev`, 운영 PostgreSQL 전용 설정, 구조화된 DB health, 운영 H2·Swagger 비활성, Flutter 실제 API 기본값
- 데이터 영향: read-only 쿼리(`SELECT 1`)만 실행했으며 운영 데이터 생성·수정·삭제는 하지 않음

## 2. 문제와 목표

DB 접속 성공만으로는 운영 준비를 주장할 수 없다. 실행 프로필의 책임이 섞여 있으면 테스트 환경과 운영 환경의 동작이 달라질 수 있고, Flutter가 Mock API를 기본 사용하면 화면 테스트가 실제 연동 상태를 증명하지 못한다.

이번 변경의 목표는 다음과 같았다.

1. 공통·개발·로컬 PostgreSQL·운영 PostgreSQL 설정의 책임을 분리한다.
2. DB 상태를 기계가 해석할 수 있는 JSON과 적절한 HTTP 상태로 반환한다.
3. 운영 환경의 개발용 표면(H2, Swagger, 과도한 Actuator)을 닫는다.
4. Flutter가 실제 API를 기본 사용하고 Mock은 명시적으로만 활성화한다.
5. 포트폴리오 문장을 실제 검증 근거와 연결한다.

## 3. 범위

### 포함

- Spring 프로필과 환경변수 계약 정리
- PostgreSQL DB health 응답 및 장애 시 정보 노출 방지
- 운영 H2·Swagger 비활성화, Actuator health/info만 노출
- 존재하지 않는 리소스가 전역 예외 처리기로 인해 `500`이 되던 문제 수정
- Flutter `USE_MOCK_API`, `API_BASE_URL` dart define 적용
- 임시 로그인 우회 버튼 제거, Android debug 전용 cleartext 허용
- 자동 테스트 및 운영 프로필 read-only smoke test

### 제외

- 소셜 로그인 버튼의 실제 OAuth 구현
- 운영 데이터가 필요한 인증 후 CRUD 전체 시나리오
- 배포 파이프라인과 운영 도메인 HTTPS 검증
- Flutter analyzer 기존 이슈 전체 정리
- 성능·부하 테스트와 개선 수치 산출

## 4. 주요 의사결정

| 결정 | 이유 | 대안과 경계 |
|---|---|---|
| 기본 프로필을 `dev`로 지정 | 환경변수 없이 개발·테스트 가능 | `prod` 기본값은 비밀값 누락과 운영 DB 오접속 위험이 큼 |
| 운영은 `ddl-auto=validate` 유지 | 애플리케이션 기동 시 스키마 계약만 검증 | 자동 스키마 변경은 운영 데이터에 영향을 줄 수 있어 제외 |
| health 응답을 JSON으로 반환 | 모니터링과 테스트가 상태를 안정적으로 판별 | 예외 메시지는 DB 정보 유출 가능성이 있어 반환하지 않음 |
| Mock API 기본값을 `false`로 변경 | 실제 연동 여부를 화면 실행과 일치 | Mock은 `USE_MOCK_API=true`일 때만 명시적으로 사용 |
| 평문 HTTP는 Android debug에서만 허용 | 로컬 개발 편의와 배포 보안 경계 분리 | 배포 환경은 HTTPS 전제 |

## 5. 구현 내역

| 영역 | 변경 | 결과 |
|---|---|---|
| Spring 설정 | `application.yml`, `application-local.yml`, `application-prod.yml` 책임 분리 | 공통 설정에서 DB·비밀값 제거, 환경별 계약 명확화 |
| DB health | `DbHealthController` 구조화 | 성공 `200/UP`, 실패 `503/DOWN`, 예외 문자열 비노출 |
| Security | Actuator matcher 축소 | 익명 공개는 health/info만 허용 |
| 예외 처리 | `NoResourceFoundException` 전용 처리 | 비활성·미존재 리소스가 `500` 대신 `404` 반환 |
| Flutter 런타임 | dart define 적용 | 실제 API 기본, Mock과 API 주소를 실행 시점에 선택 |
| Flutter 로그인 | 임시 진입 버튼 제거 | 인증 우회 진입 경로 제거 |
| Android | debug manifest 분리 | debug에서만 로컬 HTTP 허용 |

## 6. TDD 및 자동 검증

### RED에서 확인한 실패

- 기본 프로필이 `prod`였음
- local 설정에 DB·JWT 고정값이 남아 있었음
- prod의 H2·Swagger·Actuator 제한 계약이 없었음
- DB health가 문자열을 반환하고 장애 상태 계약이 없었음
- Flutter Mock API 기본값이 `true`였음
- 로그인 화면에 임시 우회 버튼이 노출됐음
- 미존재 정적 리소스가 전역 범용 예외 처리기에 의해 `500`으로 변환됐음

### GREEN 결과

| 구분 | 명령 | 결과 |
|---|---|---|
| Backend 핵심 계약 | `gradlew test --tests ...PostgresProductionProfileTest --tests ...DbHealthControllerTest` | PASS |
| 미존재 리소스 예외 계약 | `gradlew test --tests ...GlobalExceptionHandlerTest` | PASS |
| Backend 전체 | `gradlew clean test --no-daemon` | 11 tests, 실패·오류·건너뜀 0, PASS |
| Flutter 전체 | `flutter test` | 3 tests PASS |
| Flutter 정적 분석 | `flutter analyze` | 오류 0, 경고 7, 정보 133(총 140), 분석 종료 코드는 실패 |

## 7. 운영 프로필 read-only smoke test

Supabase 연결 환경변수는 프로세스 메모리에만 로드하고 출력하지 않았다. Spring Boot를 `prod`로 기동해 PostgreSQL 17.6 연결을 확인한 뒤 다음 요청만 수행했다.

| 요청 | 상태 | 해석 |
|---|---:|---|
| `GET /actuator/health` | 200 | 애플리케이션 health 정상 |
| `GET /health/db` | 200 | `database=PostgreSQL`, `status=UP` |
| `GET /api/storage/quota` | 401 | 인증 보호 정상 |
| `GET /h2-console/` | 404 | 운영 H2 미노출 |
| `GET /swagger-ui/index.html` | 404 | 운영 Swagger UI 미노출 |
| `GET /v3/api-docs` | 404 | 운영 API 문서 미노출 |
| `GET /actuator/env` | 404 | 미허용 Actuator 엔드포인트 미노출 |

검증 후 해당 저장소에서 시작한 8080 포트 프로세스만 종료했고 포트 반환을 확인했다.

## 8. 보안과 데이터 영향

- DB, JWT, S3 비밀값은 환경변수로만 주입한다.
- health 장애 응답에 원본 예외 메시지를 포함하지 않는다.
- 운영 smoke test는 `SELECT 1` 외 데이터 쿼리를 수행하지 않았다.
- H2, Swagger, API docs, Actuator env는 운영에서 노출되지 않는다.
- 실제 비밀값과 `.env` 내용은 문서와 테스트 출력에 기록하지 않았다.

## 9. 남은 제한사항

- 로그인 후 앨범·사진·공유·스토리지 CRUD를 실제 Supabase 데이터로 검증하지 않았다.
- 소셜 로그인 UI는 실제 OAuth 흐름과 아직 연결되지 않았다.
- `flutter analyze`의 기존 140건(경고 및 정보 수준)을 별도 품질 개선 작업으로 남겼다.
- Backend 빌드에는 `AlbumShare.active`, `Album.photos`의 Lombok `@Builder` 기본값 경고와 deprecated/unchecked 사용 안내가 남아 있다.
- 배포, HTTPS, 방화벽, 실기기 전체 시나리오는 이번 변경의 검증 범위가 아니다.
- 부하 테스트를 하지 않았으므로 성능 개선 수치를 주장하지 않는다.

## 10. 포트폴리오 근거

### 개인 기여로 사용할 수 있는 표현

> PM과 백엔드 공동 담당으로 참여해 인증·QR·앨범·사진·공유·스토리지 API 영역을 맡았고, Supabase PostgreSQL 전환 후 프로필·보안 노출·health check·Flutter 런타임 설정을 정리했습니다. JUnit/Flutter 테스트와 운영 프로필 read-only smoke test로 PostgreSQL 연결, 인증 차단, 개발용 엔드포인트 비노출을 검증했습니다.

### 표현 시 지켜야 할 경계

- “전체 백엔드를 단독 개발” 대신 담당 도메인과 공동 담당 역할을 명시한다.
- “운영 배포 완료” 대신 로컬 `prod` 프로필 기동 및 read-only smoke 검증이라고 쓴다.
- “성능 개선” 대신 설정 안정화와 재현 가능한 검증 체계를 만들었다고 쓴다.
- Supabase Auth를 구현한 것으로 표현하지 않는다. 이번 전환은 PostgreSQL 연결과 런타임 설정 범위다.

## 11. 관련 문서

- [설계 문서](../../superpowers/specs/2026-08-02-runtime-hardening-and-evidence-documentation-design.md)
- [구현 계획](../../superpowers/plans/2026-08-02-runtime-hardening-and-evidence-documentation.md)
- [프로젝트 문서 인덱스](../README.md)
