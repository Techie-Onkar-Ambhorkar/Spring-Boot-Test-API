pipeline {
  agent any

  tools {
    maven 'Maven'
  }

  environment {
    DOCKER_IMAGE    = "spring-boot-test-api"
    DOCKER_TAG      = "latest"
    SERVICE_NAME    = "spring-boot-test-api"
    COMPOSE_FILE    = "docker-compose.yml"
    COMPOSE_PROJECT = "spring-boot-test"
    APP_PORT        = "8080"
  }

  stages {
    stage('Checkout') {
      steps {
        git branch: 'master',
            url: 'https://github.com/Techie-Onkar-Ambhorkar/Spring-Boot-Test-API.git',
            credentialsId: 'github-creds'
      }
    }

    stage('Build & Test') {
      steps {
        sh 'mvn clean package'
      }
    }

    stage('Build Docker Image') {
      steps {
        script {
          // Build the Docker image
          docker.build("${DOCKER_IMAGE}:${DOCKER_TAG}").withRun("-p 8080:8080") { c ->
            // Verify the container started successfully
            sh "docker logs ${c.id}"
            
            // Simple health check
            def health = sh(script: "docker inspect -f '{{.State.Health.Status}}' ${c.id} 2>/dev/null || echo 'unknown'", returnStdout: true).trim()
            if (health != 'healthy' && health != 'no healthcheck') {
              error "Container failed health check: ${health}"
            }
          }
        }
      }
    }

    stage('Deploy with Docker Compose') {
      steps {
        script {
          try {
            // Stop and remove any existing containers
            sh "docker-compose -f ${COMPOSE_FILE} down --remove-orphans || true"

            // Start the application
            sh "docker-compose -f ${COMPOSE_FILE} up -d --build"

            // Wait for the application to start
            sleep 10

            // Verify the container is running
            def status = sh(script: "docker-compose -f ${COMPOSE_FILE} ps --services --filter 'status=running'", returnStdout: true).trim()
            if (!status.contains(SERVICE_NAME)) {
              error "${SERVICE_NAME} failed to start"
            }

            // Check application health
            def healthCheck = sh(
              script: "curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/actuator/health",
              returnStdout: true
            ).trim()

            if (healthCheck != '200') {
              error "Health check failed with status: ${healthCheck}"
            }

            echo "Deployment successful! Application is running on http://localhost:${APP_PORT}"

          } catch (Exception e) {
            // Get container logs if available
            def containerId = sh(script: "docker ps -q --filter 'name=${SERVICE_NAME}'", returnStdout: true).trim()
            if (containerId) {
              echo '=== Container Logs ==='
              sh "docker logs ${containerId} --tail 100 || true"
            }
            error "Deployment failed: ${e.message}"
          }
        }
      }
    }
  }

  post {
    always {
      // Clean up any running containers
      sh "docker-compose -f ${COMPOSE_FILE} down --remove-orphans || true"

      // Clean up workspace
      cleanWs()
    }

    success {
      echo 'Pipeline completed successfully!'
    }

    failure {
      echo 'Pipeline failed. Check the logs for details.'
    }
  }
}