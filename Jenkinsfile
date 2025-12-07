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
      steps {
        script {
          try {
            // Install Docker Compose if not already installed
            sh '''
              if ! command -v docker-compose &> /dev/null; then
                echo "Installing Docker Compose..."
                sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                sudo chmod +x /usr/local/bin/docker-compose
              fi
            '''

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