#!/usr/bin/env python3
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from src.client import SDClient
from PIL import Image
import base64
import json


def test_txt2img():
    client = SDClient()

    print("Testing txt2img...")
    result = client.txt2img(
        prompt="a cute cat",
        steps=10,
        width=512,
        height=512,
    )

    assert "images" in result
    assert len(result["images"]) > 0

    image = client.base64_to_image(result["images"][0])
    assert isinstance(image, Image.Image)

    print("  txt2img: PASS")


def test_api_endpoints():
    client = SDClient()

    print("Testing API endpoints...")

    samplers = client.get_samplers()
    assert isinstance(samplers, list)
    print(f"  Found {len(samplers)} samplers")

    schedulers = client.get_schedulers()
    assert isinstance(schedulers, list)
    print(f"  Found {len(schedulers)} schedulers")

    loras = client.get_loras()
    assert isinstance(loras, list)

    models = client.get_sd_models()
    assert isinstance(models, list)

    options = client.get_options()
    assert isinstance(options, dict)

    print("  API endpoints: PASS")


def test_health_check():
    from src.healthcheck import wait_for_server, get_server_info

    print("Testing health check...")

    if wait_for_server(timeout=5):
        info = get_server_info()
        print(
            f"  Server is healthy, model: {info['options'].get('sd_model_checkpoint', 'unknown')}"
        )
        print("  Health check: PASS")
    else:
        print("  Health check: SKIP (server not running)")


def main():
    print("Running sd-cpp tests...\n")

    try:
        test_api_endpoints()
        test_txt2img()
        test_health_check()
        print("\nAll tests passed!")
    except Exception as e:
        print(f"\nTest failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
