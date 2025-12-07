pipeline {
    agent any

    environment {
        DOCKER_IMAGE = "spring-boot-test-api"
        DOCKER_TAG = "latest"
        SERVICE_NAME = "spring-boot-test-api"
        COMPOSE_FILE = "docker-compose.yml"
        COMPOSE_PROJECT = "spring-boot-test"
        APP_PORT = "8080"
        GIT_URL = "https://github.com/Techie-Onkar-Ambhorkar/Spring-Boot-Test-API.git"
        GIT_BRANCH = "master"
        ACTIVE_PROFILE = ""  // Empty string for default profile
    }

    stages {
        stage('Cleanup Before Build') {
            steps {
                script {
                    sh '''
                        docker-compose -f ${COMPOSE_FILE} down -v --remove-orphans || true
                        docker system prune -f || true
                        docker volume prune -f || true
                    '''
                }
            }
        }

        stage('Checkout Code') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: "*/${GIT_BRANCH}"]],
                    extensions: [[$class: 'CleanCheckout']],
                    userRemoteConfigs: [[
                        url: GIT_URL
                    ]]
                ])
            }
        }

        stage('Build with Maven') {
            steps {
                script {
                    sh "mvn clean package -DskipTests"
                }
            }
        }

        stage('Build and Deploy Docker') {
            steps {
                script {
                    // Create necessary directories
                    sh 'mkdir -p logs heapdumps'
                    sh 'chmod -R 777 logs/ heapdumps/ || true'

                    // Build with the active profile if set
                    def buildArgs = env.ACTIVE_PROFILE?.trim() ? "--build-arg ACTIVE_PROFILE=${env.ACTIVE_PROFILE}" : ""

                    // Build and start the application
                    sh "docker-compose -f ${COMPOSE_FILE} build ${buildArgs}"
                    sh "docker-compose -f ${COMPOSE_FILE} up -d"

                    // Wait for the application to start
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
                }
            }
        }
    }

    post {
        always {
            script {
                // Clean up Docker resources
                sh "docker-compose -f ${COMPOSE_FILE} down -v --remove-orphans || true"
                sh 'docker system prune -f || true'
                sh 'docker volume prune -f || true'
            }
        }
    }
}