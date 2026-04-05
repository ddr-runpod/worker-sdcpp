#!/bin/bash
set -e

BASE_URL="${SD_SERVER_URL:-http://localhost:8080}"
OUTPUT_DIR="${1:-./test_output}"

mkdir -p "$OUTPUT_DIR"

echo "Testing sd-server at $BASE_URL"
echo "Output directory: $OUTPUT_DIR"

echo ""
echo "=== Testing /sdapi/v1/txt2img ==="
curl -s -X POST "$BASE_URL/sdapi/v1/txt2img" \
    -H "Content-Type: application/json" \
    -d '{
        "prompt": "a beautiful sunset over mountains, highly detailed, cinematic",
        "steps": 10,
        "width": 512,
        "height": 512
    }' > "$OUTPUT_DIR/txt2img_response.json"

if [ $? -eq 0 ]; then
    echo "txt2img request succeeded"
    python3 -c "
import base64, json
with open('$OUTPUT_DIR/txt2img_response.json') as f:
    data = json.load(f)
if 'images' in data and len(data['images']) > 0:
    with open('$OUTPUT_DIR/txt2img_output.png', 'wb') as f:
        f.write(base64.b64decode(data['images'][0]))
    print('Saved txt2img_output.png')
"
fi

echo ""
echo "=== Testing /sdapi/v1/samplers ==="
curl -s "$BASE_URL/sdapi/v1/samplers" | python3 -m json.tool > "$OUTPUT_DIR/samplers.json"
echo "Saved samplers.json"

echo ""
echo "=== Testing /sdapi/v1/schedulers ==="
curl -s "$BASE_URL/sdapi/v1/schedulers" | python3 -m json.tool > "$OUTPUT_DIR/schedulers.json"
echo "Saved schedulers.json"

echo ""
echo "=== Testing /sdapi/v1/loras ==="
curl -s "$BASE_URL/sdapi/v1/loras" | python3 -m json.tool > "$OUTPUT_DIR/loras.json"
echo "Saved loras.json"

echo ""
echo "=== Testing /sdapi/v1/sd-models ==="
curl -s "$BASE_URL/sdapi/v1/sd-models" | python3 -m json.tool > "$OUTPUT_DIR/models.json"
echo "Saved models.json"

echo ""
echo "All tests completed. Results in $OUTPUT_DIR/"
