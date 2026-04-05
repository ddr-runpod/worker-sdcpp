import requests
import base64
import io
from typing import Optional, List, Dict, Any
from PIL import Image


class SDClient:
    def __init__(self, base_url: str = "http://localhost:8080"):
        self.base_url = base_url.rstrip("/")

    def txt2img(
        self,
        prompt: str,
        negative_prompt: str = "",
        width: int = 512,
        height: int = 512,
        steps: int = 20,
        cfg_scale: float = 7.0,
        seed: int = -1,
        sampler_name: str = "euler_a",
        scheduler: str = "default",
        batch_size: int = 1,
        lora: Optional[List[Dict[str, Any]]] = None,
    ) -> Dict[str, Any]:
        payload = {
            "prompt": prompt,
            "negative_prompt": negative_prompt,
            "width": width,
            "height": height,
            "steps": steps,
            "cfg_scale": cfg_scale,
            "seed": seed,
            "sampler_name": sampler_name,
            "scheduler": scheduler,
            "batch_size": batch_size,
        }
        if lora:
            payload["lora"] = lora

        response = requests.post(f"{self.base_url}/sdapi/v1/txt2img", json=payload)
        response.raise_for_status()
        return response.json()

    def img2img(
        self,
        prompt: str,
        init_images: List[str],
        negative_prompt: str = "",
        mask: Optional[str] = None,
        denoising_strength: float = 0.75,
        width: int = 512,
        height: int = 512,
        steps: int = 20,
        cfg_scale: float = 7.0,
        seed: int = -1,
        sampler_name: str = "euler_a",
        scheduler: str = "default",
        lora: Optional[List[Dict[str, Any]]] = None,
    ) -> Dict[str, Any]:
        payload = {
            "prompt": prompt,
            "negative_prompt": negative_prompt,
            "init_images": init_images,
            "denoising_strength": denoising_strength,
            "width": width,
            "height": height,
            "steps": steps,
            "cfg_scale": cfg_scale,
            "seed": seed,
            "sampler_name": sampler_name,
            "scheduler": scheduler,
        }
        if mask:
            payload["mask"] = mask
        if lora:
            payload["lora"] = lora

        response = requests.post(f"{self.base_url}/sdapi/v1/img2img", json=payload)
        response.raise_for_status()
        return response.json()

    def get_samplers(self) -> List[Dict[str, Any]]:
        response = requests.get(f"{self.base_url}/sdapi/v1/samplers")
        response.raise_for_status()
        return response.json()

    def get_schedulers(self) -> List[Dict[str, Any]]:
        response = requests.get(f"{self.base_url}/sdapi/v1/schedulers")
        response.raise_for_status()
        return response.json()

    def get_loras(self) -> List[Dict[str, str]]:
        response = requests.get(f"{self.base_url}/sdapi/v1/loras")
        response.raise_for_status()
        return response.json()

    def refresh_loras(self) -> Dict[str, bool]:
        response = requests.post(f"{self.base_url}/sdapi/v1/refresh-loras")
        response.raise_for_status()
        return response.json()

    def get_sd_models(self) -> List[Dict[str, Any]]:
        response = requests.get(f"{self.base_url}/sdapi/v1/sd-models")
        response.raise_for_status()
        return response.json()

    def get_options(self) -> Dict[str, Any]:
        response = requests.get(f"{self.base_url}/sdapi/v1/options")
        response.raise_for_status()
        return response.json()

    def health_check(self) -> bool:
        try:
            self.get_sd_models()
            return True
        except requests.RequestException:
            return False

    @staticmethod
    def image_to_base64(image: Image.Image, format: str = "PNG") -> str:
        buffer = io.BytesIO()
        image.save(buffer, format=format)
        return base64.b64encode(buffer.getvalue()).decode("utf-8")

    @staticmethod
    def base64_to_image(base64_str: str) -> Image.Image:
        if base64_str.startswith("data:"):
            base64_str = base64_str.split(",", 1)[1]
        image_data = base64.b64decode(base64_str)
        return Image.open(io.BytesIO(image_data))
