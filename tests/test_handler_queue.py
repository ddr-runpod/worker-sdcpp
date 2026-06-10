import requests
import requests_mock
import pytest

from src.handler_queue import handler

# The handler reads SD_SERVER_URL at import time. tests/conftest.py
# sets it to "http://mock-upstream" so the load-balancing tests can
# intercept calls with respx; the queue tests use the same URL so both
# sets of tests agree on what to mock.
SD_SERVER_URL = "http://mock-upstream"
TXT2IMG_URL = f"{SD_SERVER_URL}/sdapi/v1/txt2img"
IMG2IMG_URL = f"{SD_SERVER_URL}/sdapi/v1/img2img"


@pytest.fixture
def mock_sd_server():
    """Mock sd-server with a default route for both txt2img and img2img."""
    with requests_mock.Mocker() as m:
        m.post(TXT2IMG_URL, json={"images": ["abc"]})
        m.post(IMG2IMG_URL, json={"images": ["def"]})
        yield m


def test_handler_routes_to_txt2img_by_default(mock_sd_server):
    result = handler({"id": "test", "input": {"prompt": "a cat"}})
    assert result == {"images": ["abc"]}
    assert mock_sd_server.last_request.url == TXT2IMG_URL


def test_handler_routes_to_img2img_when_mode_is_img2img(mock_sd_server):
    result = handler(
        {"id": "test", "input": {"mode": "img2img", "init_images": ["img"]}}
    )
    assert result == {"images": ["def"]}
    assert mock_sd_server.last_request.url == IMG2IMG_URL


def test_handler_pops_mode_from_payload(mock_sd_server):
    """The `mode` key is used to pick the endpoint and must not be
    forwarded to sd-server as a generation parameter."""
    handler(
        {
            "id": "test",
            "input": {
                "mode": "img2img",
                "init_images": ["img"],
                "extra": "x",
            },
        }
    )
    body = mock_sd_server.last_request.json()
    assert "mode" not in body
    assert body["init_images"] == ["img"]
    assert body["extra"] == "x"


def test_handler_returns_response_payload_on_success(mock_sd_server):
    mock_sd_server.post(
        TXT2IMG_URL,
        json={"images": ["img1", "img2"], "info": "info"},
    )
    result = handler({"id": "test", "input": {"prompt": "x"}})
    assert result == {"images": ["img1", "img2"], "info": "info"}


def test_handler_returns_error_dict_on_timeout(mock_sd_server):
    mock_sd_server.post(TXT2IMG_URL, exc=requests.exceptions.Timeout)
    result = handler({"id": "test", "input": {"prompt": "x"}})
    assert "error" in result
    assert "timed out" in result["error"].lower()


def test_handler_returns_error_dict_on_http_error(mock_sd_server):
    mock_sd_server.post(
        TXT2IMG_URL, status_code=500, text="internal error"
    )
    result = handler({"id": "test", "input": {"prompt": "x"}})
    assert result["error"] == "sd-server error: 500"
    assert "internal error" in result["details"]


def test_handler_returns_error_dict_on_connection_error(mock_sd_server):
    mock_sd_server.post(TXT2IMG_URL, exc=requests.exceptions.ConnectionError)
    result = handler({"id": "test", "input": {"prompt": "x"}})
    assert "error" in result
    assert "failed" in result["error"].lower()
