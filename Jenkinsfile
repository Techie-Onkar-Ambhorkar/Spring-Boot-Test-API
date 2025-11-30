pipeline {
    agent any
    
    environment {
        // Define environment variables here
        APP_NAME = 'Spring-Boot-Test-Api'
        VERSION = '1.0.0'
        DOCKER_IMAGE = "${env.APP_NAME}:${env.BUILD_NUMBER}"
        DOCKER_TAG = "latest"
    }

    stages {
            stage('Checkout') {
                steps {
                    git branch: 'main', url: 'https://github.com/Techie-Onkar-Ambhorkar/Spring-Boot-Test-API.git'
                }
            }

            stage('Build with Maven') {
                steps {
                    sh 'mvn clean package -DskipTests'
                }
            }

            stage('Build Docker Image') {
                steps {
                    sh "docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} ."
                }
            }

            stage('Deploy to Docker') {
                steps {
                    sh "docker rm -f springboot-app || true"
                    sh "docker run -d --name springboot-app -p 8050:8080 ${DOCKER_IMAGE}:${DOCKER_TAG}"
                }
            }
        }

        post {
            success {
                echo "Spring Boot app deployed successfully in Docker!"
            }
            failure {
                echo "Build or deployment failed."
            }
        }

}
