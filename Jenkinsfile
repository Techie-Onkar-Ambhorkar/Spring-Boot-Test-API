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
    WORKSPACE_PATH = "${env.WORKSPACE}"
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
if [ ! -f "${COMPOSE_ABS}" ]; then
  echo "ERROR: Compose file ${COMPOSE_ABS} not found"
  echo "Listing domains directory:"
  ls -la "${WORKSPACE}/domains" || true
  exit 2
fi

echo "=== Compose config (expanded) ==="
docker compose -p ${COMPOSE_PROJECT} -f "${COMPOSE_ABS}" config || true

echo "=== Images (recent) ==="
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}" | head -n 50 || true
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
        script {
          // Capture full build output and fail if build fails
          sh '''#!/usr/bin/env bash
set -euo pipefail
echo "=== Docker build start ==="
docker build -t ${DOCKER_IMAGE} . 2>&1 | tee docker-build.log
BUILD_EXIT=${PIPESTATUS[0]:-0}
if [ "$BUILD_EXIT" -ne 0 ]; then
  echo "ERROR: docker build failed (exit $BUILD_EXIT). Last 200 lines of build log:"
  tail -n 200 docker-build.log || true
  exit $BUILD_EXIT
fi
echo "=== Docker build completed ==="
'''
        }
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
        script {
          sh '''#!/usr/bin/env bash
set -euo pipefail
COMPOSE_ABS="${WORKSPACE}/${COMPOSE_FILE}"

echo "Bringing down any leftover resources for project ${COMPOSE_PROJECT} (ignore errors)"
docker compose -p ${COMPOSE_PROJECT} -f "${COMPOSE_ABS}" down --remove-orphans || true

echo "Starting compose (rebuild disabled here because image already built)"
docker compose -p ${COMPOSE_PROJECT} -f "${COMPOSE_ABS}" up -d --force-recreate --remove-orphans
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
COMPOSE_ABS="${WORKSPACE}/${COMPOSE_FILE}"

echo "=== Containers matching ${NAME} ==="
docker ps -a --filter "name=^/${NAME}$" --format "table {{.ID}}\t{{.Status}}\t{{.Names}}" || true

CID=$(docker ps -a --filter "name=^/${NAME}$" --format '{{.ID}}' || true)
if [ -z "$CID" ]; then
  echo "No container found for ${NAME} after compose up"
  echo "=== All containers (recent) ==="
  docker ps -a --format "table {{.ID}}\t{{.Status}}\t{{.Names}}\t{{.Image}}" | head -n 200 || true