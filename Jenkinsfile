pipeline {
    agent any

    environment {
        DOCKER_IMAGE = "spring-boot-test-api"
        DOCKER_TAG = "latest"
        SERVICE_NAME = "spring-boot-test-api"
        COMPOSE_FILE = "docker-compose.yml"
        COMPOSE_PROJECT = "spring-boot-test"
        APP_PORT = "8050"
        GIT_URL = "https://github.com/Techie-Onkar-Ambhorkar/Spring-Boot-Test-API.git"
        GIT_BRANCH = "master"
        ACTIVE_PROFILE = ""
        // Add these new variables
        OLD_CONTAINER = ""
        NEW_CONTAINER = ""
        DEPLOYMENT_SUCCESS = "false"
    }

    stages {
        stage('Check Prerequisites') {
            steps {
                script {
                    sh """
                        echo "=== Docker System Info ==="
                        docker info
                        echo "\\n=== Docker Images ==="
                        docker images
                        echo "\\n=== Docker Containers ==="
                        docker ps -a
                    """

                    def mvnInstalled = sh(script: 'command -v mvn || echo "not_found"', returnStdout: true).trim()
                    def dockerInstalled = sh(script: 'command -v docker || echo "not_found"', returnStdout: true).trim()

                    if (mvnInstalled == 'not_found' || dockerInstalled == 'not_found') {
                        error "Required tools not found. Maven: ${mvnInstalled == 'not_found' ? 'MISSING' : 'OK'}, Docker: ${dockerInstalled == 'not_found' ? 'MISSING' : 'OK'}"
                    }

                    sh 'mvn -v'
                    sh 'docker --version'
                    sh 'docker-compose --version'
                }
            }
        }

        stage('Cleanup Before Build') {
            steps {
                script {
                    // Get current running container if any
                    OLD_CONTAINER = sh(script: "docker ps -q --filter 'name=${SERVICE_NAME}'", returnStdout: true).trim()

                    sh """
                        echo "=== Cleaning up old deployments ==="
                        docker-compose -f ${COMPOSE_FILE} stop || true
                        docker-compose -f ${COMPOSE_FILE} rm -f || true
                        docker system prune -f || true
                        docker volume prune -f || true
                    """
                }
            }
        }

        stage('Checkout Code') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: "*/${GIT_BRANCH}"]],
                    extensions: [[$class: 'CleanCheckout']],
                    userRemoteConfigs: [[url: GIT_URL]]
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
                    sh """
                        mkdir -p logs heapdumps
                        chmod -R 777 logs/ heapdumps/ || true
                    """

                    // Build the new Docker image
                    def buildArgs = env.ACTIVE_PROFILE?.trim() ? "--build-arg ACTIVE_PROFILE=${env.ACTIVE_PROFILE}" : ""
                    sh "docker-compose -f ${COMPOSE_FILE} build ${buildArgs}"

                    // Start the new container
                    sh """
                        docker-compose -f ${COMPOSE_FILE} up -d
                        sleep 10
                    """

                    // Get new container ID
                    NEW_CONTAINER = sh(script: "docker ps -q --filter 'name=${SERVICE_NAME}'", returnStdout: true).trim()
                    if (!NEW_CONTAINER) {
                        error "New container failed to start"
                    }

                    // Check container logs
                    sh "docker logs ${NEW_CONTAINER}"

                    // Health check
                    def healthCheck = sh(
                        script: "docker exec ${NEW_CONTAINER} curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/actuator/health || echo '503'",
                        returnStdout: true
                    ).trim()

                    if (healthCheck != "200") {
                        error "Health check failed with status: ${healthCheck}"
                    }

                    // Mark deployment as successful
                    DEPLOYMENT_SUCCESS = "true"
                    echo "Deployment successful! New container ID: ${NEW_CONTAINER}"

                    // Clean up old container if it exists and new deployment is successful
                    if (OLD_CONTAINER?.trim()) {
                        echo "Cleaning up old container: ${OLD_CONTAINER}"
                        sh "docker stop ${OLD_CONTAINER} || true"
                        sh "docker rm -f ${OLD_CONTAINER} || true"
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                echo "=== Final Container Status ==="
                sh "docker ps -a | grep ${SERVICE_NAME} || true"

                if (DEPLOYMENT_SUCCESS != "true") {
                    echo "=== Deployment Failed - Rolling Back ==="
                    // Stop and remove the failed new container
                    if (NEW_CONTAINER?.trim()) {
                        sh "docker stop ${NEW_CONTAINER} || true"
                        sh "docker rm -f ${NEW_CONTAINER} || true"
                    }

                    // Restart the old container if it existed
                    if (OLD_CONTAINER?.trim()) {
                        echo "Restoring previous container: ${OLD_CONTAINER}"
                        sh "docker start ${OLD_CONTAINER} || true"
                    }

                    // Final status after rollback
                    echo "=== Status After Rollback ==="
                    sh "docker ps -a | grep ${SERVICE_NAME} || true"
                }

                // Clean up unused images
                sh "docker image prune -f || true"
            }
        }
    }
}