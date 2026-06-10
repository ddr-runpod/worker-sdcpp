def test_e2e_ping_200(integration_client):
    """Real upstream returns 200 for /sdapi/v1/sd-models, so /ping returns 200."""
    response = integration_client.get("/ping")
    assert response.status_code == 200


def test_e2e_post_txt2img_forwards_body_and_path(integration_client):
    payload = {"prompt": "a sunset", "steps": 4, "width": 64, "height": 64}
    response = integration_client.post("/sdapi/v1/txt2img", json=payload)
    assert response.status_code == 200
    body = response.json()
    assert body["echo_path"] == "/sdapi/v1/txt2img"
    assert body["echo_method"] == "POST"
    assert "a sunset" in body["echo_body"]


def test_e2e_query_string_is_preserved(integration_client):
    response = integration_client.get("/sdapi/v1/samplers?foo=bar&baz=qux")
    assert response.status_code == 200
    body = response.json()
    # The upstream echoes the raw path including the query string.
    assert "foo=bar" in body["echo_path"]
    assert "baz=qux" in body["echo_path"]


def test_e2e_get_passes_through_response_body(integration_client):
    response = integration_client.get("/sdapi/v1/loras")
    assert response.status_code == 200
    body = response.json()
    assert body["echo_path"] == "/sdapi/v1/loras"
    assert body["echo_method"] == "GET"
