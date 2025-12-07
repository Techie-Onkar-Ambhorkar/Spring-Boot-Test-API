# Build stage
FROM maven:3.8.4-jdk-17 AS build
WORKDIR /app
COPY . .
ARG ACTIVE_PROFILE
RUN mvn clean package -DskipTests ${ACTIVE_PROFILE:+-Dspring.profiles.active=$ACTIVE_PROFILE} && \
    ls -la /app/target/

# Runtime stage
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app
RUN mkdir -p /app/logs && \
    chmod 777 /app/logs
COPY --from=build /app/target/Spring-Boot-Test-API-0.0.1-SNAPSHOT.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", \
    "-Djava.security.egd=file:/dev/./urandom", \
    "-Dlogging.file.name=/app/logs/application.log", \
    "-Dlogging.level.root=INFO", \
    "-Dlogging.level.org.springframework=WARN", \
    "-jar", "app.jar"]