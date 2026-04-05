#!/bin/bash
set -e

BASE_URL="${SD_SERVER_URL:-http://localhost:8080}"

echo "Running sd-server health check against $BASE_URL"

SAMPLERS=$(curl -s "$BASE_URL/sdapi/v1/samplers")
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to connect to sd-server"
    exit 1
fi

MODELS=$(curl -s "$BASE_URL/sdapi/v1/sd-models")
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to get model info"
    exit 1
fi

echo "sd-server is healthy"
echo "Available samplers:"
echo "$SAMPLERS" | python3 -m json.tool 2>/dev/null || echo "$SAMPLERS"

exit 0
