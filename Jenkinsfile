pipeline {
  agent any

  tools {
    maven 'Maven'
  }

  environment {
    DOCKER_IMAGE    = "spring-boot-test-api"
    DOCKER_TAG      = "latest"
    SERVICE_NAME    = "spring-boot-test-api"
    COMPOSE_FILE    = "docker-compose.yml"
    COMPOSE_PROJECT = "spring-boot-test"
    APP_PORT        = "8080"
  }

  stages {
    stage('Checkout') {
      steps {
        git branch: 'master',
            url: 'https://github.com/Techie-Onkar-Ambhorkar/Spring-Boot-Test-API.git',
            credentialsId: 'github-creds'
      }
    }

    stage('Build & Test') {
      steps {
        sh 'mvn clean package'
      }
    }

    stage('Build Docker Image') {
      steps {
        script {
          // Build the Docker image
          docker.build("${DOCKER_IMAGE}:${DOCKER_TAG}").withRun("-p 8080:8080") { c ->
            // Verify the container started successfully
            sh "docker logs ${c.id}"
            
            // Simple health check
            def health = sh(script: "docker inspect -f '{{.State.Health.Status}}' ${c.id} 2>/dev/null || echo 'unknown'", returnStdout: true).trim()
            if (health != 'healthy' && health != 'no healthcheck') {
              error "Container failed health check: ${health}"
            }
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
                    echo "=== Container processes ==="
                    docker top "$CID" 2>/dev/null || true
                fi
                '''
                error "Deployment failed: ${e.message}"
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

    stage('Deploy with Docker Compose') {
      steps {
        script {
          try {
            // Stop and remove any existing containers
            sh "docker-compose -f ${COMPOSE_FILE} down --remove-orphans || true"
            
            // Start the application
            sh "docker-compose -f ${COMPOSE_FILE} up -d --build"
            
            // Wait for the application to start
            sleep 10
            
            // Verify the container is running
            def status = sh(script: "docker-compose -f ${COMPOSE_FILE} ps --services --filter 'status=running'", returnStdout: true).trim()
            if (!status.contains(SERVICE_NAME)) {
              error "${SERVICE_NAME} failed to start"
            }
            
            // Check application health
            def healthCheck = sh(
              script: "curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/actuator/health",
              returnStdout: true
            ).trim()
            
            if (healthCheck != '200') {
              error "Health check failed with status: ${healthCheck}"
            }
            
            echo "Deployment successful! Application is running on http://localhost:${APP_PORT}"
            
          } catch (Exception e) {
            // Get container logs if available
            def containerId = sh(script: "docker ps -q --filter 'name=${SERVICE_NAME}'", returnStdout: true).trim()
            if (containerId) {
              echo '=== Container Logs ==='
              sh "docker logs ${containerId} --tail 100 || true"
            }
            error "Deployment failed: ${e.message}"
          }
        }
      }
    }
  }

  post {
    always {
      // Clean up any running containers
      sh "docker-compose -f ${COMPOSE_FILE} down --remove-orphans || true"
      
      // Clean up workspace
      cleanWs()
    }
    
    success {
      echo 'Pipeline completed successfully!'
    }
    
    failure {
      echo 'Pipeline failed. Check the logs for details.'
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