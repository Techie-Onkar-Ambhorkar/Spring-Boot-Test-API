pipeline {
  agent any  // This will use any available agent

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
        cleanWs()
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

    stage('Docker Build & Deploy') {
      agent {
        docker {
          image 'docker:20.10.16-dind'  // Use Docker-in-Docker for container operations
          args '-v /var/run/docker.sock:/var/run/docker.sock'  // Mount Docker socket
          reuseNode true
        }
      }
      steps {
        script {
          try {
            // Install docker-compose
            sh 'apk add --no-cache docker-compose'

            // Stop and remove any existing containers
            sh 'docker-compose -f docker-compose.yml down -v --remove-orphans || true'

            // Build and start the application
            sh 'docker-compose -f docker-compose.yml up -d --build'
            sleep 30

            // Verify container is running
            def containerId = sh(script: "docker ps -q --filter 'name=${SERVICE_NAME}'", returnStdout: true).trim()
            if (!containerId) {
              error "${SERVICE_NAME} container is not running"
            }

            // Check application health
            def healthCheck = sh(
              script: "docker exec ${containerId} curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/actuator/health",
              returnStatus: true
            )

            if (healthCheck != 0) {
              error "Health check failed. Application did not start properly."
            }

            echo "Deployment successful! Application is running on http://localhost:${APP_PORT}"

          } catch (Exception e) {
            sh 'docker ps -a || true'
            sh 'docker-compose -f docker-compose.yml logs --tail=100 || true'
            error "Deployment failed: ${e.message}"
          } finally {
            // Clean up Docker resources
            sh 'docker-compose -f docker-compose.yml down -v --remove-orphans || true'
          }
        }
      }
    }
  }

  post {
    always {
      cleanWs()
    }
  }
}