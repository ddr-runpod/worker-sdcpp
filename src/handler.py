import os
import runpod
import requests

SD_SERVER_URL = os.getenv("SD_SERVER_URL", "http://127.0.0.1:8080")
REQUEST_TIMEOUT = int(os.getenv("HANDLER_TIMEOUT", "300"))


def handler(job: dict) -> dict:
    """Process incoming RunPod job by proxying to sd-server."""
    job_input = job.get("input", {})
    job_id = job.get("id", "unknown")

    mode = job_input.get("mode", "txt2img")

    runpod.serverless.progress_update(job, f"Starting {mode} generation")

    endpoint = "/sdapi/v1/img2img" if mode == "img2img" else "/sdapi/v1/txt2img"

    try:
        response = requests.post(
            f"{SD_SERVER_URL}{endpoint}",
            json=job_input,
            timeout=REQUEST_TIMEOUT,
        )
        response.raise_for_status()
    except requests.exceptions.Timeout:
        return {"error": f"Request timed out after {REQUEST_TIMEOUT}s"}
    except requests.exceptions.HTTPError as e:
        return {
            "error": f"sd-server error: {e.response.status_code}",
            "details": e.response.text[:500],
        }
    except requests.exceptions.RequestException as e:
        return {"error": f"Request failed: {str(e)}"}

    result = response.json()

    if "images" in result:
        runpod.serverless.progress_update(
            job, f"Generated {len(result['images'])} images"
        )

    return result


if __name__ == "__main__":
    runpod.serverless.start(handler)
