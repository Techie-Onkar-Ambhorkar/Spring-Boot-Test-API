# Use Eclipse Temurin JDK 17 with full JDK for debugging
FROM eclipse-temurin:17-jdk-jammy

# Install debugging tools
RUN apt-get update && apt-get install -y \
    curl \
    net-tools \
    iputils-ping \
    dnsutils \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Create directory for logs
RUN mkdir -p /app/logs

# Copy JAR file into container
COPY target/*.jar app.jar

# Expose the application port
EXPOSE 8080

# Set health check with better debugging
HEALTHCHECK --interval=15s --timeout=15s --start-period=45s --retries=5 \
  CMD curl -f http://localhost:8080/actuator/health || (echo "Health check failed" && exit 1)

# Run the application with debug and memory options
ENTRYPOINT ["sh", "-c", " \
    echo '=== Starting Application ===' && \
    echo 'Java version:' && java -version && \
    echo 'Environment:' && env && \
    echo '=== JAR Contents ===' && \
    unzip -l app.jar | head -20 && \
    echo '=== Starting Application ===' && \
    exec java \
    -Djava.security.egd=file:/dev/./urandom \
    -XX:+ShowCodeDetailsInExceptionMessages \
    -XX:+HeapDumpOnOutOfMemoryError \
    -XX:HeapDumpPath=/app/heapdump.hprof \
    -Dlogging.file.name=/app/logs/application.log \
    -Dlogging.level.root=INFO \
    -Dlogging.level.org.springframework=INFO \
    -Dlogging.level.com.example=DEBUG \
    -jar app.jar \
    --debug \
    --spring.config.location=classpath:/application.yaml,file:/app/config/application.yaml \
    2>&1 | tee -a /app/logs/console.log"