import os
import runpod
import requests

SD_SERVER_URL = os.getenv("SD_SERVER_URL", "http://127.0.0.1:8080")
REQUEST_TIMEOUT = int(os.getenv("HANDLER_TIMEOUT", "300"))


def handler(job: dict) -> dict:
    """Process incoming RunPod job."""
    job_input = job.get("input", {})

    mode = job_input.get("mode", "txt2img")

    if mode == "img2img":
        response = requests.post(
            f"{SD_SERVER_URL}/sdapi/v1/img2img", json=job_input, timeout=REQUEST_TIMEOUT
        )
    else:
        response = requests.post(
            f"{SD_SERVER_URL}/sdapi/v1/txt2img", json=job_input, timeout=REQUEST_TIMEOUT
        )

    response.raise_for_status()
    return response.json()


if __name__ == "__main__":
    runpod.serverless.start(handler)
