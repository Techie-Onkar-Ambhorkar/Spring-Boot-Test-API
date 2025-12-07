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
        // Deployment tracking
        OLD_CONTAINER = ""
        NEW_CONTAINER = ""
        BUILD_SUCCESS = "false"
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
                script {
                    try {
                        sh "mvn clean package -DskipTests"
                        BUILD_SUCCESS = "true"
                    } catch (Exception e) {
                        error "Build failed: ${e.message}"
                    }
                }
            }
        }

        stage('Deploy with Rollback') {
            when {
                expression { BUILD_SUCCESS == "true" }
            }
            steps {
                script {
                    try {
                        // Get current running container (if any)
                        OLD_CONTAINER = sh(script: "docker ps -q --filter 'name=${SERVICE_NAME}'", returnStdout: true).trim()

                        echo "=== Starting deployment of new container ==="

                        // Create necessary directories
                        sh """
                            mkdir -p logs heapdumps
                            chmod -R 777 logs/ heapdumps/ || true
                        """

                        // Build the new Docker image
                        def buildArgs = env.ACTIVE_PROFILE?.trim() ? "--build-arg ACTIVE_PROFILE=${env.ACTIVE_PROFILE}" : ""
                        sh "docker-compose -f ${COMPOSE_FILE} build --no-cache ${buildArgs}"

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

                        // If we got here, the new container is healthy
                        echo "New container is healthy: ${NEW_CONTAINER}"

                        // Only now, clean up the old container if it existed
                        if (OLD_CONTAINER?.trim()) {
                            echo "Cleaning up old container: ${OLD_CONTAINER}"
                            sh "docker stop ${OLD_CONTAINER} || true"
                            sh "docker rm -f ${OLD_CONTAINER} || true"
                            echo "Old container cleaned up successfully"
                        }

                        DEPLOYMENT_SUCCESS = "true"
                        echo "Deployment successful! Application is available at: http://localhost:${APP_PORT}"

                    } catch (Exception e) {
                        error "Deployment failed: ${e.message}"
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

                if (BUILD_SUCCESS == "true" && DEPLOYMENT_SUCCESS != "true") {
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

                // Clean up unused images only if build was successful
                if (BUILD_SUCCESS == "true") {
                    echo "=== Cleaning up unused Docker resources ==="
                    sh "docker system prune -f || true"
                    sh "docker volume prune -f || true"
                }
            }
        }
    }
}