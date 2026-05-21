#!/usr/bin/env bash
set -euo pipefail

echo "[START] Launching secure network topology in background..."
docker-compose up -d
echo "[START] Infraestructure is up."
