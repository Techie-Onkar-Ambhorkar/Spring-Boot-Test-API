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
    GIT_URL         = "https://github.com/Techie-Onkar-Ambhorkar/Spring-Boot-Test-API.git"
    GIT_BRANCH      = "master"
  }

  stages {
    stage('Checkout') {
      steps {
        script {
          // Clean workspace first
          cleanWs()
          
          // Checkout the code using checkout step for better control
          checkout([
            $class: 'GitSCM',
            branches: [[name: "*/${GIT_BRANCH}"]],
            extensions: [[$class: 'CleanCheckout']],
            userRemoteConfigs: [[
              url: GIT_URL,
              credentialsId: ''  // Remove credentials for public repo
            ]]
          ])
          
          // Verify files were checked out
          sh 'ls -la'
        }
      }
    }

    stage('Cleanup Docker') {
      steps {
        script {
          // Stop and remove any running containers
          sh '''
            # Stop and remove any running containers
            if [ -f docker-compose.yml ]; then
              docker-compose -f docker-compose.yml down -v --remove-orphans || true
            fi
            
            # Clean up Docker resources
            docker system prune -f || true
            docker volume prune -f || true
          '''
        }
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
            // Create necessary directories with proper permissions
            sh 'mkdir -p logs heapdumps'
            sh 'chmod -R 777 logs/ heapdumps/ || true'

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
          }
        }
      }
    }
  }

  post {
    always {
      script {
        // Clean up Docker resources
        sh 'docker-compose -f docker-compose.yml down -v --remove-orphans || true'
        sh 'docker system prune -f || true'
        sh 'docker volume prune -f || true'
      }
    }
  }
}