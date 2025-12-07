pipeline {
  agent any

  tools {
    maven 'Maven'
  }

  environment {
    DOCKER_IMAGE = "spring-boot-test-api:latest"
    SERVICE_NAME = "spring-boot-test-api"
    COMPOSE_FILE = "domains/pune/docker-compose.yml"
    COMPOSE_PROJECT = "pune"
    APP_PORT = "8080"
    HEALTH_TIMEOUT = "120"
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
        sh 'mvn clean install -DskipTests=false'
      }
    }

    stage('Test') {
      steps {
        sh 'mvn test'
      }
    }

    stage('Build JAR') {
      steps {
        sh 'mvn clean package -DskipTests'
      }
    }

    stage('Build Docker Image') {
      steps {
        script {
          sh "docker build -t ${DOCKER_IMAGE} ."
        }
      }
    }

    stage('Pre-clean existing container') {
      steps {
        script {
          sh '''#!/usr/bin/env bash
set -euo pipefail
NAME="${SERVICE_NAME}"
EXISTING_ID=$(docker ps -a --filter "name=^/${NAME}$" --format '{{.ID}}' || true)
if [ -n "$EXISTING_ID" ]; then
  echo "Found existing container $NAME -> $EXISTING_ID. Stopping and removing..."
  docker rm -f "$EXISTING_ID" || true
else
  echo "No existing container named $NAME"
fi
'''
        }
      }
    }

    stage('Deploy with Docker Compose') {
      steps {
        script {
          sh '''#!/usr/bin/env bash
set -euo pipefail
if [ ! -f "${COMPOSE_FILE}" ]; then
  echo "Compose file ${COMPOSE_FILE} not found"
  exit 2
fi

docker compose -p ${COMPOSE_PROJECT} -f ${COMPOSE_FILE} down --remove-orphans || true
docker compose -p ${COMPOSE_PROJECT} -f ${COMPOSE_FILE} up -d --build --force-recreate --remove-orphans
'''
        }
      }
    }

    stage('Verify deployment') {
      steps {
        script {
          sh '''#!/usr/bin/env bash
set -euo pipefail
NAME="${SERVICE_NAME}"
TIMEOUT=${HEALTH_TIMEOUT}
START=$(date +%s)

CONTAINER_ID=$(docker ps --filter "name=^/${NAME}$" --format '{{.ID}}' || true)
if [ -z "$CONTAINER_ID" ]; then
  echo "ERROR: container ${NAME} not found after compose up"
  docker ps -a --filter "name=^/${NAME}$" --format "table {{.ID}}\t{{.Status}}\t{{.Names}}"
  exit 1
fi

echo "Waiting for container $NAME ($CONTAINER_ID) to become healthy (timeout ${TIMEOUT}s)..."
while true; do
  HEALTH=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$CONTAINER_ID" || true)
  if [ -n "$HEALTH" ]; then
    echo "Health status: $HEALTH"
    if [ "$HEALTH" = "healthy" ]; then
      echo "Container is healthy"
      break
    fi
  else
    echo "No healthcheck defined; probing http://localhost:${APP_PORT}/actuator/health (or /)"
    if curl -fsS "http://localhost:${APP_PORT}/actuator/health" >/dev/null 2>&1 || curl -fsS "http://localhost:${APP_PORT}/" >/dev/null 2>&1; then
      echo "HTTP probe succeeded"
      break
    fi
  fi

  NOW=$(date +%s)
  ELAPSED=$((NOW - START))
  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    echo "Timed out waiting for healthy container"
    echo "=== Container status ==="
    docker ps -a --filter "name=^/${NAME}$" --format "table {{.ID}}\t{{.Status}}\t{{.Names}}"
    echo "=== Recent logs (tail 200) ==="
    docker logs --tail 200 "$CONTAINER_ID" || true
    exit 1
  fi
  sleep 3
done
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
      script {
        sh '''#!/usr/bin/env bash
set -euo pipefail
echo "Pipeline failed — printing docker ps and recent logs for ${SERVICE_NAME}"
docker ps -a --filter "name=^/${SERVICE_NAME}$" --format "table {{.ID}}\t{{.Status}}\t{{.Names}}" || true
ID=$(docker ps -a --filter "name=^/${SERVICE_NAME}$" --format '{{.ID}}' || true)
if [ -n "$ID" ]; then
  echo "=== Logs for $ID ==="
  docker logs --tail 500 "$ID" || true
fi
'''
      }
      echo "❌ Pipeline failed. Check logs for details."
    }
  }
}