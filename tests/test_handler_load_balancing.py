import asyncio

import httpx
from httpx import Response


# /ping
# -----
def test_ping_returns_200_when_upstream_returns_200(respx_mock, client):
    respx_mock.get("http://mock-upstream/sdapi/v1/sd-models").mock(
        return_value=Response(200, json=[{"title": "test-model"}])
    )
    response = client.get("/ping")
    assert response.status_code == 200


def test_ping_returns_204_when_upstream_returns_500(respx_mock, client):
    respx_mock.get("http://mock-upstream/sdapi/v1/sd-models").mock(
        return_value=Response(500, text="server error")
    )
    response = client.get("/ping")
    assert response.status_code == 204


def test_ping_returns_204_when_upstream_unreachable(respx_mock, client):
    respx_mock.get("http://mock-upstream/sdapi/v1/sd-models").mock(
        side_effect=httpx.ConnectError("connection refused")
    )
    response = client.get("/ping")
    assert response.status_code == 204


def test_ping_returns_204_when_upstream_times_out(respx_mock, client):
    respx_mock.get("http://mock-upstream/sdapi/v1/sd-models").mock(
        side_effect=asyncio.TimeoutError()
    )
    response = client.get("/ping")
    assert response.status_code == 204


# Catch-all proxy
# ---------------
def test_proxy_forwards_get_with_path(respx_mock, client):
    respx_mock.get("http://mock-upstream/sdapi/v1/loras").mock(
        return_value=Response(200, json=[{"name": "lora1"}])
    )
    response = client.get("/sdapi/v1/loras")
    assert response.status_code == 200
    assert response.json() == [{"name": "lora1"}]


def test_proxy_forwards_post_with_json_body(respx_mock, client):
    route = respx_mock.post("http://mock-upstream/sdapi/v1/txt2img").mock(
        return_value=Response(200, json={"images": ["abc"]})
    )
    response = client.post(
        "/sdapi/v1/txt2img", json={"prompt": "hi", "steps": 20}
    )
    assert response.status_code == 200
    assert response.json() == {"images": ["abc"]}
    sent_body = route.calls.last.request.content
    assert b'"prompt":"hi"' in sent_body
    assert b'"steps":20' in sent_body


def test_proxy_preserves_query_params(respx_mock, client):
    route = respx_mock.get("http://mock-upstream/sdapi/v1/samplers").mock(
        return_value=Response(200, json=["euler"])
    )
    response = client.get("/sdapi/v1/samplers?foo=bar&baz=qux")
    assert response.status_code == 200
    assert route.calls.last.request.url.params["foo"] == "bar"
    assert route.calls.last.request.url.params["baz"] == "qux"


def test_proxy_passes_through_upstream_status_code(respx_mock, client):
    respx_mock.post("http://mock-upstream/sdapi/v1/txt2img").mock(
        return_value=Response(422, text="validation error")
    )
    response = client.post("/sdapi/v1/txt2img", json={})
    assert response.status_code == 422
    assert response.text == "validation error"


def test_proxy_passes_through_upstream_body(respx_mock, client):
    respx_mock.get("http://mock-upstream/sdapi/v1/sd-models").mock(
        return_value=Response(200, json=[{"title": "model"}])
    )
    response = client.get("/sdapi/v1/sd-models")
    assert response.json() == [{"title": "model"}]


def test_proxy_returns_502_when_upstream_unreachable(respx_mock, client):
    respx_mock.get("http://mock-upstream/sdapi/v1/loras").mock(
        side_effect=httpx.ConnectError("connection refused")
    )
    response = client.get("/sdapi/v1/loras")
    assert response.status_code == 502
    body = response.json()
    assert "error" in body
    assert "unreachable" in body["error"].lower()


def test_proxy_strips_hop_by_hop_request_headers(respx_mock, client):
    """The proxy must not forward the incoming request's `host` or
    `connection` headers verbatim.

    httpx will set its own `host` and `connection` headers on the
    outgoing request regardless of what we pass to it, so we cannot
    assert their direct absence in the captured request. We assert the
    observable consequence: the upstream sees the URL's host (not the
    caller's value), and arbitrary custom headers pass through.
    """
    route = respx_mock.get("http://mock-upstream/sdapi/v1/sd-models").mock(
        return_value=Response(200, json=[])
    )
    client.get(
        "/sdapi/v1/sd-models",
        headers={"host": "evil.example.com", "x-custom": "should-pass"},
    )
    sent_headers = route.calls.last.request.headers
    # The caller's host value must not reach the upstream; httpx sets
    # the URL's host automatically.
    assert sent_headers.get("host") != "evil.example.com"
    # Custom headers pass through the filter.
    assert sent_headers["x-custom"] == "should-pass"


def test_proxy_strips_hop_by_hop_response_headers(respx_mock, client):
    respx_mock.get("http://mock-upstream/sdapi/v1/sd-models").mock(
        return_value=Response(
            200,
            json=[],
            headers={"connection": "close", "x-custom": "stays"},
        )
    )
    response = client.get("/sdapi/v1/sd-models")
    response_header_names = {k.lower() for k in response.headers.keys()}
    assert "connection" not in response_header_names
    assert "x-custom" in response_header_names


def test_proxy_forwards_custom_request_header(respx_mock, client):
    route = respx_mock.get("http://mock-upstream/sdapi/v1/sd-models").mock(
        return_value=Response(200, json=[])
    )
    client.get("/sdapi/v1/sd-models", headers={"x-my-header": "value"})
    assert route.calls.last.request.headers["x-my-header"] == "value"


def test_explicit_ping_route_wins_over_catch_all(respx_mock, client):
    """The /ping route is registered before the catch-all, so a request
    to /ping must hit the explicit handler, not the catch-all proxy.

    The catch-all would forward to http://mock-upstream/ping; we mock
    that endpoint to return a body the proxy would pass through. If
    the catch-all had matched, the response would carry that body.
    Instead the explicit /ping handler returns an empty 200 and only
    calls /sdapi/v1/sd-models internally.
    """
    respx_mock.get("http://mock-upstream/sdapi/v1/sd-models").mock(
        return_value=Response(200, json=[{"title": "model"}])
    )
    catch_all_ping = respx_mock.get("http://mock-upstream/ping").mock(
        return_value=Response(200, json={"via_catch_all": True})
    )
    response = client.get("/ping")
    assert response.status_code == 200
    assert response.content == b""
    # The catch-all /ping mock must NOT have been called.
    assert not catch_all_ping.called
    # The /sdapi/v1/sd-models mock should have been called exactly once
    # (by the /ping handler's internal probe).
    assert len(respx_mock.calls) == 1
    assert (
        str(respx_mock.calls[0].request.url)
        == "http://mock-upstream/sdapi/v1/sd-models"
    )
