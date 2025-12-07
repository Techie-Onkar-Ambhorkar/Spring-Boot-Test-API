# Use Eclipse Temurin JRE 17 (smaller than JDK)
FROM eclipse-temurin:17-jre-jammy

# Set working directory
WORKDIR /app

# Create directory for logs with correct permissions
RUN mkdir -p /app/logs && \
    chmod 777 /app/logs

# Copy JAR file into container
COPY target/*.jar app.jar

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