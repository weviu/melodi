import json
import logging
import os
import shutil
import subprocess
import tempfile
import urllib.parse
from logging.handlers import RotatingFileHandler
from pathlib import Path

from dotenv import load_dotenv
from fastapi import FastAPI, Header, HTTPException, Query, Request
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

load_dotenv()

API_KEY: str = os.environ["MELODI_API_KEY"]

# ── Logging ────────────────────────────────────────────────────────────────────

Path("logs").mkdir(exist_ok=True)
_file_handler = RotatingFileHandler(
    "logs/melodi.log", maxBytes=5 * 1024 * 1024, backupCount=3
)
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[_file_handler, logging.StreamHandler()],
)
logger = logging.getLogger(__name__)


def _log(request: Request, endpoint: str, key: str, success: bool) -> None:
    ip = request.client.host if request.client else "unknown"
    prefix = (key[:6] + "...") if key else "none"
    logger.info("%-22s ip=%-15s key=%s success=%s", endpoint, ip, prefix, success)


# ── Rate limiter (per API key, fall back to IP) ────────────────────────────────


def _key_func(request: Request) -> str:
    return request.headers.get("x-api-key") or get_remote_address(request)


limiter = Limiter(key_func=_key_func)

# ── App ────────────────────────────────────────────────────────────────────────

app = FastAPI(title="Melodi Server")
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)


def _verify(key: str) -> None:
    if key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")


# ── GET / (health check) ───────────────────────────────────────────────────────


@app.get("/")
async def health():
    return {"status": "ok"}


# ── GET /search ────────────────────────────────────────────────────────────────


@app.get("/search")
@limiter.limit("10/minute")
async def search(
    request: Request,
    q: str = Query(..., min_length=1),
    limit: int = Query(20, ge=1, le=50),
    x_api_key: str = Header(alias="x-api-key", default=""),
):
    _verify(x_api_key)

    try:
        result = subprocess.run(
            [
                "yt-dlp",
                f"ytsearch{limit}:{q}",
                "--flat-playlist",
                "--dump-single-json",
                "--no-warnings",
                "--quiet",
                "--extractor-args", "youtube:player_client=ios,web",
            ],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode != 0:
            raise RuntimeError(result.stderr)

        data = json.loads(result.stdout)
        entries = data.get("entries") or []

        output = []
        for e in entries:
            secs = int(e.get("duration") or 0)
            output.append(
                {
                    "id": e.get("id", ""),
                    "title": e.get("title", "Unknown"),
                    "channel": e.get("channel") or e.get("uploader", ""),
                    "duration": f"{secs // 60:02d}:{secs % 60:02d}",
                    "thumbnailUrl": e.get("thumbnail", ""),
                }
            )

        _log(request, "GET /search", x_api_key, True)
        return output

    except Exception as exc:
        _log(request, "GET /search", x_api_key, False)
        raise HTTPException(status_code=500, detail=str(exc)) from exc


# ── POST /download ─────────────────────────────────────────────────────────────


class DownloadRequest(BaseModel):
    url: str


@app.post("/download")
@limiter.limit("10/minute")
async def download(
    request: Request,
    body: DownloadRequest,
    x_api_key: str = Header(alias="x-api-key", default=""),
):
    _verify(x_api_key)

    tmp_dir = tempfile.mkdtemp(prefix="melodi_")

    try:
        # Fetch metadata (title / artist) before downloading
        meta_proc = subprocess.run(
            [
                "yt-dlp", "--dump-single-json", "--no-warnings", "--quiet",
                "--extractor-args", "youtube:player_client=ios,web",
                body.url,
            ],
            capture_output=True,
            text=True,
            timeout=30,
        )
        title, artist = "Unknown", "Unknown"
        if meta_proc.returncode == 0:
            meta = json.loads(meta_proc.stdout)
            title = meta.get("title") or "Unknown"
            artist = meta.get("channel") or meta.get("uploader") or "Unknown"

        # Download and convert to MP3
        dl_proc = subprocess.run(
            [
                "yt-dlp",
                "-x",
                "--audio-format", "mp3",
                "--audio-quality", "5",
                "--concurrent-fragments", "4",
                "--embed-thumbnail",
                "--add-metadata",
                "--extractor-args", "youtube:player_client=ios,web",
                "-o", os.path.join(tmp_dir, "%(title)s.%(ext)s"),
                "--no-warnings",
                "--quiet",
                body.url,
            ],
            capture_output=True,
            timeout=300,
        )
        if dl_proc.returncode != 0:
            raise RuntimeError(dl_proc.stderr.decode(errors="replace"))

        mp3_files = list(Path(tmp_dir).glob("*.mp3"))
        if not mp3_files:
            raise RuntimeError("yt-dlp produced no mp3 file")

        mp3_path = mp3_files[0]
        file_size = mp3_path.stat().st_size

        def _stream():
            try:
                with open(mp3_path, "rb") as fh:
                    while chunk := fh.read(64 * 1024):
                        yield chunk
            finally:
                shutil.rmtree(tmp_dir, ignore_errors=True)

        encoded_filename = urllib.parse.quote(mp3_path.name)
        _log(request, "POST /download", x_api_key, True)
        return StreamingResponse(
            _stream(),
            media_type="audio/mpeg",
            headers={
                "Content-Disposition": f"attachment; filename*=UTF-8''{encoded_filename}",
                "Content-Length": str(file_size),
                "X-Title": title,
                "X-Artist": artist,
                "X-Filename": encoded_filename,
            },
        )

    except Exception as exc:
        shutil.rmtree(tmp_dir, ignore_errors=True)
        _log(request, "POST /download", x_api_key, False)
        raise HTTPException(status_code=500, detail=str(exc)) from exc
