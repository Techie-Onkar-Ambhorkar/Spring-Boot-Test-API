pipeline {
  agent any
  tools { maven 'Maven' }
  stages {
    stage('Checkout') {
      steps { git 'https://github.com/your/repo.git' }
    }
    stage('Build') {
      steps { sh 'mvn clean install' }
    }
    stage('Test') {
      steps { sh 'mvn test' }
    }
  }
}