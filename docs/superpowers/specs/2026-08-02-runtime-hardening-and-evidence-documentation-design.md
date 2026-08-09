# NEMO 런타임 하드닝과 증거 문서화 설계

## 배경

Supabase PostgreSQL 연결과 Spring Boot `prod` 기동은 확인됐지만, 기본 프로필이 운영 환경을 바라보고 H2 콘솔이 운영에서도 열리며 Flutter가 기본적으로 mock API를 사용한다. 현재 테스트는 설정 계약과 컨텍스트 로딩 위주라 실제 연동 상태를 충분히 설명하지 못한다.

## 목표

1. 로컬 기본 실행과 운영 실행의 경계를 명확히 분리한다.
2. 운영에서 개발용 H2 콘솔과 Swagger를 비활성화하고 Actuator 공개 범위를 제한한다.
3. DB 헬스체크가 PostgreSQL 상태를 정확한 HTTP 상태와 JSON으로 반환하게 한다.
4. Flutter가 `--dart-define`으로 mock 사용 여부와 API 주소를 선택하게 한다.
5. 변경 목적, 검증 명령, 확인 결과, 한계와 포트폴리오 표현을 재사용 가능한 문서 구조로 남긴다.

## 설계

### Spring 프로필

- `application.yml`은 공통 설정만 유지하고 기본 프로필을 `${SPRING_PROFILES_ACTIVE:dev}`로 둔다.
- H2 datasource, H2 console, 개발용 S3/URL은 `application-dev.yml`이 담당한다.
- `application-local.yml`은 PostgreSQL 로컬 연결용이며 DB, JWT, 공개 URL을 모두 환경변수로 받는다.
- `application-prod.yml`은 PostgreSQL, `ddl-auto=validate`, 운영 S3 환경변수를 사용한다.
- 운영에서는 H2 console과 springdoc API/Swagger UI를 명시적으로 비활성화한다.
- Actuator 웹 노출은 `health,info`로 제한하고 상세 정보는 기본적으로 공개하지 않는다.

### 보안과 헬스체크

- 공개 Actuator 경로는 `/actuator/health`, `/actuator/info`로 한정한다.
- `/health/db`는 `SELECT 1` 결과가 정상일 때 `200`과 `{status: UP, database: PostgreSQL}`을 반환한다.
- DB 예외 시 내부 예외 메시지를 노출하지 않고 `503`과 `{status: DOWN, database: PostgreSQL}`을 반환한다.

### Flutter 런타임 설정

- `AppConstants.useMockApi`는 `USE_MOCK_API` dart define을 읽고 기본값은 `false`로 둔다.
- API base URL은 `API_BASE_URL` dart define으로 받으며 미지정 시 Android 에뮬레이터 주소를 사용한다.
- 단위 테스트는 필요한 테스트에서 mock 모드를 명시적으로 켠다.
- Android의 HTTP 로컬 테스트 허용은 debug manifest에만 둔다.
- 인증 없이 앱 본문으로 진입하는 임시 버튼은 제거한다.

## 문서 구조

```text
docs/project/
├─ README.md
├─ templates/
│  └─ technical-change-record.md
└─ case-studies/
   └─ 2026-08-02-supabase-postgresql-runtime-hardening.md
```

- `README.md`: 문서 목적, 탐색 순서, 상태 표기 규칙을 제공한다.
- 템플릿: 문제, 범위, 선택지, 결정, 구현, 검증, 결과, 한계, 증거, 포트폴리오 문장을 고정 섹션으로 제공한다.
- 사례 문서: 이번 PostgreSQL 연결 전환과 런타임 하드닝을 실제 명령·결과로 채운다.

## 테스트 전략

- 설정 계약 테스트로 기본 프로필, 운영 H2/Swagger 비활성화, Actuator 노출 범위, 환경변수 기반 local/prod 설정을 검사한다.
- `DbHealthController` 단위 테스트에서 성공과 실패 HTTP 계약을 검증한다.
- Flutter 테스트에서 실제 API 기본값과 테스트별 mock opt-in을 확인한다.
- 전체 백엔드 테스트, Flutter 테스트, Flutter analyzer, `prod` 실제 기동과 read-only HTTP smoke를 다시 실행한다.

## 비범위

- Supabase Auth 도입
- 기존 데이터 이전 또는 라이브 DB 테스트 데이터 생성
- 카카오·구글 SDK 로그인 완성
- Flutter lint 141건 전체 정리
- 캐시/DB 성능 수치 생성
- Railway 등 외부 서버 배포

## 완료 기준

- 새 계약 테스트가 수정 전 실패하고 수정 후 통과한다.
- 전체 백엔드·Flutter 테스트가 통과한다.
- `prod` 기동에서 PostgreSQL 연결과 `/actuator/health`, `/health/db`, 보호 API 상태를 확인한다.
- `prod`에서 `/h2-console/`과 Swagger가 제공되지 않는다.
- README와 구조화된 프로젝트 문서가 실제 검증 결과와 남은 한계를 함께 기록한다.
- 성능 개선, 무중단 마이그레이션, 외부 배포 완료를 주장하지 않는다.
