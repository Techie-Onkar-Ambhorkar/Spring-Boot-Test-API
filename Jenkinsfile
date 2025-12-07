pipeline {
  agent any

  tools {
    maven 'Maven'
  }

  environment {
    DOCKER_IMAGE = "spring-boot-test-api:latest"
    SERVICE_NAME = "spring-boot-test-api"
    COMPOSE_FILE = "domains/learnings/docker-compose.yml"
    COMPOSE_PROJECT = "learnings"
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

    stage('Agent debug & validate') {
      steps {
        sh '''#!/usr/bin/env bash
set -euo pipefail
echo "=== Agent user and shell ==="
whoami || true
echo "SHELL=${SHELL:-unknown}"

echo "=== Docker version/info ==="
docker version || true
docker info || true

echo "=== Workspace files (top) ==="
ls -la || true
echo "=== Compose file check ==="
if [ ! -f "${COMPOSE_FILE}" ]; then
  echo "ERROR: Compose file ${COMPOSE_FILE} not found"
  exit 2
fi
echo "=== Compose config ==="
docker compose -p ${COMPOSE_PROJECT} -f ${COMPOSE_FILE} config || true

echo "=== Images (recent) ==="
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}" | head -n 50 || true
'''
      }
    }

    stage('Pre-clean existing container (preserve for diagnostics)') {
      steps {
        script {
          sh '''#!/usr/bin/env bash
set -euo pipefail
NAME="${SERVICE_NAME}"
EXISTING_ID=$(docker ps -a --filter "name=^/${NAME}$" --format '{{.ID}}' || true)
if [ -n "$EXISTING_ID" ]; then
  echo "Found existing container $NAME -> $EXISTING_ID. Stopping (preserve for logs)..."
  docker stop "$EXISTING_ID" || true
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

# ensure compose file exists
if [ ! -f "${COMPOSE_FILE}" ]; then
  echo "Compose file ${COMPOSE_FILE} not found"
  exit 2
fi

# bring down any leftover resources for this project (ignore errors)
docker compose -p ${COMPOSE_PROJECT} -f ${COMPOSE_FILE} down --remove-orphans || true

# start services (rebuild image if needed)
docker compose -p ${COMPOSE_PROJECT} -f ${COMPOSE_FILE} up -d --build --force-recreate --remove-orphans
'''
        }
      }
    }

    stage('Post-deploy quick check') {
      steps {
        script {
          sh '''#!/usr/bin/env bash
set -euo pipefail
NAME="${SERVICE_NAME}"
# show container list for this service
docker ps -a --filter "name=^/${NAME}$" --format "table {{.ID}}\t{{.Status}}\t{{.Names}}" || true

CID=$(docker ps -a --filter "name=^/${NAME}$" --format '{{.ID}}' || true)
if [ -z "$CID" ]; then
  echo "No container found for ${NAME} after compose up"
  exit 1
fi

STATUS=$(docker inspect --format='{{.State.Status}}' "$CID" || true)
echo "Container $CID status: $STATUS"
if [ "$STATUS" != "running" ]; then
  echo "Container not running — printing last 500 lines of logs"
  docker logs --tail 500 "$CID" || true
  docker inspect "$CID" --format '{{json .State}}' || true
  exit 1
fi

echo "Container appears to be running: $CID"
'''
        }
      }
    }

    stage('Verify deployment (health or HTTP probe)') {
      steps {
        script {
          sh '''#!/usr/bin/env bash
set -euo pipefail
NAME="${SERVICE_NAME}"
TIMEOUT=${HEALTH_TIMEOUT}
START=$(date +%s)

CID=$(docker ps --filter "name=^/${NAME}$" --format '{{.ID}}' || true)
if [ -z "$CID" ]; then
  echo "ERROR: container ${NAME} not found for health check"
  exit 1
fi

echo "Waiting for container $NAME ($CID) to become healthy (timeout ${TIMEOUT}s)..."
while true; do
  HEALTH=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$CID" || true)
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
    echo "=== Recent logs (tail 500) ==="
    docker logs --tail 500 "$CID" || true
    docker inspect "$CID" --format '{{json .State}}' || true
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
  docker logs --tail 1000 "$ID" || true
  echo "=== Inspect state ==="
  docker inspect "$ID" --format '{{json .State}}' || true
fi
'''
      }
      echo "❌ Pipeline failed. Check logs for details."
    }
  }
}