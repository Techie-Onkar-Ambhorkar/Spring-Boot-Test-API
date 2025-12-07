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
        script {
            try {
                // Clean up any existing containers
                sh '''#!/usr/bin/env bash
                set -x
                echo "=== Starting deployment with Docker Compose ==="
                echo "Current directory: $(pwd)"
                echo "Docker Compose file: ${WORKSPACE}/${COMPOSE_FILE}"
                
                # List all files in the workspace
                echo "=== Workspace contents ==="
                find . -type f | sort
                
                # Clean up any existing containers
                echo "=== Cleaning up existing containers ==="
                docker-compose -f "${WORKSPACE}/${COMPOSE_FILE}" down -v --remove-orphans 2>/dev/null || true
                '''
                
                // Build and start the service
                sh '''#!/usr/bin/env bash
                set -e
                echo "=== Building and starting services ==="
                if ! docker-compose -f "${WORKSPACE}/${COMPOSE_FILE}" up -d --build --force-recreate; then
                    echo "=== Docker Compose up failed, showing logs ==="
                    docker-compose -f "${WORKSPACE}/${COMPOSE_FILE}" logs --tail=100
                    exit 1
                fi
                '''
                
                // Get container ID
                def containerId = sh(script: '''#!/usr/bin/env bash
                    docker ps -q --filter "name=${SERVICE_NAME}"
                ''', returnStdout: true).trim()
                
                if (!containerId) {
                    error "No container found with name ${SERVICE_NAME}"
                }
                
                echo "=== Container ${containerId} details ==="
                sh "docker inspect ${containerId}"
                
                // Wait for container to be running
                echo "=== Waiting for container to be healthy ==="
                def maxRetries = 30
                def retryCount = 0
                def isHealthy = false
                
                while (retryCount < maxRetries) {
                    def status = sh(script: """#!/usr/bin/env bash
                        docker inspect -f '{{.State.Status}}' ${containerId} 2>/dev/null || echo "unknown"
                    """, returnStdout: true).trim()
                    
                    echo "Container status: ${status}"
                    
                    if (status == "running") {
                        // Check health status if healthcheck is configured
                        def health = sh(script: """#!/usr/bin/env bash
                            docker inspect -f '{{.State.Health.Status}}' ${containerId} 2>/dev/null || echo "no-healthcheck"
                        """, returnStdout: true).trim()
                        
                        if (health == "healthy" || health == "no-healthcheck") {
                            isHealthy = true
                            break
                        }
                        echo "Container is running but not yet healthy (${health})"
                    }
                    
                    retryCount++
                    if (retryCount >= maxRetries) {
                        break
                    }
                    
                    sleep(2)
                }
                
                if (!isHealthy) {
                    echo "=== Container failed to become healthy ==="
                    echo "=== Container logs ==="
                    sh "docker logs --tail 200 ${containerId} || true"
                    echo "=== Container inspect ==="
                    sh "docker inspect ${containerId} || true"
                    error "Container failed to become healthy after ${maxRetries} retries"
                }
                
                // Check application logs
                echo "=== Application logs (last 50 lines) ==="
                sh "docker logs --tail 50 ${containerId} || true"
                
                // Check if application is responding
                echo "=== Checking application health ==="
                def healthCheck = sh(script: """#!/usr/bin/env bash
                    curl -f http://localhost:8050/actuator/health || (echo "Health check failed" && exit 1)
                """, returnStatus: true)
                
                if (healthCheck != 0) {
                    echo "=== Health check failed ==="
                    echo "=== Full container logs ==="
                    sh "docker logs ${containerId} || true"
                    echo "=== Checking container processes ==="
                    sh "docker top ${containerId} || true"
                    error "Application health check failed"
                }
                
                echo "=== Deployment successful ==="
                
            } catch (Exception e) {
                echo "=== Deployment failed: ${e.message} ==="
                // Try to get container logs even if the main deployment failed
                sh '''#!/usr/bin/env bash
                echo "=== Attempting to get container logs ==="
                CID=$(docker ps -a --filter "name=${SERVICE_NAME}" --format '{{.ID}}' | head -1) || true
                if [ -n "$CID" ]; then
                    echo "=== Container logs ==="
                    docker logs --tail 200 "$CID" 2>/dev/null || true
                    echo "=== Container inspect ==="
                    docker inspect "$CID" 2>/dev/null || true
                fi
                '''
                throw e
            }
        }
      }
    }

    stage('Debug container logs') {
      steps {
        sh '''#!/usr/bin/env bash
set -euo pipefail
CID=$(docker ps -a --filter "name=^/${SERVICE_NAME}$" --format '{{.ID}}' || true)
if [ -n "$CID" ]; then
  echo "=== Initial logs for $CID ==="
  docker logs --tail 200 "$CID" || true
else
  echo "No container found for ${SERVICE_NAME}"
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
docker ps -a --filter "name=^/${NAME}" --format "table {{.ID}}\t{{.Status}}\t{{.Names}}\t{{.Image}}" || true

# Give the container some time to start
sleep 10

# Get the container ID with more flexible matching
CID=$(docker ps -a --filter "name=${NAME}" --format '{{.ID}}' | head -1 || true)

if [ -z "$CID" ]; then
  echo "ERROR: No container found matching ${NAME}"
  echo "=== All containers ==="
  docker ps -a --format "table {{.ID}}\t{{.Status}}\t{{.Names}}\t{{.Image}}" || true
  exit 1
fi

echo "=== Container $CID details ==="
docker inspect "$CID" | jq '.[0].State, .[0].NetworkSettings, .[0].HostConfig' || true

STATUS=$(docker inspect --format='{{.State.Status}}' "$CID" || true)
echo "Container status: $STATUS"

if [ "$STATUS" != "running" ]; then
  echo "\n=== Last 200 lines of logs ==="
  docker logs --tail 200 "$CID" 2>&1 || true
  
  echo "\n=== Error logs ==="
  docker logs "$CID" 2>&1 | grep -i error | tail -n 50 || true
  
  echo "\n=== Full container inspection ==="
  docker inspect "$CID" || true
  
  echo "\n=== Checking container processes ==="
  docker top "$CID" || true
  
  exit 1
fi

echo "\n=== Application logs (last 50 lines) ==="
docker logs --tail 50 "$CID" 2>&1 || true

echo "\n=== Checking application health ==="
HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$CID" 2>/dev/null || echo "healthcheck not configured")
echo "Health status: $HEALTH"

# Additional debug: Check if port is accessible
echo "\n=== Checking port accessibility ==="
PORT_CHECK=$(docker exec "$CID" /bin/sh -c "nc -z localhost 8080 && echo 'Port 8080 is open' || echo 'Port 8080 is not accessible'" 2>&1 || true)
echo "$PORT_CHECK"

echo "\n=== Checking Java process ==="
JAVA_PROCESS=$(docker exec "$CID" /bin/sh -c 'ps aux | grep [j]ava || echo "No Java process found"' 2>&1 || true)
echo "$JAVA_PROCESS"

echo "\n=== Checking listening ports ==="
docker exec "$CID" /bin/sh -c 'netstat -tuln 2>/dev/null || ss -tuln 2>/dev/null || echo "Could not check listening ports"' || true

echo "\nContainer $CID appears to be running"
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
    }
  }
}