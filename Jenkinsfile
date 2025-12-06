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
                    credentialsId: 'github-creds'
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

        stage('Deploy with Docker Compose') {
            steps {
                script {
                    // Stop old containers and redeploy
                    sh '''
                      docker compose down || true
                      docker compose up -d --build
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "✅ Build, Test, and Docker Compose deployment completed successfully!"
        }
        failure {
            echo "❌ Pipeline failed. Check logs for details."
        }
    }
}