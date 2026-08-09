# Supabase PostgreSQL Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** NEMO의 운영 DB 설정을 CloudType MariaDB에서 Supabase PostgreSQL로 전환한다.

**Architecture:** Flutter와 Spring Boot 및 기존 JWT 인증 구조는 유지한다. Supabase는 PostgreSQL DB로만 사용하고, 운영 접속 정보와 JWT secret은 환경변수로 주입한다.

**Tech Stack:** Java 21, Spring Boot 3.5.3, Spring Data JPA, Hibernate, PostgreSQL JDBC, JUnit 5, AssertJ

## Global Constraints

- 기존 MariaDB 데이터는 이전하지 않는다.
- Supabase Auth를 도입하지 않는다.
- `application.yml`과 `application-local.yml`의 사용자 미커밋 변경을 보존한다.
- 기존 MariaDB 로컬 프로필 호환성을 위해 MariaDB JDBC 드라이버를 유지한다.
- 커밋과 스테이징은 사용자가 요청하기 전까지 하지 않는다.

---

### Task 1: 운영 PostgreSQL 설정 계약 테스트

**Files:**
- Create: `backend/src/test/java/com/nemo/backend/config/PostgresProductionProfileTest.java`
- Test: `backend/src/test/java/com/nemo/backend/config/PostgresProductionProfileTest.java`

**Interfaces:**
- Consumes: `backend/src/main/resources/application-prod.yml`
- Produces: 운영 프로필이 충족해야 할 PostgreSQL 설정 계약

- [ ] **Step 1: 실패하는 설정 테스트 작성**

`YamlPropertySourceLoader`로 `application-prod.yml`을 읽고 다음 값을 검증한다.

```java
assertThat(property("spring.datasource.driver-class-name"))
        .isEqualTo("org.postgresql.Driver");
assertThat(property("spring.datasource.url"))
        .isEqualTo("${DB_URL}");
assertThat(property("spring.jpa.database-platform"))
        .isEqualTo("org.hibernate.dialect.PostgreSQLDialect");
assertThat(property("app.jwt.secret"))
        .isEqualTo("${JWT_SECRET}");
assertThatCode(() -> Class.forName("org.postgresql.Driver"))
        .doesNotThrowAnyException();
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `.\gradlew.bat test --tests com.nemo.backend.config.PostgresProductionProfileTest`

Expected: MariaDB 드라이버와 CloudType URL이 남아 있고 PostgreSQL 드라이버 클래스가 없어 FAIL.

### Task 2: PostgreSQL 의존성과 운영 설정 구현

**Files:**
- Modify: `backend/build.gradle`
- Modify: `backend/src/main/resources/application-prod.yml`
- Test: `backend/src/test/java/com/nemo/backend/config/PostgresProductionProfileTest.java`

**Interfaces:**
- Consumes: Task 1의 운영 설정 계약
- Produces: Supabase PostgreSQL에 연결 가능한 `prod` 프로필

- [ ] **Step 1: PostgreSQL 드라이버 추가**

`backend/build.gradle`에 다음 런타임 의존성을 추가하고 MariaDB 드라이버는 유지한다.

```groovy
runtimeOnly 'org.postgresql:postgresql'
```

- [ ] **Step 2: 운영 프로필 전환**

`application-prod.yml`을 다음 원칙으로 변경한다.

```yaml
spring:
  datasource:
    driver-class-name: org.postgresql.Driver
    url: ${DB_URL}
    username: ${DB_USER}
    password: ${DB_PASSWORD}
  jpa:
    database-platform: org.hibernate.dialect.PostgreSQLDialect
    hibernate:
      ddl-auto: update

app:
  jwt:
    secret: ${JWT_SECRET}
    issuer: ${JWT_ISSUER:nemo-backend}
    access-ttl-ms: ${JWT_ACCESS_TTL_MS:900000}
  public-base-url: ${PUBLIC_BASE_URL}
```

- [ ] **Step 3: 설정 테스트 통과 확인**

Run: `.\gradlew.bat test --tests com.nemo.backend.config.PostgresProductionProfileTest`

Expected: PASS.

### Task 3: 전체 회귀 검증

**Files:**
- Verify: `backend/`

**Interfaces:**
- Consumes: PostgreSQL 운영 설정과 기존 애플리케이션 코드
- Produces: 컴파일 및 테스트 증거

- [ ] **Step 1: 전체 테스트 실행**

Run: `.\gradlew.bat test`

Expected: 모든 테스트 PASS.

- [ ] **Step 2: 컴파일 실행**

Run: `.\gradlew.bat compileJava`

Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 3: 변경 범위 확인**

Run: `git status --short` 및 `git diff --check`

Expected: 기존 사용자 변경 2건은 유지되고, PostgreSQL 마이그레이션 파일만 추가 또는 수정되며 whitespace 오류가 없다.

### Task 4: Supabase 프로젝트 생성 및 연결

**Files:**
- No repository changes until project details are known.

**Interfaces:**
- Consumes: 사용자가 선택한 Supabase organization ID
- Produces: NEMO용 Supabase project ID와 Session Pooler 연결 정보

- [ ] **Step 1: 조직 선택 확인**

연결된 `aimong-dev`가 속한 조직 `hotblgptmnmujmhlffrz`에 `nemo-dev`를 생성할지 사용자에게 확인한다.

- [ ] **Step 2: 프로젝트 생성**

비용 확인 절차 후 서울 리전 `ap-northeast-2`에 `nemo-dev` 프로젝트를 생성한다.

- [ ] **Step 3: 배포 환경변수 준비**

생성된 프로젝트의 Session Pooler JDBC URL을 `DB_URL`, 사용자명을 `DB_USER`, 비밀번호를 `DB_PASSWORD`로 설정한다. `JWT_SECRET`, `PUBLIC_BASE_URL`, AWS S3 환경변수도 별도 배포 서버에 설정한다.

- [ ] **Step 4: 원격 기동 검증**

Spring Boot 서버를 별도 Java 호스팅 환경에서 `prod` 프로필로 기동하고, Hibernate가 빈 PostgreSQL DB에 스키마를 생성하는지 확인한다.
