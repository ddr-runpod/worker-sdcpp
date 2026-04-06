import requests
import time


def wait_for_server(url: str = "http://localhost:8080", timeout: int = 300) -> bool:
    end_time = time.time() + timeout
    while time.time() < end_time:
        try:
            if requests.get(f"{url}/sdapi/v1/sd-models", timeout=5).status_code == 200:
                return True
        except requests.RequestException:
            pass
        time.sleep(5)
    return False
