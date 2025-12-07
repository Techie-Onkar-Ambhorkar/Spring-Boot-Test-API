# Build stage
FROM maven:3.8.4-jdk-17 AS build
WORKDIR /app
COPY . .
ARG ACTIVE_PROFILE=prod
RUN mvn clean package -DskipTests -Dspring.profiles.active=${ACTIVE_PROFILE} && \
    ls -la /app/target/

# Runtime stage
FROM eclipse-temurin:17-jre-jammy

# Set working directory
WORKDIR /app

# Create directory for logs with correct permissions
RUN mkdir -p /app/logs && \
    chmod 777 /app/logs

# Copy the JAR file from the build stage
COPY --from=build /app/target/Spring-Boot-Test-API-0.0.1-SNAPSHOT.jar app.jar

# Set the active profile
ARG ACTIVE_PROFILE=prod
ENV SPRING_PROFILES_ACTIVE=${ACTIVE_PROFILE}

# Expose the application port
EXPOSE 8080

# Run the application
ENTRYPOINT ["java", \
    "-Djava.security.egd=file:/dev/./urandom", \
    "-Dlogging.file.name=/app/logs/application.log", \
    "-Dlogging.level.root=INFO", \
    "-Dlogging.level.org.springframework=WARN", \
    "-jar", "app.jar"]