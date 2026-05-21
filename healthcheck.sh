#!/usr/bin/env bash
set -euo pipefail

URL="http://localhost/health"
echo "[MONITOR] Initializing active health polling on $URL (Interval: 5s)..."

while true; do
	#Fetch only the HTTP status code. If connection fails, output FAIL.
	STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL" || echo "FAIL")

	if [ "$STATUS" = "200" ]; then
		echo "[$(date +%T)] STATUS: 200 OK | System Secure"
	else
		echo "[$(date +%T)] STATUS: $STATUS | ALERT HEALTHCHECK FAILED"
	fi
	sleep 5
done
