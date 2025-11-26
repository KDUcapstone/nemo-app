# ============================
# 1단계: 빌드용 이미지 (Gradle + JDK)
# ============================
FROM eclipse-temurin:21-jdk AS builder

# 작업 디렉토리 설정
WORKDIR /app

# Gradle Wrapper 및 설정 파일 먼저 복사 (캐시 활용)
COPY gradlew ./
COPY gradle ./gradle
COPY build.gradle* settings.gradle* ./

# 나머지 소스 코드 복사
COPY src ./src

# Gradle wrapper 실행 권한 부여 (리눅스 환경 필수)
RUN chmod +x ./gradlew

# 테스트는 건너뛰고 bootJar만 빌드
RUN ./gradlew clean bootJar -x test


# ============================
# 2단계: 실행용 이미지 (JRE만 포함, 더 가벼움)
# ============================
FROM eclipse-temurin:21-jre

# 작업 디렉토리 설정
WORKDIR /app

# 1단계에서 빌드된 JAR 파일 복사
COPY --from=builder /app/build/libs/*.jar app.jar

# 컨테이너에서 사용할 포트 (Spring 기본: 8080)
EXPOSE 8080

# ⚠ 프로필은 Dockerfile에서 고정하지 않고,
#    CloudType 환경변수 SPRING_PROFILES_ACTIVE=prod 로 제어할 것!
#
# 시간대도 한국 기준으로 맞춰줌.
ENTRYPOINT ["java", "-Duser.timezone=Asia/Seoul", "-jar", "app.jar"]
