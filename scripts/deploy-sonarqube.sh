#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="$SCRIPT_DIR/../docker/sonarqube"

echo "==> Deploying SonarQube stack..."

cd "$COMPOSE_DIR"

docker compose pull
docker compose up -d --remove-orphans

echo "==> SonarQube deployment complete"
echo "    Access at http://$(hostname -I | awk '{print $1}'):9000"
