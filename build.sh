#!/usr/bin/env bash
set -euo pipefail

echo "[BUILD] Triggering multi-stage container build..."
docker-compose build --no-cache
echo "[BUILD] Images compiled succesfully."

