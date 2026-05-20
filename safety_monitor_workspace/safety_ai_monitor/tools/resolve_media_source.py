import hashlib
import json
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) < 3:
        print(
            json.dumps(
                {
                    "ok": False,
                    "error": "usage: resolve_media_source.py <source_type> <source_value>",
                },
                ensure_ascii=False,
            )
        )
        return 1

    source_type = sys.argv[1].strip()
    source_value = sys.argv[2].strip()

    if source_type == "stream" and _is_youtube_url(source_value):
        resolved_path = _download_youtube_video(source_value)
        print(
            json.dumps(
                {
                    "ok": True,
                    "source_type": "video",
                    "source_value": str(resolved_path.resolve()),
                    "original_source_type": source_type,
                    "original_source_value": source_value,
                },
                ensure_ascii=False,
            )
        )
        return 0

    print(
        json.dumps(
            {
                "ok": True,
                "source_type": source_type,
                "source_value": source_value,
                "original_source_type": source_type,
                "original_source_value": source_value,
            },
            ensure_ascii=False,
        )
    )
    return 0


def _download_youtube_video(url: str) -> Path:
    try:
        import yt_dlp
    except ModuleNotFoundError as error:
        raise RuntimeError(
            "유튜브 링크를 열려면 yt-dlp 설치가 필요합니다."
        ) from error

    workspace_root = Path(__file__).resolve().parents[2]
    cache_dir = workspace_root / "safety_ai_monitor" / "logs" / "source_cache"
    cache_dir.mkdir(parents=True, exist_ok=True)

    url_hash = hashlib.sha1(url.encode("utf-8")).hexdigest()[:12]
    output_path = cache_dir / f"youtube_{url_hash}.mp4"

    if output_path.exists() and output_path.is_file() and output_path.stat().st_size > 0:
        return output_path

    ydl_opts = {
        "format": "best[ext=mp4]/best",
        "outtmpl": str(output_path),
        "merge_output_format": "mp4",
        "noplaylist": True,
        "quiet": True,
        "no_warnings": True,
        "overwrites": True,
    }

    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        ydl.download([url])

    if not output_path.exists() or output_path.stat().st_size <= 0:
        raise RuntimeError("유튜브 영상을 다운로드하지 못했습니다.")

    return output_path


def _is_youtube_url(value: str) -> bool:
    normalized = value.strip().lower()
    return (
        "youtube.com/" in normalized
        or "youtu.be/" in normalized
        or "youtube-nocookie.com/" in normalized
    )


if __name__ == "__main__":
    raise SystemExit(main())
