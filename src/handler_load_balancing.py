import asyncio
import os

import httpx
import uvicorn
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, Response

SD_SERVER_URL = os.getenv("SD_SERVER_URL", "http://127.0.0.1:8080")
REQUEST_TIMEOUT = int(os.getenv("HANDLER_TIMEOUT", "300"))
# The load balancer health probe must fail fast when sd-server is down;
# 5s is short enough to keep the probe responsive and long enough to
# tolerate normal sd-server latency on the readiness check.
PING_TIMEOUT_SECONDS = 5
PORT = int(os.getenv("PORT", "80"))
LOG_LEVEL = os.getenv("LOG_LEVEL", "info").lower()

# Hop-by-hop headers (RFC 7230 §6.1) and headers that httpx manages itself
# when forwarding a request. Stripping them avoids request smuggling and
# double-content-length bugs.
HOP_BY_HOP_HEADERS = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailers",
    "transfer-encoding",
    "upgrade",
    "host",
    "content-length",
}


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.client = httpx.AsyncClient(base_url=SD_SERVER_URL, timeout=REQUEST_TIMEOUT)
    try:
        yield
    finally:
        await app.state.client.aclose()


app = FastAPI(title="worker-sdcpp", lifespan=lifespan)


@app.get("/ping")
async def ping(request: Request):
    """Health probe for the RunPod load balancer.

    200 once sd-server responds; 204 while it is still initialising.
    startup.sh normally blocks on sd-server readiness before exec-ing this
    process, so 204 is a safety net for races or future refactors.
    """
    client: httpx.AsyncClient = request.app.state.client
    try:
        response = await asyncio.wait_for(
            client.get("/sdapi/v1/sd-models"),
            timeout=PING_TIMEOUT_SECONDS,
        )
    except (httpx.RequestError, asyncio.TimeoutError):
        return Response(status_code=204)
    return Response(status_code=200 if response.status_code == 200 else 204)


@app.api_route(
    "/{full_path:path}",
    methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS", "HEAD"],
)
async def proxy(full_path: str, request: Request):
    """Catch-all reverse proxy that forwards every other path to sd-server."""
    client: httpx.AsyncClient = request.app.state.client
    body = await request.body()
    forwarded_headers = {
        k: v for k, v in request.headers.items() if k.lower() not in HOP_BY_HOP_HEADERS
    }

    try:
        upstream = await client.request(
            request.method,
            f"/{full_path}",
            params=request.query_params,
            headers=forwarded_headers,
            content=body,
        )
    except httpx.RequestError as exc:
        return JSONResponse(
            {"error": f"sd-server unreachable: {exc}"},
            status_code=502,
        )

    response_headers = {
        k: v for k, v in upstream.headers.items() if k.lower() not in HOP_BY_HOP_HEADERS
    }
    return Response(
        content=upstream.content,
        status_code=upstream.status_code,
        headers=response_headers,
    )


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=PORT, log_level=LOG_LEVEL)
