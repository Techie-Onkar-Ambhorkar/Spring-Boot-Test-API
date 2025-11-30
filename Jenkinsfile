pipeline {
    agent any

    tools {
        maven 'Maven'   // Must match the Maven tool name in Jenkins Global Tool Config
    }

    environment {
        DOCKER_IMAGE = "spring-boot-test-api:latest"
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'master',
                    url: 'https://github.com/Techie-Onkar-Ambhorkar/Spring-Boot-Test-API.git',
                    credentialsId: 'github-creds'   // Your GitHub PAT credentials ID
            }
        }

        stage('Build with Maven') {
            steps {
                sh 'mvn clean install'
            }
        }

        stage('Test') {
            steps {
                sh 'mvn test'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    sh "docker build -t $DOCKER_IMAGE ."
                }
            }
        }

        stage('Run Docker Container') {
            steps {
                script {
                    // Stop old container if running
                    sh "docker rm -f springboot || true"
                    // Run new container
                    sh "docker run -d --name springboot -p 8050:8080 $DOCKER_IMAGE"
                }
            }
        }
    }

    post {
        success {
            echo "✅ Build, Test, and Docker deployment completed successfully!"
        }
        failure {
            echo "❌ Pipeline failed. Check logs for details."
        }
    }
}