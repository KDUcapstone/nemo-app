# 네컷모아 (NEMO)

셀프 포토부스 사진을 QR 또는 직접 업로드로 모아 클라우드에 보관하고, 날짜·브랜드·장소·친구 기준으로 정리해 캘린더 회고와 공유 앨범을 제공하는 앱입니다.

## WHY

포토부스는 브랜드마다 사진 다운로드 방식과 보관 위치가 제각각입니다. 카카오톡으로 받은 것, 브랜드 앱에 남은 것, 갤러리에 저장한 것이 흩어지고, 시간이 지나면 "언제 누구와 어디서 찍었는지"라는 맥락이 먼저 사라집니다.

네컷모아는 **사진 파일과 촬영 맥락을 함께 저장**해서, 나중에 다시 찾고 회고할 수 있게 만듭니다.

## WHAT

| 기능 | 설명 |
|---|---|
| QR 가져오기 | 포토부스 QR을 스캔해 원본을 내려받고 중복을 걸러 저장 |
| 직접 업로드 | 갤러리 파일 업로드. EXIF에서 촬영일 추출 |
| 자동·수동 분류 | 날짜 · 브랜드 · 장소 · 함께 찍은 친구 · 해시태그 |
| 캘린더 회고 | 월별 캘린더와 타임라인에서 과거 사진 탐색 |
| 공유 앨범 | 공유 링크 또는 친구 초대로 공동 앨범 구성 |
| 지도 | 사진을 찍은 포토부스 위치 확인 |

## HOW

```text
Flutter 앱
  │  http + JWT
  ▼ HTTPS
Spring Boot API
  ├─ auth    인증·토큰 발급/검증, 이메일 인증, 비밀번호 재설정
  ├─ user    프로필, 계정 상태
  ├─ photo   업로드, QR 가져오기, 태그, 즐겨찾기
  ├─ album   앨범, 공유 링크, 참여자 권한
  ├─ friend  친구 관계
  ├─ timeline 캘린더·타임라인 조회 모델
  ├─ map     포토부스 위치 검색
  └─ storage 파일 저장 추상화
        │
        ├─ PostgreSQL (Supabase) — 사용자·사진 메타데이터·관계
        └─ S3 / LocalStack       — 원본·압축본·썸네일
```

큰 바이너리는 오브젝트 스토리지에, 검색·정렬에 필요한 메타데이터는 RDB에 두고 DB에는 객체 키만 저장합니다. 졸업작품 규모에서 마이크로서비스 분리는 하지 않았습니다 — 운영과 설명이 모두 어려워지기 때문입니다.

## 기술 스택

**Backend** — Java 21 · Spring Boot 3.5.3 · Spring Security + JWT(jjwt) · Spring Data JPA · springdoc-openapi · Actuator · AWS SDK v2 (S3) · ZXing(QR) · Jsoup

**Frontend** — Flutter (Dart SDK 3.8+) · provider · http · flutter_naver_map · mobile_scanner(QR) · image_picker · geolocator

**Data / Infra** — PostgreSQL(Supabase, 운영) · H2(개발) · MariaDB(레거시) · LocalStack · Docker · Nginx

## 실행

### Backend

```bash
cd backend && ./gradlew bootRun
```

기본 프로필은 `dev`입니다. 환경변수 없이 H2 인메모리로 뜹니다. Swagger는 `http://localhost:8080/swagger-ui/index.html`.

운영 프로필은 환경변수를 요구합니다 — `SPRING_PROFILES_ACTIVE=prod`, `DB_URL` / `DB_USER` / `DB_PASSWORD`, `JWT_SECRET`, `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`. 저장소에는 비밀값을 커밋하지 않습니다.

### Frontend

```bash
cd frontend && flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

Mock API는 `--dart-define=USE_MOCK_API=true`일 때만 켜집니다.

### 빌드 주의

Gradle toolchain이 **Java 21**을 요구합니다. JDK 23 환경에서는 빌드가 깨집니다.

## 문서

- [문서 허브](docs/project/README.md) — 문서 상태 규칙(`Draft` / `Verified` / `Historical`)
- [Case Study: Supabase PostgreSQL 전환 후 런타임 하드닝](docs/project/case-studies/2026-08-02-supabase-postgresql-runtime-hardening.md) — `Verified`
- [설계·구현 계획](docs/superpowers/)

## 팀

3인 졸업작품 (KDU 캡스톤)

| 이름 | 역할 |
|---|---|
| 김한욱 | 팀장 · 풀스택 |
| 문한일 | 백엔드 |
| 임다빈 | 프론트엔드 |

기여자 목록은 `.mailmap`으로 정규화되어 있습니다 — `git shortlog -sne --all`.

## 브랜치

`dev`가 통합 브랜치입니다. 기능 작업은 `feature/*`에서 시작해 `dev`로 PR을 보내고, 릴리스 시점에 `dev` → `main`으로 병합합니다.
