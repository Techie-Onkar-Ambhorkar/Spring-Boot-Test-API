# Build stage
FROM maven:3.8.4-jdk-17 AS build
WORKDIR /app
COPY . .
RUN mvn clean package -DskipTests && \
    ls -la /app/target/ && \
    unzip -l /app/target/Spring-Boot-Test-API-0.0.1-SNAPSHOT.jar | grep -i manifest

# Runtime stage
FROM eclipse-temurin:17-jre-jammy

# Set working directory
WORKDIR /app

# Create directory for logs with correct permissions
RUN mkdir -p /app/logs && \
    chmod 777 /app/logs

# Copy the JAR file from the build stage
COPY --from=build /app/target/Spring-Boot-Test-API-0.0.1-SNAPSHOT.jar app.jar

# Debug: Show JAR contents
RUN ls -la /app/ && \
    unzip -p /app/app.jar META-INF/MANIFEST.MF || true

# Expose the application port
EXPOSE 8080

# Set health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# Run the application with optimized JVM settings
ENTRYPOINT ["java", \
    "-Djava.security.egd=file:/dev/./urandom", \
    "-Dlogging.file.name=/app/logs/application.log", \
    "-Dlogging.level.root=INFO", \
    "-Dlogging.level.org.springframework=WARN", \
    "-jar", "app.jar"]