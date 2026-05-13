from pathlib import Path

import requests


class ClipUploadClient:
    def __init__(
        self,
        upload_url: str,
        timeout_seconds: float = 5.0,
    ) -> None:
        self.upload_url = upload_url
        self.timeout_seconds = timeout_seconds

    def upload_clip(
        self,
        clip_path: str,
        event_key: str | None = None,
    ) -> dict | None:
        normalized_path = clip_path.strip()
        if not normalized_path or normalized_path == "-":
            return None

        file_path = Path(normalized_path)
        if not file_path.exists() or not file_path.is_file():
            return None
        if file_path.suffix.lower() != ".mp4":
            return None

        data = {}
        if event_key:
            data["event_key"] = event_key

        try:
            with file_path.open("rb") as clip_file:
                response = requests.post(
                    self.upload_url,
                    files={"file": (file_path.name, clip_file, "video/mp4")},
                    data=data,
                    timeout=self.timeout_seconds,
                )
            if 200 <= response.status_code < 300:
                result = response.json()
                if isinstance(result, dict):
                    return result
            print(f"HTTP clip upload failed: status_code={response.status_code}")
        except requests.RequestException as error:
            print(f"HTTP clip upload failed: {error}")
        except ValueError as error:
            print(f"HTTP clip upload response parse failed: {error}")

        return None
