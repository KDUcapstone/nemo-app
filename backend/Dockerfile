# =============================
# 1단계: 빌드용 이미지 (Gradle + JDK)
# =============================
FROM eclipse-temurin:21-jdk AS builder

# 작업 디렉토리 설정
WORKDIR /app

# Gradle Wrapper 및 설정 파일 먼저 복사 (캐시 활용)
COPY gradlew ./
COPY gradle ./gradle
COPY build.gradle* settings.gradle* ./

# 나머지 소스 코드 복사
COPY . .

# Gradle wrapper 실행 권한 부여
RUN chmod +x gradlew

# 테스트는 건너뛰고(Spring Boot JAR 빌드만)
RUN ./gradlew clean bootJar -x test


# =============================
# 2단계: 실제 서비스용 이미지 (JRE)
# =============================
FROM eclipse-temurin:21-jre

# 프로필은 운영용(prod)으로
ENV SPRING_PROFILES_ACTIVE=prod

# 작업 디렉토리
WORKDIR /app

# 1단계에서 빌드한 JAR 파일 복사
# (build/libs 안에 있는 .jar 하나를 app.jar로 복사)
COPY --from=builder /app/build/libs/*.jar app.jar

# 컨테이너가 외부에 개방할 포트
EXPOSE 8080

# 컨테이너 시작 시 실행할 명령
ENTRYPOINT ["java", "-jar", "app.jar"]
