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
    stage('Cleanup Before Checkout') {
      steps {
        script {
          // First, stop any running containers
          sh 'docker-compose -f docker-compose.yml down -v --remove-orphans || true'

          // Then clean up any dangling resources
          sh 'docker system prune -f || true'

          // Ensure we have a clean workspace
          dir('.') {
            deleteDir()
          }
        }
      }
    }

    stage('Checkout') {
      steps {
        script {
          // Create fresh directories with proper permissions
          sh 'mkdir -p logs heapdumps'
          sh 'chmod -R 777 logs/ heapdumps/ || true'

          // Then checkout the code
          git branch: 'main',
              url: 'https://github.com/Techie-Onkar-Ambhorkar/Spring-Boot-Test-API.git',
              credentialsId: 'github-creds'
        }
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
          sh "docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} ."
        }
      }
    }

    stage('Deploy with Docker Compose') {
      steps {
        script {
          try {
            sh "docker-compose -f ${COMPOSE_FILE} up -d --build"
            sleep 30

            def containerId = sh(script: "docker ps -q --filter 'name=${SERVICE_NAME}'", returnStdout: true).trim()
            if (!containerId) {
              error "${SERVICE_NAME} container is not running"
            }

            echo '=== Container Logs ==='
            sh "docker logs ${containerId} --tail 100 || true"

            def healthCheck = sh(
              script: "docker exec ${containerId} curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/actuator/health",
              returnStatus: true
            )

            if (healthCheck != 0) {
              error "Health check failed. Application did not start properly."
            }

            echo "Deployment successful! Application is running on http://localhost:${APP_PORT}"

          } catch (Exception e) {
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
        try {
          // Clean up containers and volumes
          sh "docker-compose -f ${COMPOSE_FILE} down -v --remove-orphans || true"
          sh 'docker system prune -f || true'

          // Clean up workspace
          cleanWs()
        } catch (Exception e) {
          echo "Error during cleanup: ${e.message}"
        }
      }
    }
  }
}