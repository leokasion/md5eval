#!/usr/bin/env bash
set -euo pipefail

echo "[STOP] Tearing down containers, volumes, and networks..."
docker-compose down -v
echo "[STOP] Environment cleared."

