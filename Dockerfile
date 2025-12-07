# Build stage
FROM maven:3.8.4-jdk-17 AS build
WORKDIR /app
COPY . .
RUN mvn clean package -DskipTests

# Runtime stage
FROM eclipse-temurin:17-jre-jammy

# Set working directory
WORKDIR /app

# Create directory for logs with correct permissions
RUN mkdir -p /app/logs && \
    chmod 777 /app/logs

# Copy the JAR file from the build stage
COPY --from=build /app/target/Spring-Boot-Test-API-*.jar app.jar

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