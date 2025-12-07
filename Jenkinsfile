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
    stage('Prepare Workspace') {
      steps {
        script {
          // Clean up any existing containers and volumes
          sh 'docker-compose -f docker-compose.yml down -v --remove-orphans || true'

          // Remove any existing directories that might cause permission issues
          sh 'rm -rf logs/ heapdumps/ || true'
          sh 'mkdir -p logs heapdumps'
          sh 'chmod -R 777 logs/ heapdumps/ || true'
        }
      }
    }

    stage('Checkout') {
      steps {
        git branch: 'main',
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
          // Build the Docker image directly using shell commands
          sh "docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} ."
        }
      }
    }

    stage('Deploy with Docker Compose') {
      steps {
        script {
          try {
            // Start the application
            sh "docker-compose -f ${COMPOSE_FILE} up -d --build"

            // Wait for the application to start
            sleep 30

            // Get container logs for debugging
            def containerId = sh(script: "docker ps -q --filter 'name=${SERVICE_NAME}'", returnStdout: true).trim()
            if (!containerId) {
              error "${SERVICE_NAME} container is not running"
            }

            // Show container logs
            echo '=== Container Logs ==='
            sh "docker logs ${containerId} --tail 100 || true"

            // Check application health (using container's internal network)
            def healthCheck = sh(
              script: "docker exec ${containerId} curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/actuator/health",
              returnStatus: true
            )

            if (healthCheck != 0) {
              error "Health check failed. Application did not start properly."
            }

            echo "Deployment successful! Application is running on http://localhost:${APP_PORT}"

          } catch (Exception e) {
            // Get container logs if available
            def containerId = sh(script: "docker ps -q --filter 'name=${SERVICE_NAME}'", returnStdout: true).trim()
            if (containerId) {
              echo '=== Error Container Logs ==='
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
      script {
        // Save container logs before cleanup
        try {
          def containerId = sh(script: "docker ps -aq --filter 'name=${SERVICE_NAME}'", returnStdout: true).trim()
          if (containerId) {
            echo '=== Final Container Logs ==='
            sh "docker logs ${containerId} --tail 500 || true"
            sh "docker-compose -f ${COMPOSE_FILE} down -v --remove-orphans || true"
          }
          // Clean up any remaining files
          sh 'rm -rf logs/ heapdumps/ || true'
        } catch (Exception e) {
          echo "Error during cleanup: ${e.message}"
        }
      }
    }
  }
}