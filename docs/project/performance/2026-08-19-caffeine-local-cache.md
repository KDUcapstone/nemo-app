---
title: Naver 지도 로컬 캐시 Caffeine 교체
status: Verified
date: 2026-08-19
owner: PM 겸 백엔드 공동 담당
related_issues: []
---

# Naver 지도 로컬 캐시 Caffeine 교체

## 1. 요약

- 변경 목적: 직접 구현한 `ConcurrentHashMap + TTL`을 정책과 통계를 제공하는 Caffeine 로컬 캐시로 교체했다.
- 사용자 영향: 지도 검색·뷰포트·Delta API의 URI key와 응답 형식은 유지했다.
- 현재 상태: 로컬 자동 테스트와 스텁 측정으로 검증했다.
- 핵심 결과: 성능 수치 자체보다 최대 크기, 만료, hit/miss/eviction 관측 정책을 코드와 설정으로 명확히 만들었다.

## 2. Before: ConcurrentHashMap + 직접 TTL

`NaverApiClient` 하나가 Local Search와 Reverse Geocoding 응답을 공통 `ConcurrentHashMap`에 저장했다.

| 항목 | 변경 전 동작 |
|---|---|
| key | 완성된 Naver 요청 URI 문자열 |
| value | Naver 원본 응답 `Map<String, Object>` |
| TTL | 코드에 고정된 120,000ms |
| 만료 판정 | 같은 key를 다시 조회할 때 저장 시각과 현재 시각 비교 |
| 정리 | 만료된 key를 재조회했을 때만 `remove` |
| 최대 크기 | 없음 |
| 통계 | hit 디버그 로그만 존재 |

이 구조는 작은 단일 서버에서 빠르게 만들기에는 단순하다. 하지만 다시 조회되지 않는 만료 항목은 남을 수 있고, URI 종류가 계속 늘어도 저장 개수를 제한하지 못한다. miss와 eviction 수가 없어서 캐시 효과도 정량적으로 확인하기 어려웠다.

## 3. Why Caffeine

Caffeine은 JVM 프로세스 안에서 동작하는 검증된 로컬 캐시다. 이번 요구에 필요한 `expireAfterWrite`, `maximumSize`, `recordStats`를 제공하며 별도 서버나 네트워크 호출이 필요 없다.

NEMO는 현재 단일 인스턴스이고 지도 데이터는 Naver 원본의 짧은 임시 복사본이다. 여러 서버가 공유해야 하는 세션이나 영구 데이터가 아니므로 Redis의 배포, 장애 대응, 네트워크 비용을 추가할 이유가 없다.

다음 조건이 생기면 Redis를 다시 검토한다.

- 애플리케이션 인스턴스를 여러 대로 늘려 같은 캐시를 공유해야 할 때
- 인스턴스 재시작 뒤에도 캐시를 유지해야 할 때
- 중앙 무효화나 전체 인스턴스의 통합 통계가 필요할 때

## 4. After 구조

```text
Map Controller
→ PhotoboothService
→ NaverApiClient
→ URI 문자열 key 생성
→ Caffeine Cache<String, Map<String, Object>>
   ├─ hit: 저장된 Naver 응답 반환
   └─ miss: Naver API 호출 후 저장
```

Local Search와 Reverse Geocoding은 기존처럼 같은 캐시를 공유한다. key 생성과 `null` 응답을 빈 Map으로 저장하는 동작도 유지했다. Controller, Service, DTO와 HTTP 응답 계약은 수정하지 않았다.

## 5. 적용 정책

| 정책 | 기본값 | 설정 |
|---|---:|---|
| 만료 | `expireAfterWrite` 120,000ms | `NAVER_CACHE_TTL_MS` |
| 최대 크기 | 1,000 entries | `NAVER_CACHE_MAXIMUM_SIZE` |
| 통계 | hit/miss/eviction 기록 | Caffeine `recordStats()` |
| 캐시 OFF | TTL `0` | 조회·저장 모두 우회 |

`expireAfterWrite`는 기존의 “응답을 저장한 시점부터 2분” 의미를 유지한다. `expireAfterAccess`를 쓰면 자주 조회되는 오래된 외부 결과가 계속 연장될 수 있어 선택하지 않았다.

뷰포트 한 번은 Reverse Geocoding 1개와 Local Search 고유 URI 약 36개까지 만들 수 있다. `maximumSize=1000`은 이 최악 조건을 단순 환산하면 약 27개 지역 그룹을 담는 시작값이다. 이는 정확한 메모리 바이트 제한이 아니므로 운영 heap과 eviction 통계를 보고 조정해야 한다.

## 6. 테스트 결과

TDD의 RED 단계에서는 기존 클라이언트에 설정 가능한 생성자와 통계 API가 없어 `compileTestJava`가 실패했다. Caffeine 교체 뒤 다음 동작이 통과했다.

| 검증 | 실제 결과 |
|---|---|
| 동일 key 재조회 | 외부 호출 1회, miss 1, hit 1 |
| TTL 만료 후 재조회 | 가짜 시계로 만료 후 외부 호출 총 2회 |
| TTL=0 | 같은 key도 외부 호출 2회, 캐시 크기 0 |
| maximumSize=1 | 두 key 저장 시 eviction 1회, 크기 1 이하 |
| Local/Reverse 공통 정책 | 동일 Reverse Geocoding key 재조회 시 외부 호출 1회, miss/hit 1/1 |
| 지도 검색 결과 회귀 | 이름·브랜드·좌표·주소·Naver URL 유지 |
| 설정 계약 | TTL 120000, maximumSize 1000 환경변수 기본값 확인 |
| 실제 Spring Bean 생성 | 테스트용 생성자와 함께 있어도 운영 생성자 주입 성공 |

실행 명령:

```bash
cd backend
./gradlew test --rerun-tasks --no-daemon --console=plain
./gradlew mapCacheMeasurement --rerun-tasks --no-daemon --console=plain
```

## 7. 측정 결과

### 조건

- JDK 로컬 HTTP 스텁 서버 사용
- `MockMvc → PhotoboothController → PhotoboothService → NaverApiClient → stub` 경로
- `GET /api/map/photobooths/search?keyword=인생네컷&limit=10`
- 워밍업 결과는 버리고 OFF/ON 각각 같은 요청 10회, 총 3회 반복
- OFF: TTL 0
- ON: TTL 120,000ms, maximumSize 1,000
- 실제 Naver, 운영 DB, 운영 네트워크는 사용하지 않음

| 회차 | 모드 | 외부 호출 | 평균 응답시간 | hit | miss |
|---:|---|---:|---:|---:|---:|
| 1 | OFF | 10 | 183.754ms | 0 | 0 |
| 1 | ON | 1 | 6.907ms | 9 | 1 |
| 2 | OFF | 10 | 186.468ms | 0 | 0 |
| 2 | ON | 1 | 6.405ms | 9 | 1 |
| 3 | OFF | 10 | 186.411ms | 0 | 0 |
| 3 | ON | 1 | 6.473ms | 9 | 1 |
| 평균 | OFF | 10.0 | 185.544ms | 0 | 0 |
| 평균 | ON | 1.0 | 6.595ms | 9 | 1 |

OFF 평균에는 반복 외부 호출뿐 아니라 `NaverApiClient`의 기존 200ms 최소 호출 간격이 반영된다. ON은 첫 요청 뒤 9개 요청이 cache hit여서 그 간격과 HTTP 호출을 피한다.

이 측정은 **캐시 OFF와 Caffeine 캐시 ON의 차이**다. 기존 직접 구현 캐시 ON과 Caffeine ON을 같은 실행에서 비교한 결과가 아니므로 “Caffeine 교체로 응답시간을 98% 개선했다”라고 표현하면 안 된다. 확인된 사실은 동일 key 10회에서 외부 호출이 10회에서 1회로 줄고 hit/miss가 기대대로 기록됐다는 것이다.

## 8. Trade-off와 남은 한계

- 캐시는 애플리케이션 프로세스별로 존재한다. 다중 인스턴스 간 공유나 일관성은 제공하지 않는다.
- 서버 재시작 시 캐시는 사라진다. 지도 임시 응답에는 허용한 선택이다.
- `maximumSize`는 entry 수 제한이지 byte 단위 heap 제한이 아니다.
- Caffeine 정리와 eviction도 요청 처리 과정에 작은 비용을 추가한다.
- 동일 key가 동시에 miss일 때 외부 호출을 하나로 합치는 single-flight 구조는 추가하지 않았다.
- hit/miss/eviction은 `cacheStats()`와 측정 테스트에서 확인할 수 있지만, Actuator 공개 metric으로 노출하지는 않았다.
- 실제 Naver 지연시간, 운영 트래픽, heap 사용량은 측정하지 않았다.

## 9. 포트폴리오 요약

문제

→ 기존 직접 구현 로컬 캐시는 TTL은 있었지만 크기 제한과 만료 항목 정리, hit/miss 통계가 명확하지 않았다.

선택

→ 단일 인스턴스에서 짧게 재사용하는 외부 API 응답이므로 분산 캐시는 불필요하다고 판단해 Redis 대신 Caffeine을 선택했다.

구현

→ 기존 URI key와 API 응답을 유지하면서 `expireAfterWrite` 2분, `maximumSize` 1,000, 통계 기록을 적용하고 TTL 0 비교 설정과 회귀 테스트를 추가했다.

결과

→ 로컬 스텁의 동일 요청 10회 조건에서 캐시 OFF는 외부 호출 10회, ON은 1회였고 ON의 hit/miss는 9/1로 확인됐다. 이번 변경의 핵심 성과는 직접 구현 캐시를 최대 크기·만료·통계 정책이 명확한 로컬 캐시로 교체한 것이다.

### 넣어도 되는 문장

> 단일 인스턴스 지도 조회의 직접 구현 TTL 캐시를 Caffeine으로 교체하고, 기존 URI key와 API 응답을 유지한 채 2분 만료·최대 1,000개·hit/miss 통계 정책을 설정과 회귀 테스트로 검증했습니다.

> 로컬 스텁의 동일 요청 10회 조건에서 캐시 OFF 10회, ON 1회의 외부 호출을 확인했으며, Caffeine 자체의 속도 향상보다 캐시 정책과 메모리 관리 구조 개선에 초점을 맞췄습니다.

### 넣으면 안 되는 표현

- “Caffeine으로 응답속도를 98% 개선했다.”
- “운영 환경에서 약 190ms를 2ms로 개선했다.”
- “Redis 수준의 분산 캐시를 구현했다.”
- “메모리 사용량을 1,000개 객체만큼 보장했다.”
- “동시 요청의 중복 외부 호출을 완전히 제거했다.”

## 10. 변경 파일과 실행 위치

- 구현: `backend/src/main/java/com/nemo/backend/domain/map/util/NaverApiClient.java`
- 설정: `backend/src/main/resources/application.yml`
- 단위·회귀 테스트: `backend/src/test/java/com/nemo/backend/domain/map/`
- 설정 테스트: `backend/src/test/java/com/nemo/backend/config/NaverCacheConfigurationTest.java`
- 측정: `backend/src/test/java/com/nemo/backend/performance/MapCacheMeasurementTest.java`
- 실행 task: `backend/build.gradle`의 `mapCacheMeasurement`
