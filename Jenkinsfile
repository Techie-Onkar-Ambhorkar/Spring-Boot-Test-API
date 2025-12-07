pipeline {
    agent any  // Use any available agent

    environment {
        DOCKER_IMAGE = "spring-boot-test-api"
        DOCKER_TAG = "latest"
        SERVICE_NAME = "spring-boot-test-api"  // Make sure this matches your docker-compose service name
        COMPOSE_FILE = "docker-compose.yml"
        COMPOSE_PROJECT = "spring-boot-test"
        APP_PORT = "8080"
        GIT_URL = "https://github.com/Techie-Onkar-Ambhorkar/Spring-Boot-Test-API.git"
        GIT_BRANCH = "master"
        ACTIVE_PROFILE = ""  // Empty string for default profile
    }

    stages {
        stage('Check Prerequisites') {
            steps {
                script {
                    // Check if Maven is available
                    def mvnInstalled = sh(script: 'command -v mvn || echo "not_found"', returnStdout: true).trim()
                    if (mvnInstalled == 'not_found') {
                        error "Maven is not installed on this agent. Please install Maven or use an agent with Maven pre-installed."
                    }

                    // Check if Docker is available
                    def dockerInstalled = sh(script: 'command -v docker || echo "not_found"', returnStdout: true).trim()
                    if (dockerInstalled == 'not_found') {
                        error "Docker is not installed on this agent. Please install Docker or use an agent with Docker pre-installed."
                    }

                    // Print versions
                    sh 'mvn -v'
                    sh 'docker --version'
                    sh 'docker-compose --version'
                }
            }
        }

        stage('Cleanup Before Build') {
            steps {
                script {
                    sh '''
                        # Stop and remove any existing containers and networks
                        docker-compose -f ${COMPOSE_FILE} down -v --remove-orphans || true

                        # Force remove any container with the same name
                        docker rm -f ${SERVICE_NAME} || true

                        # Clean up unused resources
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
                sh "mvn clean package -DskipTests"
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

                    // Build the Docker image
                    sh "docker-compose -f ${COMPOSE_FILE} build ${buildArgs}"

                    // Start the container in detached mode
                    sh "docker-compose -f ${COMPOSE_FILE} up -d"

                    // Wait for the container to start
                    sleep 10

                    // Verify container is running
                    def containerId = sh(script: "docker ps -q --filter 'name=${SERVICE_NAME}'", returnStdout: true).trim()
                    if (!containerId) {
                        error "Container ${SERVICE_NAME} failed to start"
                    }

                    // Check container logs
                    sh "docker logs ${SERVICE_NAME}"

                    // Health check
                    def healthCheck = sh(
                        script: "docker exec ${SERVICE_NAME} curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/actuator/health || echo '503'",
                        returnStdout: true
                    ).trim()

                    if (healthCheck != "200") {
                        error "Health check failed with status: ${healthCheck}"
                    }

                    echo "Container ${SERVICE_NAME} is running and healthy"
                    echo "Application is available at: http://localhost:${APP_PORT}"
                }
            }
        }
    }

    post {
        always {
            script {
                // Clean up Docker resources
                sh """
                    echo "Cleaning up Docker resources..."
                    docker-compose -f ${COMPOSE_FILE} down -v --remove-orphans || true
                    docker rm -f ${SERVICE_NAME} || true
                    docker system prune -f || true
                    docker volume prune -f || true
                    echo "Cleanup complete"
                """
            }
        }
    }
}