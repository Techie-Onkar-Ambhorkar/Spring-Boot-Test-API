pipeline {
    agent any
    tools {
        maven 'Maven'
    }
    stages {
        stage('Test Maven') {
            steps {
                sh 'mvn -v'
            }
        }
    }
}