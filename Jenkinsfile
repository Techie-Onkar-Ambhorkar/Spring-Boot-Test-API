pipeline {
  agent any

  tools {
    maven 'Maven'
  }

  environment {
    DOCKER_IMAGE   = "spring-boot-test-api:latest"
    SERVICE_NAME   = "spring-boot-test-api"
    COMPOSE_FILE   = "domains/learnings/docker-compose.yml"
    COMPOSE_PROJECT= "learnings"
    APP_PORT       = "8080"
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

    stage('Agent debug & validate') {
      steps {
        sh '''#!/usr/bin/env bash
set -euo pipefail
echo "=== Agent user and shell ==="
whoami || true
echo "SHELL=${SHELL:-unknown}"
echo "WORKSPACE=${WORKSPACE:-unknown}"
echo "PWD=$(pwd)"

echo "=== Docker version/info ==="
docker version || true
docker info || true

echo "=== Workspace top-level files ==="
ls -la || true

COMPOSE_ABS="${WORKSPACE}/${COMPOSE_FILE}"
echo "Looking for compose file at: ${COMPOSE_ABS}"
if [ -f "${COMPOSE_ABS}" ]; then
  echo "=== Compose config (expanded) ==="
  docker compose -p "${COMPOSE_PROJECT}" -f "${COMPOSE_ABS}" config || true
else
  echo "WARNING: Compose file ${COMPOSE_ABS} not found. Skipping compose validation."
fi

echo "=== Images (recent) ==="
docker images | head -n 50 || true
'''
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
        sh '''#!/usr/bin/env bash
set -euo pipefail
echo "=== Docker build start ==="
if ! docker build -t "${DOCKER_IMAGE}" . 2>&1 | tee docker-build.log; then
  echo "ERROR: docker build failed. Last 200 lines of build log:"
  tail -n 200 docker-build.log || true
  exit 1
fi
echo "=== Docker build completed ==="
'''
      }
    }

    stage('Pre-clean existing container (stop, preserve logs)') {
      steps {
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

    stage('Deploy with Docker Compose') {
      steps {
        sh '''#!/usr/bin/env bash
set -euo pipefail
COMPOSE_ABS="${WORKSPACE}/${COMPOSE_FILE}"

if [ -f "${COMPOSE_ABS}" ]; then
  echo "Bringing down any leftover resources for project ${COMPOSE_PROJECT} (ignore errors)"
  docker compose -p "${COMPOSE_PROJECT}" -f "${COMPOSE_ABS}" down --remove-orphans || true

  echo "Starting compose (recreate)"
  docker compose -p "${COMPOSE_PROJECT}" -f "${COMPOSE_ABS}" up -d --force-recreate --remove-orphans
else
  echo "WARNING: Compose file not found, skipping Docker Compose deploy."
fi
'''
      }
    }

    stage('Post-deploy quick check') {
      steps {
        sh '''#!/usr/bin/env bash
set -euo pipefail
NAME="${SERVICE_NAME}"

echo "=== Containers matching ${NAME} ==="
docker ps -a --filter "name=^/${NAME}$" --format "table {{.ID}}\t{{.Status}}\t{{.Names}}" || true

CID=$(docker ps -a --filter "name=^/${NAME}$" --format '{{.ID}}' || true)
if [ -z "$CID" ]; then
  echo "No container found for ${NAME} after compose up"
  echo "=== All containers (recent) ==="
  docker ps -a --format "table {{.ID}}\t{{.Status}}\t{{.Names}}\t{{.Image}}" | head -n 200 || true
  exit 1
fi

STATUS=$(docker inspect --format='{{.State.Status}}' "$CID" || true)
echo "Container $CID status: $STATUS"
if [ "$STATUS" != "running" ]; then
  echo "Container not running — printing last 1000 lines of logs"
  docker logs --tail 1000 "$CID" || true
  echo "=== Inspect state ==="
  docker inspect "$CID" --format '{{json .State}}' || true
  exit 1
fi

echo "Container appears to be running: $CID"
'''
      }
    }

    stage('Verify deployment (health or HTTP probe)') {
      steps {
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
    echo "=== Recent logs (tail 1000) ==="
    docker logs --tail 1000 "$CID" || true
    docker inspect "$CID" --format '{{json .State}}' || true
    exit 1
  fi
  sleep 3
done
'''
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
echo "Pipeline failed — printing docker info, images, compose config, and recent logs for ${SERVICE_NAME}"

docker version || true
docker info || true

echo "=== Images (top 50) ==="
docker images | head -n 50 || true

COMPOSE_ABS="${WORKSPACE}/${COMPOSE_FILE}"
if [ -f "${COMPOSE_ABS}" ]; then
  echo "=== Compose config ==="
  docker compose -p "${COMPOSE_PROJECT}" -f "${COMPOSE_ABS}" config || true
fi

echo "=== Container list for ${SERVICE_NAME} ==="
docker ps -a --filter "name=^/${SERVICE_NAME}$" --format "table {{.ID}}\t{{.Status}}\t{{.Names}}\t{{.Image}}" || true

ID=$(docker ps -a --filter "name=^/${SERVICE_NAME}$" --format '{{.ID}}' || true)
if [ -n "$ID" ]; then
  echo "=== Logs for $ID ==="
  docker logs --tail 2000 "$ID" || true
  echo "=== Inspect state ==="
  docker inspect "$ID" --format '{{json .State}}' || true
fi

echo "=== Last lines of docker-build.log (if present) ==="
if [ -f docker-build.log ]; then
  tail -n 500 docker-build.log || true
fi
'''
      }
      echo "❌ Pipeline failed. Check logs for details."