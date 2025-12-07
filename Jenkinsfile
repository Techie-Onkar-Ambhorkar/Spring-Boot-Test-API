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
                    sh """
                        echo "=== Cleaning up Docker resources ==="
                        docker-compose -f ${COMPOSE_FILE} down -v --remove-orphans || true
                        docker rm -f ${SERVICE_NAME} || true
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
                    sh """
                        mkdir -p logs heapdumps
                        chmod -R 777 logs/ heapdumps/ || true
                    """

                    def buildArgs = env.ACTIVE_PROFILE?.trim() ? "--build-arg ACTIVE_PROFILE=${env.ACTIVE_PROFILE}" : ""
                    sh "docker-compose -f ${COMPOSE_FILE} build ${buildArgs}"

                    sh """
                        docker-compose -f ${COMPOSE_FILE} up -d
                        sleep 10
                    """

                    def containerId = sh(script: "docker ps -q --filter 'name=${SERVICE_NAME}'", returnStdout: true).trim()
                    if (!containerId) {
                        sh "docker logs ${SERVICE_NAME} || true"
                        error "Container ${SERVICE_NAME} failed to start"
                    }

                    sh "docker logs ${SERVICE_NAME}"

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
                echo "=== Final Container Status ==="
                sh "docker ps -a | grep ${SERVICE_NAME} || true"
                echo "=== Container Logs ==="
                sh "docker logs ${SERVICE_NAME} || true"
            }
        }
    }
}