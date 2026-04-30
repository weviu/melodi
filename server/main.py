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

# Optional YouTube cookies file to bypass bot detection
_COOKIES_FILE = Path("/var/lib/melodi-server/youtube-cookies.txt")
_COOKIES_LOCK = __import__("threading").Lock()


def _yt_base_args(cookies_path: str | None = None) -> list[str]:
    """Common yt-dlp args applied to every call."""
    args = [
        "--extractor-args", "youtube:player_client=mweb,web",
        "--js-runtime", "node",
        "--cache-dir", "/var/lib/melodi-server/yt-dlp-cache",
    ]
    if cookies_path:
        args += ["--cookies", cookies_path]
    elif _COOKIES_FILE.exists():
        args += ["--cookies", str(_COOKIES_FILE)]
    return args


def _copy_cookies(dest_dir: str) -> str | None:
    """Copy the master cookies file into dest_dir so yt-dlp can write freely."""
    with _COOKIES_LOCK:
        if not _COOKIES_FILE.exists():
            return None
        dest = os.path.join(dest_dir, "cookies.txt")
        shutil.copy2(str(_COOKIES_FILE), dest)
    os.chmod(dest, 0o600)
    return dest


def _sync_cookies(tmp_cookies: str) -> None:
    """Copy updated cookies from the per-request temp file back to master.

    yt-dlp writes refreshed YouTube session tokens into the temp file.
    Syncing back keeps the master file current so future requests stay
    authenticated.  Guarded by a lock to avoid concurrent-write corruption.
    """
    if not tmp_cookies or not os.path.exists(tmp_cookies):
        return
    with _COOKIES_LOCK:
        try:
            shutil.copy2(tmp_cookies, str(_COOKIES_FILE))
        except OSError as e:
            logger.warning("cookies sync failed: %s", e)

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
        search_tmp = tempfile.mkdtemp(prefix="melodi_search_")
        try:
            search_cookies = _copy_cookies(search_tmp)
            result = subprocess.run(
                [
                    "yt-dlp",
                    f"ytsearch{limit}:{q}",
                    "--flat-playlist",
                    "--dump-single-json",
                    "--no-warnings",
                    "--quiet",
                    *_yt_base_args(search_cookies),
                ],
                capture_output=True,
                text=True,
                timeout=30,
            )
        finally:
            shutil.rmtree(search_tmp, ignore_errors=True)
        if result.returncode != 0:
            # Filter out yt-dlp WARNING lines, show only the real error
            error = '\n'.join(
                l for l in result.stderr.splitlines()
                if not l.startswith('WARNING:')
            ).strip() or result.stderr
            raise RuntimeError(error)

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
        # Extract only the last meaningful error line, drop tracebacks
        msg = str(exc).splitlines()[-1] if str(exc).strip() else str(exc)
        raise HTTPException(status_code=500, detail=msg) from exc


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
        # Per-request writable copy of cookies — prevents yt-dlp from
        # overwriting the master file (which would strip auth cookies).
        cookies = _copy_cookies(tmp_dir)

        # Fetch metadata (title / artist) before downloading
        meta_proc = subprocess.run(
            [
                "yt-dlp", "--dump-single-json", "--no-warnings", "--quiet",
                *_yt_base_args(cookies),
                body.url,
            ],
            capture_output=True,
            text=True,
            timeout=30,
        )
        title, artist = "Unknown", "Unknown"
        # Parse metadata even if returncode != 0 — cookies save PermissionError
        # fires after fetch, stdout may still contain valid JSON.
        if meta_proc.stdout.strip():
            try:
                meta = json.loads(meta_proc.stdout)
                if meta and isinstance(meta, dict):
                    title = meta.get("title") or "Unknown"
                    artist = meta.get("channel") or meta.get("uploader") or "Unknown"
            except (json.JSONDecodeError, AttributeError):
                pass

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
                *_yt_base_args(cookies),
                "-o", os.path.join(tmp_dir, "%(title)s.%(ext)s"),
                "--no-warnings",
                "--quiet",
                body.url,
            ],
            capture_output=True,
            timeout=300,
        )
        mp3_files = list(Path(tmp_dir).glob("*.mp3"))
        if not mp3_files:
            # Only surface the yt-dlp error when no output was produced.
            err = dl_proc.stderr.decode(errors="replace")
            raise RuntimeError(err or "yt-dlp produced no mp3 file")

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
