# NEMO Supabase PostgreSQL 전환 설계

## 목표

기존 CloudType MariaDB 운영 설정을 Supabase PostgreSQL 연결 설정으로 전환한다. 기존 데이터는 이전하지 않고, NEMO가 직접 발급·검증하는 Spring Security JWT 구조는 유지한다.

## 구조

```text
Flutter -> Spring Boot -> Supabase PostgreSQL
              |
              +-> 기존 NEMO JWT/RefreshToken 유지
              +-> 기존 AWS S3 유지
```

Supabase는 이 작업에서 관리형 PostgreSQL로만 사용한다. Supabase Auth, Data API, Edge Functions, Storage는 도입하지 않는다.

## 변경 범위

- PostgreSQL JDBC 드라이버를 런타임 의존성에 추가한다.
- 기존 로컬 MariaDB 프로필을 위해 MariaDB 드라이버는 유지한다.
- `application-prod.yml`을 PostgreSQL과 환경변수 기반 설정으로 교체한다.
- 빈 Supabase DB에는 Hibernate `ddl-auto=update`로 엔티티 8개의 스키마를 생성한다.
- 운영 JWT secret, DB 주소, 공개 서버 주소는 모두 환경변수로 주입한다.
- CloudType URL과 운영 설정의 하드코딩 JWT secret을 제거한다.

## 비범위

- 기존 MariaDB 데이터 이전
- Supabase Auth 도입
- Spring Boot 서버 호스팅 업체 선정 및 배포
- Flyway 도입
- 기존 `application.yml`, `application-local.yml` 변경

## 검증 기준

- 운영 프로필 설정 테스트가 PostgreSQL 드라이버, PostgreSQL Dialect, 환경변수 기반 DB/JWT 설정을 확인한다.
- PostgreSQL JDBC 드라이버 클래스가 테스트 런타임에서 로딩된다.
- 전체 백엔드 테스트와 `compileJava`가 통과한다.
- 기존 사용자 미커밋 파일은 변경되지 않는다.

## 후속 외부 작업

새 Supabase 프로젝트를 생성할 조직을 사용자에게 확인한 뒤 프로젝트를 생성한다. 생성된 프로젝트의 Session Pooler 연결 정보를 배포 환경변수로 설정하고 애플리케이션을 기동해 테이블 생성과 핵심 API를 확인한다.
