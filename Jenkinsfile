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
                git branch: 'master', url: 'https://github.com/onkyarity/spring-boot-test-api.git'
            }
        }
        
        /* stage('Build') {
            steps {
                // Build the application using Maven wrapper
                sh './mvnw clean package -DskipTests'
            }
            
            post {
                success {
                    echo 'Build successful!'
                }
                failure {
                    echo 'Build failed!'
                }
            }
        } */
        
        /* stage('Test') {
            steps {
                // Run tests
                sh './mvnw test'
                
                // Archive test results
                junit '**//* target/surefire-reports *//** /* *//*.xml'
            }
        } */
        
        /* stage('Static Code Analysis') {
            steps {
                // Run static code analysis (e.g., Checkstyle, PMD, SpotBugs)
                sh './mvnw checkstyle:check pmd:pmd spotbugs:check'
                
                // Archive reports
                archiveArtifacts '**//* target *//*.xml,**//* target *//*.txt'
            }
        } */
        
        /* stage('Docker Build') {
            when {
                // Only build Docker image for main branch
                branch 'main' or branch 'master'
            }
            steps {
                script {
                    // Build Docker image
                    docker.build("${env.DOCKER_IMAGE}")
                }
            }
        } */
    }
    
    /* post {
        always {
            // Clean up workspace after build
            cleanWs()
        }
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    } */

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
