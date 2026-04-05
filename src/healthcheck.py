import requests
import time
from typing import Optional


def wait_for_server(
    url: str = "http://localhost:8080",
    timeout: int = 300,
    poll_interval: int = 5,
) -> bool:
    start_time = time.time()
    while time.time() - start_time < timeout:
        try:
            response = requests.get(f"{url}/sdapi/v1/sd-models", timeout=5)
            if response.status_code == 200:
                return True
        except requests.RequestException:
            pass
        time.sleep(poll_interval)
    return False


def get_server_info(url: str = "http://localhost:8080") -> dict:
    models = requests.get(f"{url}/sdapi/v1/sd-models").json()
    options = requests.get(f"{url}/sdapi/v1/options").json()
    samplers = requests.get(f"{url}/sdapi/v1/samplers").json()
    schedulers = requests.get(f"{url}/sdapi/v1/schedulers").json()
    loras = requests.get(f"{url}/sdapi/v1/loras").json()
    return {
        "models": models,
        "options": options,
        "samplers": samplers,
        "schedulers": schedulers,
        "loras": loras,
    }
