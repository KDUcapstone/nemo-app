# NEMO Runtime Hardening and Evidence Documentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Supabase PostgreSQL 전환 이후의 실행 경계를 안전하게 만들고 재현 가능한 테스트와 프로젝트 문서로 증거를 남긴다.

**Architecture:** Spring 설정은 공통, dev, local, prod 책임으로 분리하고 운영 공개 표면을 최소화한다. Flutter는 dart define 기반 런타임 설정을 사용하며, 검증 결과는 `docs/project`의 템플릿과 사례 문서로 연결한다.

**Tech Stack:** Java 21, Spring Boot 3.5.3, Spring Security, Spring Data JPA, PostgreSQL, JUnit 5, Mockito, Flutter 3.35.2, Dart 3.9

## Global Constraints

- 기존 데이터와 라이브 사용자 데이터를 변경하지 않는다.
- Supabase Auth와 외부 배포는 도입하지 않는다.
- 성능 개선 수치는 측정 전까지 작성하지 않는다.
- 사용자 미커밋 변경을 보존하고 커밋·스테이징하지 않는다.
- 운영 비밀값을 문서, 테스트 출력, Git 추적 파일에 기록하지 않는다.

---

### Task 1: Spring 설정과 DB health 계약

**Files:**
- Modify: `backend/src/test/java/com/nemo/backend/config/PostgresProductionProfileTest.java`
- Create: `backend/src/test/java/com/nemo/backend/global/health/DbHealthControllerTest.java`
- Modify: `backend/src/main/resources/application.yml`
- Modify: `backend/src/main/resources/application-local.yml`
- Modify: `backend/src/main/resources/application-prod.yml`
- Modify: `backend/src/main/java/com/nemo/backend/global/health/DbHealthController.java`

**Interfaces:**
- Consumes: Spring YAML 프로필과 `JdbcTemplate`
- Produces: 안전한 프로필 계약과 JSON DB health 응답

- [x] **Step 1: 실패하는 설정 계약과 health 테스트 작성**

기본 프로필이 `${SPRING_PROFILES_ACTIVE:dev}`이고 운영 H2/Swagger가 비활성화되며, health 성공은 200/UP, 실패는 503/DOWN인지 검증한다.

- [x] **Step 2: RED 확인**

Run: `backend\gradlew.bat test --tests com.nemo.backend.config.PostgresProductionProfileTest --tests com.nemo.backend.global.health.DbHealthControllerTest`

Expected: 현재 기본 `prod`, H2 활성화, 문자열 health 응답 때문에 FAIL.

- [x] **Step 3: 최소 설정과 health 구현**

공통/프로필 책임을 분리하고 local 비밀값을 환경변수로 바꾸며 `DbHealthController`가 `ResponseEntity<Map<String,String>>`를 반환하게 한다.

- [x] **Step 4: GREEN 확인**

Run: `backend\gradlew.bat test --tests com.nemo.backend.config.PostgresProductionProfileTest --tests com.nemo.backend.global.health.DbHealthControllerTest`

Expected: PASS.

### Task 2: 공개 보안 표면 제한

**Files:**
- Modify: `backend/src/main/java/com/nemo/backend/global/security/SecurityConfig.java`
- Modify: `backend/src/test/java/com/nemo/backend/config/PostgresProductionProfileTest.java`

**Interfaces:**
- Consumes: Spring Security request matcher와 prod 설정
- Produces: health/info만 공개되는 Actuator 계약

- [x] **Step 1: 실패하는 공개 경로 계약 추가**

SecurityConfig 소스 계약에서 `/actuator/**`가 사라지고 health/info만 남는지 검증한다.

- [x] **Step 2: RED 확인 후 matcher 최소 수정**

Run: `backend\gradlew.bat test --tests com.nemo.backend.config.PostgresProductionProfileTest`

Expected: 수정 전 FAIL, 수정 후 PASS.

### Task 3: Flutter 실제 연동 기본값

**Files:**
- Modify: `frontend/test/photo_provider_test.dart`
- Create: `frontend/test/runtime_config_test.dart`
- Modify: `frontend/lib/app/constants.dart`
- Modify: `frontend/lib/services/auth_service.dart`
- Modify: `frontend/lib/presentation/screens/login/login_screen.dart`
- Modify: `frontend/android/app/src/debug/AndroidManifest.xml`

**Interfaces:**
- Consumes: `USE_MOCK_API`, `API_BASE_URL` dart define
- Produces: 실제 API 기본값과 명시적 테스트 mock 설정

- [x] **Step 1: 기본 mock 비활성화 테스트 작성**

`AppConstants.useMockApi` 기본값이 false인지 검증하고 기존 provider 테스트는 setUp/tearDown으로 mock을 명시한다.

- [x] **Step 2: RED 확인**

Run: `flutter test test/runtime_config_test.dart`

Expected: 현재 `useMockApi=true`라 FAIL.

- [x] **Step 3: dart define 설정, debug HTTP 허용, 임시 우회 제거**

런타임 설정을 dart define으로 바꾸고 로그인 화면의 임시 진입 버튼을 삭제한다.

- [x] **Step 4: GREEN 확인**

Run: `flutter test`

Expected: PASS.

### Task 4: 구조화된 프로젝트 문서

**Files:**
- Create: `docs/project/README.md`
- Create: `docs/project/templates/technical-change-record.md`
- Create: `docs/project/case-studies/2026-08-02-supabase-postgresql-runtime-hardening.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: Tasks 1-3의 실제 변경과 검증 결과
- Produces: 탐색 가능한 프로젝트 문서와 재사용 템플릿

- [x] **Step 1: 문서 인덱스와 템플릿 작성**

문서 상태, 근거 수준, 검증 명령을 고정된 섹션으로 제공한다.

- [x] **Step 2: 이번 사례를 실제 결과로 작성**

PostgreSQL 17.6 연결, 테스트 수, HTTP smoke 결과, 비범위와 잔여 위험을 기록한다.

- [x] **Step 3: README에서 문서 인덱스 연결**

기술 스택을 MariaDB 단일 표기에서 PostgreSQL 전환 상태로 고치고 실행·검증 문서 링크를 추가한다.

### Task 5: 전체 검증과 문서 결과 확정

**Files:**
- Verify: `backend/`
- Verify: `frontend/`
- Update: `docs/project/case-studies/2026-08-02-supabase-postgresql-runtime-hardening.md`

**Interfaces:**
- Consumes: 전체 변경
- Produces: 재현 가능한 최종 검증 증거

- [x] **Step 1: 백엔드 전체 테스트**

Run: `backend\gradlew.bat clean test --no-daemon`

- [x] **Step 2: Flutter 테스트와 analyzer**

Run: `flutter test`, `flutter analyze`

- [x] **Step 3: prod read-only smoke**

`.env`를 프로세스 환경에만 로드해 prod를 기동하고 health, DB health, 무토큰 보호 API, H2/Swagger 비노출을 확인한 뒤 서버를 종료한다.

- [x] **Step 4: 최종 상태 기록**

테스트 수, HTTP 상태, analyzer 잔여 항목, 미검증 기능을 사례 문서에 갱신하고 `git diff --check`, `git status --short`를 확인한다.
