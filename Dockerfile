# Use Eclipse Temurin JDK 17 (recommended)
FROM eclipse-temurin:17-jdk

# Set working directory
WORKDIR /app

# Copy JAR file into container
COPY target/*.jar app.jar

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]